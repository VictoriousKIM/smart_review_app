import { Env } from '../index';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type, Authorization',
};

export async function handleGetFile(request: Request, env: Env): Promise<Response> {
  try {
    const url = new URL(request.url);
    let key = url.pathname.replace('/api/files/', '');

    if (!key) {
      return new Response(
        JSON.stringify({ error: 'File key is required' }),
        {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        }
      );
    }

    // URL 디코딩 (인코딩된 경로 처리)
    try {
      key = decodeURIComponent(key);
    } catch (e) {
      console.warn('⚠️ URL 디코딩 실패 (원본 사용):', key, e);
    }

    console.log('📂 파일 조회 시도:', { originalPath: url.pathname, extractedKey: key });

    const object = await env.FILES.get(key);
    if (!object) {
      console.error('❌ 파일을 찾을 수 없음:', key);
      return new Response(
        JSON.stringify({ error: 'File not found', key }),
        {
          status: 404,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        }
      );
    }

    console.log('✅ 파일 조회 성공:', key);

    const headers = new Headers(corsHeaders);
    headers.set('Content-Type', object.httpMetadata?.contentType || 'application/octet-stream');
    if (object.httpMetadata?.contentEncoding) {
      headers.set('Content-Encoding', object.httpMetadata.contentEncoding);
    }

    return new Response(object.body, { headers });
  } catch (error) {
    console.error('❌ 파일 조회 실패:', error);
    return new Response(
      JSON.stringify({
        error: error instanceof Error ? error.message : 'Unknown error',
      }),
      {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      }
    );
  }
}

