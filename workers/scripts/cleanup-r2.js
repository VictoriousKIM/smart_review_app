/**
 * R2 버킷 완전 정리 스크립트
 * - 모든 객체 삭제
 * - 미완료 멀티파트 업로드 중단
 * 
 * 사용법:
 *   node scripts/cleanup-r2.js              # 현재 상태만 확인
 *   node scripts/cleanup-r2.js --cleanup    # 완전 정리 실행
 */

import { S3Client, ListObjectsV2Command, DeleteObjectsCommand, ListMultipartUploadsCommand, AbortMultipartUploadCommand } from '@aws-sdk/client-s3';

const R2_ACCOUNT_ID = process.env.R2_ACCOUNT_ID;
const R2_ACCESS_KEY_ID = process.env.R2_ACCESS_KEY_ID;
const R2_SECRET_ACCESS_KEY = process.env.R2_SECRET_ACCESS_KEY;
const R2_BUCKET_NAME = process.env.R2_BUCKET_NAME || 'smart-review-files';

if (!R2_ACCOUNT_ID || !R2_ACCESS_KEY_ID || !R2_SECRET_ACCESS_KEY) {
  console.error('❌ R2 환경 변수가 설정되지 않았습니다.');
  console.error('필요한 환경 변수: R2_ACCOUNT_ID, R2_ACCESS_KEY_ID, R2_SECRET_ACCESS_KEY');
  console.error('\n사용법:');
  console.error('  PowerShell: Get-Content .dev.vars | ForEach-Object { if ($_ -match \'^([^=]+)=(.*)$\') { [System.Environment]::SetEnvironmentVariable($matches[1], $matches[2], \'Process\') } } ; node scripts/cleanup-r2.js');
  process.exit(1);
}

const s3Client = new S3Client({
  region: 'auto',
  endpoint: `https://${R2_ACCOUNT_ID}.r2.cloudflarestorage.com`,
  credentials: {
    accessKeyId: R2_ACCESS_KEY_ID,
    secretAccessKey: R2_SECRET_ACCESS_KEY,
  },
});

// ============================================================================
// 유틸리티 함수
// ============================================================================

function formatBytes(bytes) {
  if (bytes === 0) return '0 Bytes';
  const k = 1024;
  const sizes = ['Bytes', 'KB', 'MB', 'GB'];
  const i = Math.floor(Math.log(bytes) / Math.log(k));
  return Math.round((bytes / Math.pow(k, i)) * 100) / 100 + ' ' + sizes[i];
}

function formatDate(date) {
  return new Date(date).toLocaleString('ko-KR', {
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
    second: '2-digit'
  });
}

// ============================================================================
// 객체 관련 함수
// ============================================================================

async function listAllObjects() {
  console.log(`\n📋 버킷 "${R2_BUCKET_NAME}"의 모든 객체 조회 중...\n`);
  
  const allObjects = [];
  let continuationToken = undefined;
  
  try {
    do {
      const command = new ListObjectsV2Command({
        Bucket: R2_BUCKET_NAME,
        ContinuationToken: continuationToken,
      });
      
      const response = await s3Client.send(command);
      
      if (response.Contents && response.Contents.length > 0) {
        allObjects.push(...response.Contents);
        response.Contents.forEach((obj, index) => {
          const num = allObjects.length - response.Contents.length + index + 1;
          const modified = formatDate(obj.LastModified);
          console.log(`  ${num}. ${obj.Key}`);
          console.log(`     크기: ${formatBytes(obj.Size)} | 수정: ${modified}`);
        });
      }
      
      continuationToken = response.NextContinuationToken;
    } while (continuationToken);
    
    const totalSize = allObjects.reduce((sum, obj) => sum + (obj.Size || 0), 0);
    console.log(`\n✅ 총 ${allObjects.length}개의 객체 발견`);
    console.log(`📊 총 크기: ${formatBytes(totalSize)}`);
    
    return allObjects;
  } catch (error) {
    console.error('❌ 객체 목록 조회 실패:', error.message);
    throw error;
  }
}

async function deleteAllObjects(objects) {
  if (objects.length === 0) {
    console.log('\n✅ 삭제할 객체가 없습니다.');
    return 0;
  }
  
  console.log(`\n🗑️  ${objects.length}개의 객체 삭제 중...\n`);
  
  // R2는 한 번에 최대 1000개까지 삭제 가능
  const batchSize = 1000;
  let deletedCount = 0;
  let failedCount = 0;
  
  for (let i = 0; i < objects.length; i += batchSize) {
    const batch = objects.slice(i, i + batchSize);
    
    try {
      const command = new DeleteObjectsCommand({
        Bucket: R2_BUCKET_NAME,
        Delete: {
          Objects: batch.map(obj => ({ Key: obj.Key })),
          Quiet: false,
        },
      });
      
      const response = await s3Client.send(command);
      
      if (response.Deleted) {
        deletedCount += response.Deleted.length;
        console.log(`  ✅ ${deletedCount}/${objects.length} 객체 삭제 완료`);
      }
      
      if (response.Errors && response.Errors.length > 0) {
        failedCount += response.Errors.length;
        console.error('  ⚠️  일부 객체 삭제 실패:');
        response.Errors.forEach(err => {
          console.error(`    - ${err.Key}: ${err.Message}`);
        });
      }
    } catch (error) {
      console.error(`  ❌ 배치 삭제 실패:`, error.message);
      failedCount += batch.length;
    }
  }
  
  console.log(`\n✅ 총 ${deletedCount}개의 객체가 삭제되었습니다.`);
  if (failedCount > 0) {
    console.log(`⚠️  ${failedCount}개의 객체 삭제 실패`);
  }
  
  return deletedCount;
}

