import { createClient } from '@supabase/supabase-js';
import * as jose from 'jose';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

interface RequestBody {
  platform: 'web' | 'mobile';
  accessToken?: string;  // 모바일: 네이버 SDK에서 받은 토큰
  code?: string;         // 웹: 네이버 OAuth code
  state?: string;        // 웹: OAuth state (선택사항)
}

interface NaverUserInfo {
  id: string;
  email: string;
  name: string;
  profile_image: string;
  nickname: string;
}

interface NaverTokenResponse {
  access_token: string;
  refresh_token?: string;
  token_type: string;
  expires_in: number;
  error?: string;
  error_description?: string;
}

interface Env {
  NAVER_CLIENT_ID: string;
  NAVER_CLIENT_SECRET: string;
  NAVER_REDIRECT_URI: string;
  SUPABASE_URL: string;
  SUPABASE_SERVICE_ROLE_KEY: string;
  JWT_SECRET: string;
}

// BOM 제거 유틸리티 함수 (UTF-8 BOM: \uFEFF 또는 %EF%BB%BF)
function removeBOM(str: string | undefined): string {
  if (!str) return '';
  return str.replace(/^\uFEFF/, '').trim();
}

// 웹용: 네이버 code → access_token 교환
// Edge Function과 동일한 구현
async function exchangeCodeForToken(
  code: string,
  clientId: string,
  clientSecret: string,
  redirectUri: string
): Promise<string> {
  const response = await fetch('https://nid.naver.com/oauth2.0/token', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/x-www-form-urlencoded',
    },
    body: new URLSearchParams({
      grant_type: 'authorization_code',
      client_id: clientId,
      client_secret: clientSecret,
      code: code,
      redirect_uri: redirectUri,
    }),
  });

  if (!response.ok) {
    const errorText = await response.text();
    console.error('네이버 API 응답 실패:');
    console.error('  - Status:', response.status);
    console.error('  - Status Text:', response.statusText);
    console.error('  - Response Body:', errorText);
    throw new Error(`네이버 토큰 교환 실패: ${response.status} - ${errorText}`);
  }

  const data: NaverTokenResponse = await response.json();

  if (data.error) {
    console.error('네이버 API 에러 응답:');
    console.error('  - Error:', data.error);
    console.error('  - Error Description:', data.error_description);
    console.error('  - Full Response:', JSON.stringify(data, null, 2));
    throw new Error(`네이버 토큰 교환 오류: ${data.error} - ${data.error_description}`);
  }

  if (!data.access_token) {
    throw new Error('네이버 access_token이 없습니다');
  }

  return data.access_token;
}

// 네이버 토큰으로 사용자 정보 조회
async function getNaverUserInfo(accessToken: string): Promise<NaverUserInfo> {
  const response = await fetch('https://openapi.naver.com/v1/nid/me', {
    headers: {
      'Authorization': `Bearer ${accessToken}`,
    },
  });

  if (!response.ok) {
    const errorText = await response.text();
    throw new Error(`네이버 토큰 검증 실패: ${response.status} - ${errorText}`);
  }

  const data = await response.json();

  if (data.resultcode !== '00') {
    throw new Error(`네이버 사용자 정보 조회 실패: ${data.message || '알 수 없는 오류'}`);
  }

  return {
    id: data.response.id,
    email: data.response.email,
    name: data.response.name,
    profile_image: data.response.profile_image || '',
    nickname: data.response.nickname || data.response.name,
  };
}

// Supabase JWT 생성
async function createSupabaseJWT(userId: string, email: string, jwtSecret: string): Promise<string> {
  if (!jwtSecret) {
    throw new Error('JWT_SECRET이 설정되지 않았습니다');
  }

  const secretKey = new TextEncoder().encode(jwtSecret);
  const now = Math.floor(Date.now() / 1000);

  const token = await new jose.SignJWT({
    aud: 'authenticated',
    exp: now + (60 * 60 * 24), // 24시간
    iat: now,
    sub: userId,
    email: email,
    role: 'authenticated',
    app_metadata: {
      provider: 'naver',
      providers: ['naver'],
    },
    user_metadata: {},
  })
    .setProtectedHeader({ alg: 'HS256', typ: 'JWT' })
    .sign(secretKey);

  return token;
}

