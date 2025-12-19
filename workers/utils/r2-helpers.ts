// R2 관련 유틸리티 함수들

export interface Env {
  R2_ACCOUNT_ID: string;
  R2_ACCESS_KEY_ID: string;
  R2_SECRET_ACCESS_KEY: string;
  R2_PUBLIC_URL: string;
}

// AWS Signature V4 호환 경로 인코딩
// RFC 3986에 따라 경로 세그먼트를 인코딩하되, 슬래시는 유지
export function encodePathSegment(segment: string): string {
  if (!segment) return segment;
  return encodeURIComponent(segment);
}

// 전체 경로 인코딩 (슬래시는 유지, 각 세그먼트만 인코딩)
export function encodePath(path: string): string {
  return path.split('/').map(encodePathSegment).join('/');
}

// SHA-256 해시 생성
export async function sha256(data: string): Promise<string> {
  const hashBuffer = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(data));
  return Array.from(new Uint8Array(hashBuffer))
    .map(b => b.toString(16).padStart(2, '0'))
    .join('');
}

// HMAC-SHA256 바이너리 서명 생성
export async function hmacSha256Binary(key: string | Uint8Array, data: string): Promise<Uint8Array> {
  const keyBuffer = typeof key === 'string' ? new TextEncoder().encode(key) : new Uint8Array(key);
  const dataBuffer = new TextEncoder().encode(data);
  
  const cryptoKey = await crypto.subtle.importKey(
    'raw',
    keyBuffer.buffer,
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['sign']
  );
  
  const signature = await crypto.subtle.sign('HMAC', cryptoKey, dataBuffer);
  return new Uint8Array(signature);
}

// AWS Signature V4를 사용한 Presigned URL 생성
export async function createPresignedUrlSignature(
  method: string,
  filePath: string,
  contentType: string,
  expiresIn: number,
  env: Env
): Promise<string> {
  const region = 'auto';
  const service = 's3';
  const algorithm = 'AWS4-HMAC-SHA256';
  
  // 경로 인코딩 (Canonical Request와 실제 URL에서 동일하게 사용)
  // Cloudflare R2는 bucket binding을 사용하므로 bucket name을 경로에 포함하지 않음
  const encodedPath = encodePath(filePath);
  const canonicalPath = `/${encodedPath}`;
  
  const host = `${env.R2_ACCOUNT_ID}.r2.cloudflarestorage.com`;
  const date = new Date();
  const dateStamp = date.toISOString().slice(0, 10).replace(/-/g, '');
  const amzDate = date.toISOString().replace(/[:\-]|\.\d{3}/g, '');
  
  // Query string parameters
  const queryParams = new URLSearchParams({
    'X-Amz-Algorithm': algorithm,
    'X-Amz-Credential': `${env.R2_ACCESS_KEY_ID}/${dateStamp}/${region}/${service}/aws4_request`,
    'X-Amz-Date': amzDate,
    'X-Amz-Expires': expiresIn.toString(),
    'X-Amz-SignedHeaders': 'host',
  });
  
  // Canonical Request (인코딩된 경로 사용)
  const canonicalHeaders = `host:${host}\n`;
  const signedHeaders = 'host';
  const canonicalRequest = [
    method,
    canonicalPath,  // 인코딩된 경로 사용 (bucket name 제외)
    queryParams.toString(),
    canonicalHeaders,
    signedHeaders,
    'UNSIGNED-PAYLOAD'
  ].join('\n');
  
  // String to Sign
  const credentialScope = `${dateStamp}/${region}/${service}/aws4_request`;
  const hashedCanonicalRequest = await sha256(canonicalRequest);
  const stringToSign = [
    algorithm,
    amzDate,
    credentialScope,
    hashedCanonicalRequest
  ].join('\n');
  
  // 서명 생성
  const kSecret = `AWS4${env.R2_SECRET_ACCESS_KEY}`;
  const kDate = await hmacSha256Binary(kSecret, dateStamp);
  const kRegion = await hmacSha256Binary(kDate, region);
  const kService = await hmacSha256Binary(kRegion, service);
  const kSigning = await hmacSha256Binary(kService, 'aws4_request');
  
  const signatureBuffer = await hmacSha256Binary(kSigning, stringToSign);
  const signature = Array.from(signatureBuffer)
    .map(b => b.toString(16).padStart(2, '0'))
    .join('');
  
  // Presigned URL 생성 (동일한 인코딩된 경로 사용, bucket name 제외)
  queryParams.set('X-Amz-Signature', signature);
  const fullPath = `/${encodedPath}`;
  return `https://${host}${fullPath}?${queryParams.toString()}`;
}