// ============================================================================
// 멀티파트 업로드 관련 함수
// ============================================================================

async function listIncompleteUploads() {
  console.log(`\n📋 버킷 "${R2_BUCKET_NAME}"의 미완료 멀티파트 업로드 조회 중...\n`);
  
  const allUploads = [];
  let keyMarker = undefined;
  let uploadIdMarker = undefined;
  
  try {
    do {
      const command = new ListMultipartUploadsCommand({
        Bucket: R2_BUCKET_NAME,
        KeyMarker: keyMarker,
        UploadIdMarker: uploadIdMarker,
      });
      
      const response = await s3Client.send(command);
      
      if (response.Uploads && response.Uploads.length > 0) {
        allUploads.push(...response.Uploads);
        response.Uploads.forEach((upload, index) => {
          const num = allUploads.length - response.Uploads.length + index + 1;
          const initiated = formatDate(upload.Initiated);
          console.log(`  ${num}. ${upload.Key}`);
          console.log(`     Upload ID: ${upload.UploadId?.substring(0, 40)}...`);
          console.log(`     시작: ${initiated}`);
        });
      }
      
      keyMarker = response.NextKeyMarker;
      uploadIdMarker = response.NextUploadIdMarker;
    } while (keyMarker);
    
    console.log(`\n✅ 총 ${allUploads.length}개의 미완료 업로드 발견`);
    
    return allUploads;
  } catch (error) {
    console.error('❌ 미완료 업로드 목록 조회 실패:', error.message);
    throw error;
  }
}

async function abortIncompleteUploads(uploads) {
  if (uploads.length === 0) {
    console.log('\n✅ 정리할 미완료 업로드가 없습니다.');
    return 0;
  }
  
  console.log(`\n🗑️  ${uploads.length}개의 미완료 업로드 중단 중...\n`);
  
  let abortedCount = 0;
  let failedCount = 0;
  
  for (const upload of uploads) {
    try {
      const command = new AbortMultipartUploadCommand({
        Bucket: R2_BUCKET_NAME,
        Key: upload.Key,
        UploadId: upload.UploadId,
      });
      
      await s3Client.send(command);
      abortedCount++;
      console.log(`  ✅ [${abortedCount}/${uploads.length}] 중단 완료: ${upload.Key}`);
    } catch (error) {
      failedCount++;
      console.error(`  ❌ [${abortedCount + failedCount}/${uploads.length}] 중단 실패: ${upload.Key}`);
      console.error(`     에러: ${error.message}`);
    }
  }
  
  console.log(`\n✅ 총 ${abortedCount}개의 미완료 업로드가 중단되었습니다.`);
  if (failedCount > 0) {
    console.log(`⚠️  ${failedCount}개의 업로드 중단 실패`);
  }
  
  return abortedCount;
}

// ============================================================================
// 메인 함수
// ============================================================================

async function main() {
  console.log('═══════════════════════════════════════════════════════════════');
  console.log('🧹 R2 버킷 정리 스크립트');
  console.log('═══════════════════════════════════════════════════════════════');
  console.log(`버킷: ${R2_BUCKET_NAME}`);
  console.log(`계정 ID: ${R2_ACCOUNT_ID}`);
  console.log(`실행 시간: ${formatDate(new Date())}`);
  
  const shouldCleanup = process.argv.includes('--cleanup');
  
  try {
    // 1. 일반 객체 확인 및 삭제
    const objects = await listAllObjects();
    let deletedObjects = 0;
    
    if (objects.length > 0 && shouldCleanup) {
      deletedObjects = await deleteAllObjects(objects);
    }
    
    // 2. 미완료 업로드 확인 및 중단
    const uploads = await listIncompleteUploads();
    let abortedUploads = 0;
    
    if (uploads.length > 0 && shouldCleanup) {
      abortedUploads = await abortIncompleteUploads(uploads);
    }
    
    // 3. 최종 결과
    console.log('\n═══════════════════════════════════════════════════════════════');
    console.log('📊 최종 결과');
    console.log('═══════════════════════════════════════════════════════════════');
    
    if (shouldCleanup) {
      console.log(`✅ 삭제된 객체: ${deletedObjects}개`);
      console.log(`✅ 중단된 업로드: ${abortedUploads}개`);
      
      if (deletedObjects > 0 || abortedUploads > 0) {
        console.log('\n💡 버킷 크기는 몇 분 후 Cloudflare 대시보드에 반영됩니다.');
      } else {
        console.log('\n✅ 버킷이 이미 깨끗합니다.');
      }
    } else {
      console.log(`📦 현재 객체: ${objects.length}개`);
      console.log(`📦 미완료 업로드: ${uploads.length}개`);
      
      if (objects.length > 0 || uploads.length > 0) {
        console.log('\n⚠️  정리를 실행하려면 --cleanup 플래그를 추가하세요:');
        console.log('');
        console.log('   PowerShell:');
        console.log('   Get-Content .dev.vars | ForEach-Object { if ($_ -match \'^([^=]+)=(.*)$\') { [System.Environment]::SetEnvironmentVariable($matches[1], $matches[2], \'Process\') } } ; node scripts/cleanup-r2.js --cleanup');
        console.log('');
        console.log('   또는:');
        console.log('   npm run cleanup:r2');
      } else {
        console.log('\n✅ 버킷이 이미 깨끗합니다.');
      }
    }
    
    console.log('═══════════════════════════════════════════════════════════════\n');
    
  } catch (error) {
    console.error('\n❌ 스크립트 실행 실패:', error);
    process.exit(1);
  }
}

main();