export default async function handleNaverAuth(request: Request, env: Env): Promise<Response> {
  // CORS preflight
  if (request.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    // 요청 정보 로깅
    console.log('=== Workers API 요청 수신 ===');
    console.log('Method:', request.method);
    console.log('URL:', request.url);
    console.log('Headers:', Object.fromEntries(request.headers.entries()));

    // 환경 변수 확인 (디버깅용 - 실제 값 일부 표시)
    console.log('Environment variables check:');
    console.log('JWT_SECRET:', env.JWT_SECRET ? 'SET' : 'NOT SET');
    console.log('NAVER_CLIENT_ID:', env.NAVER_CLIENT_ID || 'NOT SET');
    console.log('NAVER_CLIENT_SECRET:', env.NAVER_CLIENT_SECRET ? `${env.NAVER_CLIENT_SECRET.substring(0, 3)}...` : 'NOT SET');
    console.log('NAVER_REDIRECT_URI:', env.NAVER_REDIRECT_URI || 'http://localhost:3001/loading');
    console.log('SUPABASE_URL:', env.SUPABASE_URL ? 'SET' : 'NOT SET');

    // 요청 본문 파싱
    let body: RequestBody;
    try {
      const bodyText = await request.text();
      console.log('Request body (raw):', bodyText);
      body = JSON.parse(bodyText) as RequestBody;
    } catch (parseError) {
      console.error('JSON 파싱 실패:', parseError);
      throw new Error(`요청 본문 파싱 실패: ${parseError instanceof Error ? parseError.message : String(parseError)}`);
    }
    
    const { platform, accessToken, code, state } = body;
    console.log('Request body (parsed):', { platform, hasCode: !!code, hasAccessToken: !!accessToken, state });

    if (!platform) {
      throw new Error('platform 파라미터가 필요합니다 (web 또는 mobile)');
    }

    let finalAccessToken: string;

    // 플랫폼별 토큰 처리
    if (platform === 'web' && code) {
      // 웹: Workers 내부에서 code → access_token 교환
      // Edge Function과 동일하게 기본값 사용
      const clientId = removeBOM(env.NAVER_CLIENT_ID);
      const clientSecret = removeBOM(env.NAVER_CLIENT_SECRET);
      const redirectUri = removeBOM(env.NAVER_REDIRECT_URI) || 'http://localhost:3001/loading';

      if (!clientId || !clientSecret) {
        throw new Error('NAVER_CLIENT_ID 또는 NAVER_CLIENT_SECRET이 설정되지 않았습니다');
      }

      // Edge Function과 동일하게 토큰 교환
      console.log('네이버 토큰 교환 시도:');
      console.log('  - Client ID:', clientId);
      console.log('  - Client Secret:', clientSecret ? `${clientSecret.substring(0, 3)}...` : 'NOT SET');
      console.log('  - Client Secret Length:', clientSecret?.length || 0);
      console.log('  - Redirect URI:', redirectUri);
      console.log('  - Code:', code);
      
      // 실제 전송되는 요청 본문 확인
      const requestBody = new URLSearchParams({
        grant_type: 'authorization_code',
        client_id: clientId,
        client_secret: clientSecret,
        code: code,
        redirect_uri: redirectUri,
      });
      console.log('  - Request Body (URLSearchParams):', requestBody.toString());
      
      finalAccessToken = await exchangeCodeForToken(code, clientId, clientSecret, redirectUri);
    } else if (platform === 'mobile' && accessToken) {
      // 모바일: 이미 받은 accessToken 사용
      finalAccessToken = accessToken;
    } else {
      throw new Error('웹의 경우 code가, 모바일의 경우 accessToken이 필요합니다');
    }

    // 1. 네이버에서 사용자 정보 가져오기
    const naverUser = await getNaverUserInfo(finalAccessToken);

    // 2. Supabase Admin 클라이언트 생성
    const supabaseUrl = removeBOM(env.SUPABASE_URL);
    const supabaseServiceKey = removeBOM(env.SUPABASE_SERVICE_ROLE_KEY);

    if (!supabaseUrl || !supabaseServiceKey) {
      throw new Error('SUPABASE_URL 또는 SUPABASE_SERVICE_ROLE_KEY가 설정되지 않았습니다');
    }

    console.log('Supabase Admin Client 생성:');
    console.log('  - URL:', supabaseUrl);
    console.log('  - Service Key (first 20 chars):', supabaseServiceKey ? `${supabaseServiceKey.substring(0, 20)}...` : 'NOT SET');
    console.log('  - Service Key length:', supabaseServiceKey?.length || 0);
    console.log('  - Service Key (last 20 chars):', supabaseServiceKey ? `...${supabaseServiceKey.substring(supabaseServiceKey.length - 20)}` : 'NOT SET');
    
    // Service Role Key 검증: JWT를 디코딩해서 role이 "service_role"인지 확인
    try {
      const jwtParts = supabaseServiceKey.split('.');
      if (jwtParts.length === 3) {
        const payload = JSON.parse(atob(jwtParts[1]));
        console.log('  - JWT role:', payload.role || 'NOT FOUND');
        if (payload.role !== 'service_role') {
          console.error('  ⚠️ WARNING: Key role is not "service_role"! Current role:', payload.role);
          console.error('  ⚠️ Admin API (listUsers, createUser) requires service_role key, not anon key!');
        } else {
          console.log('  ✅ Key role is "service_role" (correct)');
        }
      }
    } catch (e) {
      console.warn('  ⚠️ Could not decode JWT to verify role:', e);
    }

    // Supabase Admin 클라이언트 생성
    // Service Role Key를 apikey로도 사용 (Admin API 호출 시 필요)
    const supabaseAdmin = createClient(supabaseUrl, supabaseServiceKey, {
      auth: {
        autoRefreshToken: false,
        persistSession: false,
        // Admin API 호출을 위해 apikey 헤더 명시
        detectSessionInUrl: false,
      },
      global: {
        fetch: globalThis.fetch,
        headers: {
          'apikey': supabaseServiceKey,
          'Authorization': `Bearer ${supabaseServiceKey}`,
        },
      },
    });

    // 3. 기존 사용자 조회 (이메일로)
    console.log('기존 사용자 조회 시작...');
    const { data: existingUsers, error: listError } = await supabaseAdmin.auth.admin.listUsers();
    
    if (listError) {
      console.error('사용자 목록 조회 에러:', listError);
      throw new Error(`사용자 목록 조회 실패: ${listError.message}`);
    }
    
    console.log('사용자 목록 조회 성공, 총 사용자 수:', existingUsers?.users?.length || 0);
    const existingUser = existingUsers?.users.find(u => u.email === naverUser.email);

    let userId: string;

    if (existingUser) {
      // 기존 사용자
      userId = existingUser.id;

      // user_metadata 업데이트 (프로필 이미지 등)
      await supabaseAdmin.auth.admin.updateUserById(userId, {
        user_metadata: {
          ...existingUser.user_metadata,
          full_name: naverUser.name,
          avatar_url: naverUser.profile_image,
          provider: 'naver',
          naver_id: naverUser.id,
        },
      });
    } else {
      // 4. 새 사용자 생성
      const { data: newUser, error: createError } = await supabaseAdmin.auth.admin.createUser({
        email: naverUser.email,
        email_confirm: true, // 이메일 확인 스킵
        user_metadata: {
          full_name: naverUser.name,
          avatar_url: naverUser.profile_image,
          provider: 'naver',
          naver_id: naverUser.id,
        },
        app_metadata: {
          provider: 'naver',
          providers: ['naver'],
        },
      });

      if (createError) {
        // 이메일 중복인 경우 기존 계정 연결
        if (createError.message.includes('already exists') || 
            createError.message.includes('already registered')) {
          const { data: retryUsers } = await supabaseAdmin.auth.admin.listUsers();
          const retryUser = retryUsers?.users.find(u => u.email === naverUser.email);
          
          if (retryUser) {
            userId = retryUser.id;
            // user_metadata 업데이트
            await supabaseAdmin.auth.admin.updateUserById(userId, {
              user_metadata: {
                ...retryUser.user_metadata,
                full_name: naverUser.name,
                avatar_url: naverUser.profile_image,
                provider: 'naver',
                naver_id: naverUser.id,
              },
            });
          } else {
            throw createError;
          }
        } else {
          throw createError;
        }
      } else {
        if (!newUser?.user) {
          throw new Error('사용자 생성 실패: user 객체가 null입니다');
        }
        userId = newUser.user.id;
      }
    }

    // 5. public.users 테이블에 프로필 자동 생성하지 않음
    // 프로필이 없으면 Flutter 앱에서 회원가입 화면으로 리다이렉트됨
    // (카카오 로그인과 동일한 동작)

    // 6. Supabase JWT 생성
    const customJWT = await createSupabaseJWT(userId, naverUser.email, env.JWT_SECRET);

    // 7. Refresh Token 생성 (선택사항 - UUID 기반)
    const refreshToken = crypto.randomUUID();

    return new Response(
      JSON.stringify({
        access_token: customJWT,
        refresh_token: refreshToken,
        token_type: 'bearer',
        expires_in: 86400, // 24시간
        user: {
          id: userId,
          email: naverUser.email,
          user_metadata: {
            full_name: naverUser.name,
            avatar_url: naverUser.profile_image,
          },
        },
      }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200,
      }
    );

  } catch (error) {
    console.error('Workers 오류:', error);
    console.error('Error type:', typeof error);
    console.error('Error name:', (error as any)?.name);
    console.error('Error message:', (error as any)?.message);
    console.error('Error stack:', (error as any)?.stack);
    
    return new Response(
      JSON.stringify({ 
        error: error instanceof Error ? error.message : '알 수 없는 오류가 발생했습니다',
        details: error instanceof Error ? error.stack : String(error),
        type: (error as any)?.constructor?.name || typeof error,
      }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: error instanceof Error && error.message.includes('설정되지 않았습니다') ? 500 : 400,
      }
    );
  }
}
