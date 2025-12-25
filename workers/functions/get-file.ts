import { Env } from '../index';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type, Authorization',
  'Access-Control-Expose-Headers': 'Content-Type, Content-Length',
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
    let decodeAttempts = 0;
    const maxDecodeAttempts = 5; // 최대 5번까지 디코딩 시도
    
    while (decodedKey !== previousKey && decodedKey.includes('%') && decodeAttempts < maxDecodeAttempts) {
      previousKey = decodedKey;
      decodeAttempts++;
      try {
        decodedKey = decodeURIComponent(decodedKey);
      } catch (e) {
        console.warn(`⚠️ URL 디코딩 실패 (시도 ${decodeAttempts}/${maxDecodeAttempts}):`, decodedKey, e);
        // 디코딩 실패 시 이전 값 사용
        decodedKey = previousKey;
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
      console.error('❌ 파일을 찾을 수 없음:', {
        key,
        originalPath: url.pathname,
        decodedKey: key,
      });
      return new Response(
        JSON.stringify({ 
          error: 'File not found', 
          key,
          originalPath: url.pathname,
        }),
        {
          status: 404,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        }
      );
    }

    console.log('✅ 파일 조회 성공:', key);

    // CORS 헤더와 함께 응답 생성
    const headers = new Headers(corsHeaders);
    const contentType = object.httpMetadata?.contentType || 'application/octet-stream';
    headers.set('Content-Type', contentType);
    
    // 캐시 헤더 추가 (이미지 성능 최적화)
    headers.set('Cache-Control', 'public, max-age=31536000, immutable');
    
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

