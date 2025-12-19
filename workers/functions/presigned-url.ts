import { createPresignedUrlSignature } from '../utils/r2-helpers';
import { formatTimestampWithMillis } from '../utils/date-helpers';
import { Env } from '../index';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type, Authorization',
};

export async function handlePresignedUrlForViewing(request: Request, env: Env): Promise<Response> {
  try {
    const { filePath } = await request.json();

    if (!filePath) {
      return new Response(
        JSON.stringify({ success: false, error: 'filePath is required' }),
        {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        }
      );
    }

    // Presigned URL 생성 (조회용, 1시간 유효)
    const presignedUrl = await createPresignedUrlSignature(
      'GET',
      filePath,
      'application/octet-stream',
      3600, // 1시간 유효
      env
    );

    return new Response(
      JSON.stringify({
        success: true,
        url: presignedUrl,
        filePath,
        expiresIn: 3600,
        expiresAt: Math.floor(Date.now() / 1000) + 3600,
        method: 'GET',
      }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      }
    );
  } catch (error) {
    return new Response(
      JSON.stringify({
        success: false,
        error: error instanceof Error ? error.message : 'Unknown error',
      }),
      {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      }
    );
  }
}

export async function handlePresignedUrl(request: Request, env: Env): Promise<Response> {
  try {
    const { 
      fileName, 
      userId, 
      contentType, 
      fileType, 
      method = 'PUT',
      // 새로운 파라미터
      companyId,      // 캠페인 이미지용
      productName,    // 캠페인 이미지용
      companyName     // 사업자등록증용
    } = await request.json();

    if (!fileName || !userId || !contentType || !fileType) {
      return new Response(
        JSON.stringify({ success: false, error: 'Missing required fields' }),
        {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        }
      );
    }

    // 파일 경로 생성
    const now = new Date();
    const timestamp = formatTimestampWithMillis(now);
    let filePath: string;

    // UUID 생성 (한글/특수문자 문제 해결을 위해 UUID 사용)
    const fileUuid = crypto.randomUUID();
    const extension = fileName.substring(fileName.lastIndexOf('.'));

    if (fileType === 'campaign-images') {
      // 캠페인 이미지: campaign-images/{companyId}/product/{timestamp}_{uuid}.jpg
      if (!companyId) {
        return new Response(
          JSON.stringify({ success: false, error: 'companyId is required for campaign-images' }),
          { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        );
      }
      filePath = `${fileType}/${companyId}/product/${timestamp}_${fileUuid}${extension}`;
    } else if (fileType === 'business-registration') {
      // 사업자등록증: business-registration/{timestamp}_{uuid}.png
      filePath = `${fileType}/${timestamp}_${fileUuid}${extension}`;
    } else {
      // 기타 파일 타입: {fileType}/{timestamp}_{uuid}.{extension}
      filePath = `${fileType}/${timestamp}_${fileUuid}${extension}`;
    }

    // Presigned URL 생성 (AWS Signature V4)
    const expiresIn = method === 'GET' ? 3600 : 900; // GET: 1시간, PUT: 15분
    const presignedUrl = await createPresignedUrlSignature(
      method,
      filePath,
      contentType,
      expiresIn,
      env
    );

    return new Response(
      JSON.stringify({
        success: true,
        url: presignedUrl,
        filePath,
        publicUrl: `${env.R2_PUBLIC_URL}/${filePath}`, // Public URL 추가
        expiresIn,
        expiresAt: Math.floor(Date.now() / 1000) + expiresIn,
        method,
      }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      }
    );
  } catch (error) {
    return new Response(
      JSON.stringify({
        success: false,
        error: error instanceof Error ? error.message : 'Unknown error',
      }),
      {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      }
    );
  }
}

