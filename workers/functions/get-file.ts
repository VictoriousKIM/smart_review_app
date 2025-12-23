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
    // 여러 번 인코딩된 경우를 대비하여 반복 디코딩
    let decodedKey = key;
    let previousKey = '';
    while (decodedKey !== previousKey && decodedKey.includes('%')) {
      previousKey = decodedKey;
      try {
        decodedKey = decodeURIComponent(decodedKey);
      } catch (e) {
        console.warn('⚠️ URL 디코딩 실패 (이전 값 사용):', decodedKey, e);
        break;
      }
    }
    key = decodedKey;

    console.log('📂 파일 조회 시도:', { 
      originalPath: url.pathname, 
      extractedKey: key,
      decodedKey: key 
    });

    // R2 바인딩 확인
    if (!env.FILES) {
      console.error('❌ R2 바인딩이 없습니다');
      return new Response(
        JSON.stringify({ error: 'R2 binding not configured' }),
        {
          status: 500,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        }
      );
    }

    let object;
    try {
      object = await env.FILES.get(key);
    } catch (getError) {
      console.error('❌ R2 get 호출 실패:', {
        key,
        error: getError instanceof Error ? getError.message : String(getError),
        stack: getError instanceof Error ? getError.stack : undefined,
      });
      return new Response(
        JSON.stringify({
          error: 'Failed to retrieve file from R2',
          details: getError instanceof Error ? getError.message : String(getError),
          key,
        }),
        {
          status: 500,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        }
      );
    }

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

