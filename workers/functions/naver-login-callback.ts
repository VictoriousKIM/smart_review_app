import { createClient } from '@supabase/supabase-js';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type, Authorization',
};

// Env 인터페이스는 index.ts에서 정의되어 있음
// 동적 import이므로 타입만 사용
interface Env {
  SUPABASE_URL: string;
  SUPABASE_SERVICE_ROLE_KEY: string;
  NAVER_PROVIDER_LOGIN_SECRET?: string;
}

interface NaverUserResponse {
  response: {
    id: string;
    email: string;
    name: string;
    profile_image?: string;
  };
}

/**
 * 네이버 로그인 콜백 처리
 * 
 * 1. 네이버 Access Token으로 사용자 정보 조회
 * 2. Supabase Admin API로 사용자 생성/로그인
 * 3. 세션 토큰 생성 및 반환
 */
export async function handleNaverLoginCallback(
  request: Request,
  env: Env
): Promise<Response> {
  // CORS preflight 처리
  if (request.method === 'OPTIONS') {
    return new Response(null, { headers: corsHeaders });
  }

  try {
    // 요청 본문에서 Access Token 추출
    const body = await request.json();
    const accessToken = body.accessToken;

    if (!accessToken) {
      return new Response(
        JSON.stringify({ error: 'Access token not found' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // 1. 네이버 API로 사용자 정보 조회
    const naverResponse = await fetch('https://openapi.naver.com/v1/nid/me', {
      headers: {
        Authorization: `Bearer ${accessToken}`,
      },
    });

    if (!naverResponse.ok) {
      return new Response(
        JSON.stringify({ error: 'Failed to fetch user info from Naver' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    const userData: NaverUserResponse = await naverResponse.json();
    const userEmail = userData.response?.email;

    if (!userEmail) {
      return new Response(
        JSON.stringify({ error: 'Email not found in Naver user data' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // 2. Supabase Admin 클라이언트 생성
    const supabaseAdmin = createClient(
      env.SUPABASE_URL,
      env.SUPABASE_SERVICE_ROLE_KEY,
      {
        auth: {
          autoRefreshToken: false,
          persistSession: false,
        },
      }
    );

    // 3. 기존 사용자 확인 (이메일로 검색)
    // listUsers()는 모든 사용자를 가져오므로 비효율적일 수 있음
    // 대신 getUserByEmail을 사용하거나, 직접 쿼리하는 방법을 고려
    // 하지만 Supabase Admin API에는 getUserByEmail이 없으므로, 
    // createUser를 시도하고 이미 존재하는 경우 에러를 처리하는 방식으로 변경
    
    let userId: string | undefined = undefined;
    let isNewUser = false;
    
    // 먼저 사용자 생성 시도 (이미 존재하면 에러 발생)
    const fixedPassword = env.NAVER_PROVIDER_LOGIN_SECRET || crypto.randomUUID();
    
    const { data: newUser, error: createError } = 
      await supabaseAdmin.auth.admin.createUser({
        email: userEmail,
        password: fixedPassword,
        email_confirm: true,
        app_metadata: {
          provider: 'naver',
          providers: ['naver'],
        },
        user_metadata: {
          iss: 'https://nid.naver.com',
          sub: userData.response.id,
          name: userData.response.name,
          email: userEmail,
          picture: userData.response.profile_image,
          full_name: userData.response.name,
          avatar_url: userData.response.profile_image,
          provider_id: userData.response.id,
          email_verified: true,
          phone_verified: false,
        },
      });

    if (createError) {
      // 이미 존재하는 경우
      if (createError.message.includes('already exists') || 
          createError.message.includes('User already registered') ||
          createError.message.includes('already registered')) {
        // 기존 사용자: 비밀번호 업데이트 후 로그인 시도
        console.log('기존 사용자 감지, 비밀번호 업데이트 시도:', userEmail);
        
        // 기존 사용자의 비밀번호를 업데이트 (Admin API 사용)
        // 먼저 사용자 정보 가져오기 (이메일로 검색은 불가능하므로, 
        // signInWithPassword 실패 시 비밀번호 업데이트를 시도)
      } else {
        // 다른 에러 (Service Role Key 문제 등)
        console.error('사용자 생성 실패:', createError);
        // 401 에러인 경우 Service Role Key 문제
        if (createError.message?.includes('401') || 
            createError.message?.includes('Unauthorized') ||
            createError.status === 401) {
          return new Response(
            JSON.stringify({ 
              error: 'Authentication failed. Please check SUPABASE_SERVICE_ROLE_KEY in Workers secrets.',
              details: '401 Unauthorized - Invalid or missing Service Role Key'
            }),
            { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
          );
        }
        return new Response(
          JSON.stringify({ 
            error: createError.message,
            details: 'Failed to create user'
          }),
          { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        );
      }
    } else {
      // 새 사용자 생성 성공
      userId = newUser.user.id;
      isNewUser = true;
    }


    // 4. 세션 토큰 생성 (Workers에서 직접 로그인하여 세션 생성)
    // 비밀번호를 클라이언트에 전달하지 않고, 서버에서 직접 세션 토큰 생성
    // Service Role Key로도 일반 auth API 사용 가능 (Admin 권한으로 로그인)
    // 참고: Service Role Key는 Admin API뿐만 아니라 일반 auth API도 사용 가능
    
    // 먼저 로그인 시도
    let sessionData: any = null;
    let signInError: any = null;
    
    const signInResult = await supabaseAdmin.auth.signInWithPassword({
      email: userEmail,
      password: fixedPassword,
    });
    
    sessionData = signInResult.data;
    signInError = signInResult.error;

    // 로그인 실패한 경우 (기존 사용자의 비밀번호가 다른 경우)
    if (signInError && !isNewUser) {
      // 기존 사용자의 비밀번호를 업데이트해야 함
      // 하지만 userId를 모르므로, listUsers()를 사용해야 함
      // 401 에러가 발생하므로, 일단 에러 반환하고 클라이언트에서 처리하도록 함
      console.error('기존 사용자 로그인 실패, 비밀번호 업데이트 필요:', signInError);
      
      return new Response(
        JSON.stringify({
          success: false,
          error: 'Failed to sign in existing user. Please try again or contact support.',
          details: signInError.message || 'Password mismatch',
          email: userEmail,
        }),
        {
          status: 500,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        }
      );
    }

    if (signInError || !sessionData?.session) {
      console.error('세션 생성 실패:', signInError);
      
      // 새 사용자인데 세션 생성 실패한 경우
      if (isNewUser) {
        return new Response(
          JSON.stringify({
            success: false,
            error: 'Failed to create session for new user',
            details: signInError?.message || 'Unknown error',
            userId,
            email: userEmail,
          }),
          {
            status: 500,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' },
          }
        );
      }
      
      return new Response(
        JSON.stringify({
          success: false,
          error: 'Failed to create session',
          details: signInError?.message || 'Unknown error',
          email: userEmail,
        }),
        {
          status: 500,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        }
      );
    }
    
    // 세션에서 userId 가져오기 (새 사용자가 아닌 경우)
    if (!userId) {
      userId = sessionData.session.user.id;
    }

    // 세션 토큰을 클라이언트에 전달 (비밀번호는 전달하지 않음)
    return new Response(
      JSON.stringify({
        success: true,
        userId,
        email: userEmail,
        isNewUser,
        // 세션 토큰 전달 (비밀번호 대신)
        accessToken: sessionData.session.access_token,
        refreshToken: sessionData.session.refresh_token,
        expiresAt: sessionData.session.expires_at,
        userMetadata: {
          name: userData.response.name,
          avatar_url: userData.response.profile_image,
        },
      }),
      {
        status: 200,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      }
    );
  } catch (error) {
    console.error('Error during Naver login callback:', error);
    return new Response(
      JSON.stringify({ error: 'Internal Server Error' }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }
}

