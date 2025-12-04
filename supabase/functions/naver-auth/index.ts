import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import * as jose from 'https://deno.land/x/jose@v4.14.4/index.ts'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

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

// 웹용: 네이버 code → access_token 교환
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
    throw new Error(`네이버 토큰 교환 실패: ${response.status} - ${errorText}`);
  }

  const data: NaverTokenResponse = await response.json();

  if (data.error) {
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
async function createSupabaseJWT(userId: string, email: string): Promise<string> {
  // SUPABASE_로 시작하는 환경 변수는 사용할 수 없으므로 JWT_SECRET 사용
  const jwtSecret = Deno.env.get('JWT_SECRET');
  
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

serve(async (req) => {
  // CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    // 환경 변수 확인 (디버깅용)
    // 주의: SUPABASE_로 시작하는 환경 변수는 Edge Function에서 사용할 수 없음
    console.log('Environment variables check:');
    console.log('JWT_SECRET:', Deno.env.get('JWT_SECRET') ? 'SET' : 'NOT SET');
    console.log('NAVER_CLIENT_ID:', Deno.env.get('NAVER_CLIENT_ID') ? 'SET' : 'NOT SET');
    console.log('NAVER_CLIENT_SECRET:', Deno.env.get('NAVER_CLIENT_SECRET') ? 'SET' : 'NOT SET');
    console.log('NAVER_REDIRECT_URI:', Deno.env.get('NAVER_REDIRECT_URI') || 'http://localhost:3001/loading');

    const body: RequestBody = await req.json();
    const { platform, accessToken, code, state } = body;
    
    console.log('Request body:', { platform, hasCode: !!code, hasAccessToken: !!accessToken });

    if (!platform) {
      throw new Error('platform 파라미터가 필요합니다 (web 또는 mobile)');
    }

    let finalAccessToken: string;

    // 플랫폼별 토큰 처리
    if (platform === 'web' && code) {
      // 웹: Edge Function 내부에서 code → access_token 교환
      const clientId = Deno.env.get('NAVER_CLIENT_ID');
      const clientSecret = Deno.env.get('NAVER_CLIENT_SECRET');
      const redirectUri = Deno.env.get('NAVER_REDIRECT_URI') || 'http://localhost:3001/loading';

      if (!clientId || !clientSecret) {
        throw new Error('NAVER_CLIENT_ID 또는 NAVER_CLIENT_SECRET이 설정되지 않았습니다');
      }

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
    // 주의: SUPABASE_로 시작하는 환경 변수는 Edge Function에서 사용할 수 없음
    // 로컬 개발 환경: Docker 컨테이너 내부에서 호스트에 접근하려면 host.docker.internal 사용
    // Windows에서는 host.docker.internal이 작동하지 않을 수 있으므로, 
    // Supabase Edge Function은 내부 네트워크를 통해 자동으로 연결됨
    // 로컬 개발 환경에서는 gateway를 통해 접근: http://kong:8000
    const supabaseUrl = 'http://kong:8000'; // 로컬 개발: Supabase 내부 게이트웨이
    const supabaseServiceKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImV4cCI6MTk4MzgxMjk5Nn0.EGIM96RAZx35lJzdJsyH-qQwv8Hdp7fsn3W0YpN81IU'; // 로컬 개발용 Service Role Key

    console.log('Supabase Admin Client 생성:');
    console.log('  - URL:', supabaseUrl);

    const supabaseAdmin = createClient(
      supabaseUrl,
      supabaseServiceKey,
      {
        auth: {
          autoRefreshToken: false,
          persistSession: false,
        },
      }
    );

    // 3. 기존 사용자 조회 (이메일로)
    const { data: existingUsers } = await supabaseAdmin.auth.admin.listUsers();
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
    const customJWT = await createSupabaseJWT(userId, naverUser.email);

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
    console.error('Edge Function 오류:', error);
    console.error('Error type:', typeof error);
    console.error('Error name:', error?.name);
    console.error('Error message:', error?.message);
    console.error('Error stack:', error?.stack);
    
    return new Response(
      JSON.stringify({ 
        error: error instanceof Error ? error.message : '알 수 없는 오류가 발생했습니다',
        details: error instanceof Error ? error.stack : String(error),
        type: error?.constructor?.name || typeof error,
      }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: error instanceof Error && error.message.includes('설정되지 않았습니다') ? 500 : 400,
      }
    );
  }
});

