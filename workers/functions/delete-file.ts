import { Env } from '../index';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type, Authorization',
};

interface DeleteFileRequest {
  fileUrl: string;
}

export async function handleDeleteFile(request: Request, env: Env): Promise<Response> {
  try {
    const requestData: DeleteFileRequest = await request.json();
    const { fileUrl } = requestData;

    if (!fileUrl) {
      return new Response(
        JSON.stringify({ success: false, error: 'fileUrl이 필요합니다.' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // R2 Public URL 또는 Workers API URL에서 파일 경로 추출
    // 예: https://7b72031b240604b8e9f88904de2f127c.r2.cloudflarestorage.com/business-registration/20250115143025_filename.png
    // 예: https://7b72031b240604b8e9f88904de2f127c.r2.cloudflarestorage.com/campaign-images/{companyId}/product/...
    // 예: https://workers-url/api/files/campaign-images/{companyId}/product/...
    const urlObj = new URL(fileUrl);
    let filePath = urlObj.pathname.substring(1); // 첫 번째 '/' 제거

    // Workers API URL 형식인 경우 (/api/files/ 제거)
    if (filePath.startsWith('api/files/')) {
      filePath = filePath.substring('api/files/'.length);
    }

    // URL 디코딩 (인코딩된 경로 처리)
    try {
      filePath = decodeURIComponent(filePath);
    } catch (e) {
      console.warn('⚠️ URL 디코딩 실패 (원본 사용):', filePath, e);
    }

    // 허용된 파일 경로 확인
    if (!filePath.startsWith('business-registration/') && 
        !filePath.startsWith('campaign-images/')) {
      console.error('❌ 유효하지 않은 파일 경로:', filePath, '원본 URL:', fileUrl);
      return new Response(
        JSON.stringify({ 
          success: false, 
          error: `유효하지 않은 파일 경로입니다: ${filePath}` 
        }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    console.log('🗑️ 파일 삭제 시도:', { 
      originalUrl: fileUrl, 
      extractedPath: filePath,
      pathname: urlObj.pathname 
    });

    // R2에서 파일 삭제
    try {
      await env.FILES.delete(filePath);
      console.log('✅ 파일 삭제 성공:', filePath);
      return new Response(
        JSON.stringify({ success: true, message: '파일이 삭제되었습니다.' }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    } catch (deleteError) {
      console.error('❌ R2 파일 삭제 실패:', deleteError, '경로:', filePath);
      throw deleteError;
    }
  } catch (error) {
    console.error('❌ 파일 삭제 실패:', error);
    return new Response(
      JSON.stringify({
        success: false,
        error: error instanceof Error ? error.message : '파일 삭제 실패',
      }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }
}

