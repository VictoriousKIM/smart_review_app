import { formatTimestamp } from '../utils/date-helpers';
import { Env } from '../index';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type, Authorization',
};

export async function handleUpload(request: Request, env: Env): Promise<Response> {
  try {
    const formData = await request.formData();
    const file = formData.get('file') as File;
    const userId = formData.get('userId') as string;
    const fileType = formData.get('fileType') as string;
    const companyId = formData.get('companyId') as string | null;

    if (!file || !userId || !fileType) {
      return new Response(
        JSON.stringify({ success: false, error: 'Missing required fields' }),
        {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        }
      );
    }

    // 파일 경로 생성 (UUID 추가로 중복 방지)
    const now = new Date();
    const timestamp = formatTimestamp(now);
    const fileUuid = crypto.randomUUID();
    const extension = file.name.substring(file.name.lastIndexOf('.'));
    const baseFileName = file.name.substring(0, file.name.lastIndexOf('.')) || 'file';

    let key: string;
    if (fileType === 'campaign-images' && companyId) {
      // 캠페인 이미지: campaign-images/{companyId}/product/{timestamp}_{uuid}.jpg
      key = `${fileType}/${companyId}/product/${timestamp}_${fileUuid}${extension}`;
    } else {
      // 기타 파일 타입: {fileType}/{timestamp}_{uuid}_{baseFileName}.{extension}
      key = `${fileType}/${timestamp}_${fileUuid}_${baseFileName}${extension}`;
    }

    // R2에 업로드
    await env.FILES.put(key, file.stream(), {
      httpMetadata: {
        contentType: file.type,
      },
      customMetadata: {
        userId,
        fileType,
        uploadedAt: new Date().toISOString(),
      },
    });

    const publicUrl = `${env.R2_PUBLIC_URL}/${key}`;

    return new Response(
      JSON.stringify({
        success: true,
        url: publicUrl,
        key,
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

