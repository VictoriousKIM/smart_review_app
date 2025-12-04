// Cloudflare Workers 타입 정의
interface R2Bucket {
  put(key: string, value: ReadableStream | ArrayBuffer | ArrayBufferView | string | null | Blob, options?: R2PutOptions): Promise<R2Object>;
  get(key: string, options?: R2GetOptions): Promise<R2ObjectBody | null>;
  delete(keys: string | string[]): Promise<void>;
}

interface R2PutOptions {
  httpMetadata?: {
    contentType?: string;
    contentEncoding?: string;
  };
  customMetadata?: Record<string, string>;
}

interface R2GetOptions {
  onlyIf?: {
    etag?: string;
    uploadedBefore?: Date;
    uploadedAfter?: Date;
  };
}

interface R2Object {
  key: string;
  version: string;
  size: number;
  etag: string;
  httpEtag: string;
  uploaded: Date;
  httpMetadata?: {
    contentType?: string;
    contentEncoding?: string;
  };
  customMetadata?: Record<string, string>;
}

interface R2ObjectBody extends R2Object {
  body: ReadableStream;
  bodyUsed: boolean;
  arrayBuffer(): Promise<ArrayBuffer>;
  text(): Promise<string>;
  json<T = unknown>(): Promise<T>;
  blob(): Promise<Blob>;
}

export interface Env {
  FILES: R2Bucket;
  R2_ACCOUNT_ID: string;
  R2_ACCESS_KEY_ID: string;
  R2_SECRET_ACCESS_KEY: string;
  R2_BUCKET_NAME: string;
  R2_PUBLIC_URL: string;
  SUPABASE_URL: string;
  SUPABASE_SERVICE_ROLE_KEY: string;
  GEMINI_API_KEY: string;
  NTS_API_KEY: string;
}

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type, Authorization',
};

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url);

    // OPTIONS 요청 처리
    if (request.method === 'OPTIONS') {
      return new Response(null, { headers: corsHeaders });
    }

    // Health check
    if (url.pathname === '/health') {
      return new Response(
        JSON.stringify({
          status: 'ok',
          timestamp: new Date().toISOString(),
          service: 'smart-review-api',
        }),
        {
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        }
      );
    }

    // API 라우팅
    if (url.pathname === '/api/presigned-url' && request.method === 'POST') {
      return handlePresignedUrl(request, env);
    }

    if (url.pathname === '/api/presigned-url-view' && request.method === 'POST') {
      return handlePresignedUrlForViewing(request, env);
    }

    if (url.pathname === '/api/upload' && request.method === 'POST') {
      return handleUpload(request, env);
    }

    if (url.pathname.startsWith('/api/files/') && request.method === 'GET') {
      return handleGetFile(request, env);
    }

    if (url.pathname === '/api/verify-and-register' && request.method === 'POST') {
      return handleVerifyAndRegister(request, env);
    }

    if (url.pathname === '/api/delete-file' && request.method === 'POST') {
      return handleDeleteFile(request, env);
    }

    if (url.pathname === '/api/analyze-campaign-image' && request.method === 'POST') {
      return handleAnalyzeCampaignImage(request, env);
    }

    if (url.pathname === '/api/auth/callback/naver' && request.method === 'POST') {
      // 네이버 로그인 콜백은 별도 파일에서 import
      const { handleNaverLoginCallback } = await import('./functions/naver-login-callback');
      return handleNaverLoginCallback(request, env);
    }

    return new Response(
      JSON.stringify({ error: 'Not Found', path: url.pathname }),
      { status: 404, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  },
};

async function handlePresignedUrlForViewing(request: Request, env: Env): Promise<Response> {
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

async function handlePresignedUrl(request: Request, env: Env): Promise<Response> {
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

// AWS Signature V4 호환 경로 인코딩
// RFC 3986에 따라 경로 세그먼트를 인코딩하되, 슬래시는 유지
function encodePathSegment(segment: string): string {
  if (!segment) return segment;
  // encodeURIComponent는 대부분의 특수 문자를 인코딩하지만,
  // AWS Signature V4에서는 추가로 일부 문자를 인코딩해야 할 수 있음
  // 현재는 encodeURIComponent로 충분하지만, 필요시 추가 인코딩 가능
  return encodeURIComponent(segment);
}

// 전체 경로 인코딩 (슬래시는 유지, 각 세그먼트만 인코딩)
function encodePath(path: string): string {
  return path.split('/').map(encodePathSegment).join('/');
}

// AWS Signature V4를 사용한 Presigned URL 생성
async function createPresignedUrlSignature(
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
  const encodedPath = encodePath(filePath);
  const canonicalPath = `/${env.R2_BUCKET_NAME}/${encodedPath}`;
  
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
    canonicalPath,  // 인코딩된 경로 사용
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
  
  // Presigned URL 생성 (동일한 인코딩된 경로 사용)
  queryParams.set('X-Amz-Signature', signature);
  const fullPath = `/${env.R2_BUCKET_NAME}/${encodedPath}`;
  return `https://${host}${fullPath}?${queryParams.toString()}`;
}

async function sha256(data: string): Promise<string> {
  const hashBuffer = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(data));
  return Array.from(new Uint8Array(hashBuffer))
    .map(b => b.toString(16).padStart(2, '0'))
    .join('');
}

async function hmacSha256Binary(key: string | Uint8Array, data: string): Promise<Uint8Array> {
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

async function handleUpload(request: Request, env: Env): Promise<Response> {
  try {
    const formData = await request.formData();
    const file = formData.get('file') as File;
    const userId = formData.get('userId') as string;
    const fileType = formData.get('fileType') as string;

    if (!file || !userId || !fileType) {
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
    const timestamp = formatTimestamp(now);

    const key = `${fileType}/${timestamp}_${file.name}`;

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

async function handleGetFile(request: Request, env: Env): Promise<Response> {
  try {
    const url = new URL(request.url);
    const key = url.pathname.replace('/api/files/', '');

    if (!key) {
      return new Response(
        JSON.stringify({ error: 'File key is required' }),
        {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        }
      );
    }

    const object = await env.FILES.get(key);
    if (!object) {
      return new Response(
        JSON.stringify({ error: 'File not found' }),
        {
          status: 404,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        }
      );
    }

    const headers = new Headers(corsHeaders);
    headers.set('Content-Type', object.httpMetadata?.contentType || 'application/octet-stream');
    if (object.httpMetadata?.contentEncoding) {
      headers.set('Content-Encoding', object.httpMetadata.contentEncoding);
    }

    return new Response(object.body, { headers });
  } catch (error) {
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

// ============================================
// 사업자등록증 검증 및 등록 통합 처리
// ============================================

interface VerifyAndRegisterRequest {
  image: string; // base64 인코딩된 이미지
  fileName: string;
  userId: string;
}

interface VerifyAndRegisterResponse {
  success: boolean;
  extractedData?: any;
  validationResult?: any;
  presignedUrl?: string;
  filePath?: string;
  publicUrl?: string;
  error?: string;
  step?: string;
  debugInfo?: any;
}

async function handleVerifyAndRegister(request: Request, env: Env): Promise<Response> {
  try {
    let requestData: VerifyAndRegisterRequest;
    
    try {
      requestData = await request.json();
    } catch (jsonError) {
      console.error('❌ JSON 파싱 실패:', jsonError);
      return new Response(
        JSON.stringify({ 
          success: false, 
          error: `요청 데이터 파싱 실패: ${jsonError instanceof Error ? jsonError.message : String(jsonError)}`,
          debugInfo: {
            contentType: request.headers.get('content-type'),
            hasBody: !!request.body,
          }
        }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    const { image, fileName, userId } = requestData;

    // 필수 필드 검증
    const missingFields: string[] = [];
    if (!image) missingFields.push('image');
    if (!fileName) missingFields.push('fileName');
    if (!userId) missingFields.push('userId');

    if (missingFields.length > 0) {
      console.error('❌ 필수 필드 누락:', missingFields);
      return new Response(
        JSON.stringify({ 
          success: false, 
          error: `Missing required fields: ${missingFields.join(', ')}`,
          debugInfo: {
            receivedFields: {
              hasImage: !!image,
              imageLength: image ? image.length : 0,
              fileName: fileName || null,
              userId: userId || null,
            }
          }
        }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    let extractedData: any = null;
    let validationResult: any = null;

    try {
      // 0단계: 이미지 검증
      const isBusinessRegistration = await verifyBusinessRegistrationImage(image, env);
      if (!isBusinessRegistration) {
        return new Response(
          JSON.stringify({
            success: false,
            error: '업로드된 이미지가 사업자등록증이 아닙니다.',
            step: 'image_verification',
          }),
          { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        );
      }

      // 1단계: AI 추출
      try {
        extractedData = await extractBusinessInfo(image, env);
        if (!extractedData.business_number) {
          throw new Error(`사업자등록번호를 추출할 수 없습니다. 추출된 데이터: ${JSON.stringify(extractedData)}`);
        }
      } catch (extractError) {
        const errorMessage = extractError instanceof Error ? extractError.message : String(extractError);
        console.error('❌ AI 추출 실패:', errorMessage);
        return new Response(
          JSON.stringify({
            success: false,
            error: `AI 추출 실패: ${errorMessage}`,
            step: 'extraction',
          }),
          { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        );
      }

      // AI 추출 데이터 검증 (회사명 확인)
      if (!extractedData || !extractedData.business_name) {
        return new Response(
          JSON.stringify({
            success: false,
            error: '회사명을 추출할 수 없습니다. 이미지를 다시 확인해주세요.',
            extractedData: extractedData || undefined,
            step: 'extraction',
          }),
          { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        );
      }

      // 회사명 정규화
      const companyName = sanitizeFileName(extractedData.business_name);
      if (!companyName || companyName === 'unknown') {
        return new Response(
          JSON.stringify({
            success: false,
            error: '유효한 회사명을 추출할 수 없습니다.',
            extractedData,
            step: 'extraction',
          }),
          { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        );
      }

      // 2단계: 사업자등록번호 검증
      validationResult = await validateBusinessNumber(extractedData.business_number, env);
      if (!validationResult.isValid) {
        return new Response(
          JSON.stringify({
            success: false,
            extractedData,
            validationResult,
            error: validationResult.errorMessage || '유효하지 않은 사업자등록번호입니다.',
            step: 'validation',
          }),
          { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        );
      }

      // 3단계: Presigned URL 생성 (모든 검증 통과 후에만 생성)
      const contentType = fileName.toLowerCase().endsWith('.pdf') ? 'application/pdf' : 'image/png';
      const filePath = generateFilePath(userId, fileName, companyName);
      const presignedUrl = await createPresignedUrlSignature(
        'PUT',
        filePath,
        contentType,
        900, // 15분 유효
        env
      );

      // DB 저장은 Flutter에서 처리하도록 변경
      // Workers는 검증과 Presigned URL 생성만 수행
      return new Response(
        JSON.stringify({
          success: true,
          extractedData,
          validationResult,
          presignedUrl,
          filePath,
          publicUrl: `${env.R2_PUBLIC_URL}/${filePath}`,
          // DB 저장은 Flutter에서 처리
        }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    } catch (error) {
      // Presigned URL 생성 후 에러 발생 시 별도 롤백 불필요
      // (파일이 아직 업로드되지 않았으므로)
      return new Response(
        JSON.stringify({
          success: false,
          extractedData: extractedData || undefined,
          validationResult: validationResult || undefined,
          error: error instanceof Error ? error.message : String(error),
          step: validationResult ? 'presigned_url' : extractedData ? 'validation' : 'extraction',
          debugInfo: {
            errorType: error instanceof Error ? error.constructor.name : typeof error,
            errorStack: error instanceof Error ? error.stack : undefined,
            timestamp: new Date().toISOString(),
          },
        }),
        { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }
  } catch (error) {
    console.error('❌ handleVerifyAndRegister 전체 오류:', error);
    return new Response(
      JSON.stringify({
        success: false,
        error: error instanceof Error ? error.message : 'Unknown error',
        debugInfo: {
          errorType: error instanceof Error ? error.constructor.name : typeof error,
          errorStack: error instanceof Error ? error.stack : undefined,
          timestamp: new Date().toISOString(),
        },
      }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }
}

// 헬퍼 함수들
async function callGeminiAPI(apiKey: string, model: string, image: string, prompt: string): Promise<Response> {
  if (!apiKey || apiKey.trim() === '') {
    throw new Error('GEMINI_API_KEY가 설정되지 않았습니다.');
  }

  console.log(`🔑 Gemini API 호출: 모델=${model}, API 키 길이=${apiKey.length}, 시작=${apiKey.substring(0, 10)}...`);
  
  const url = `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${apiKey}`;
  
  return await fetch(url, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      contents: [{
        parts: [
          { text: prompt },
          { inline_data: { mime_type: 'image/png', data: image } }
        ]
      }],
      generationConfig: { temperature: 0.1, maxOutputTokens: 1000 },
    }),
  });
}

async function verifyBusinessRegistrationImage(image: string, env: Env): Promise<boolean> {
  // API 키 검증
  if (!env.GEMINI_API_KEY || env.GEMINI_API_KEY.trim() === '') {
    console.error('❌ GEMINI_API_KEY가 설정되지 않았습니다.');
    return true; // 엄격하지 않게 처리
  }

  const verificationPrompt = `이 이미지가 한국의 사업자등록증인지 확인해주세요.

다음과 같은 요소가 있는지 확인하세요:
- "사업자등록증" 또는 "사업자등록증명원" 텍스트
- 사업자등록번호 (000-00-00000 형식 또는 10자리 숫자)
- 상호명, 대표자명, 사업장소재지 등의 정보
- 정부 기관 인증 마크나 도장
- 국세청 또는 세무서 관련 표시

다음과 같은 경우에도 사업자등록증으로 인정합니다:
- 스캔본, 사진, PDF 등 다양한 형식
- 일부가 가려지거나 흐릿한 경우
- 사업자등록증명원(인쇄본)도 포함
- 오래된 형식의 사업자등록증도 포함

응답은 다음 형식의 JSON만 반환해주세요:
{
  "is_business_registration": true 또는 false,
  "confidence": "high" 또는 "medium" 또는 "low",
  "reason": "확인 이유"
}

사업자등록증이 확실한 경우 "is_business_registration": true로 설정하고, 
의심스러운 경우에도 가능성이 있으면 true로 설정해주세요. 
명확히 다른 문서(신분증, 계약서 등)인 경우에만 false로 설정해주세요.`;

  // 여러 모델 시도 (fallback)
  const models = ['gemini-2.5-flash-lite', 'gemini-2.5-flash'];
  
  try {
    let extractedText: string | null = null;
    let lastError: Error | null = null;
    
    for (let i = 0; i < models.length; i++) {
      const model = models[i];
      try {
        console.log(`🔄 ${model} 모델로 이미지 검증 시도 중...`);
        const geminiResponse = await callGeminiAPI(env.GEMINI_API_KEY, model, image, verificationPrompt);
        
        if (!geminiResponse.ok) {
          const errorText = await geminiResponse.text();
          console.error(`❌ ${model} API 호출 실패 (${geminiResponse.status}):`, errorText);
          lastError = new Error(`${model} API 호출 실패: ${geminiResponse.status}`);
          if (i === models.length - 1) {
            // 모든 모델 실패 시에도 true 반환 (엄격하지 않게)
            console.warn('⚠️ 모든 모델 실패, 허용으로 처리');
            return true;
          }
          continue;
        }
        
        const geminiData = await geminiResponse.json();
        extractedText = geminiData.candidates?.[0]?.content?.parts?.[0]?.text;
        
        if (!extractedText) {
          console.warn(`⚠️ ${model} 응답 텍스트 없음`);
          if (i === models.length - 1) {
            // 모든 모델 실패 시에도 true 반환 (엄격하지 않게)
            console.warn('⚠️ 모든 모델에서 응답 텍스트 없음, 허용으로 처리');
            return true;
          }
          continue;
        }
        
        console.log(`✅ ${model} 모델로 검증 성공`);
        break; // 성공하면 루프 종료
      } catch (error) {
        lastError = error instanceof Error ? error : new Error(String(error));
        console.error(`❌ ${model} 모델 처리 중 오류:`, lastError.message);
        if (i === models.length - 1) {
          // 모든 모델 실패 시에도 true 반환 (엄격하지 않게)
          console.warn('⚠️ 모든 모델 실패, 허용으로 처리');
          return true;
        }
        continue;
      }
    }
    
    if (!extractedText) {
      // 모든 모델 실패 시에도 true 반환 (엄격하지 않게)
      console.warn('⚠️ 응답 텍스트 없음, 허용으로 처리');
      return true;
    }

    try {
      const jsonMatch = extractedText.match(/```json\s*([\s\S]*?)\s*```/) || 
                       extractedText.match(/```\s*([\s\S]*?)\s*```/) ||
                       [null, extractedText];
      const result = JSON.parse(jsonMatch[1] || extractedText);
      const isBusinessRegistration = result.is_business_registration === true;
      const confidence = result.confidence || 'low';
      
      console.log('📋 이미지 검증 결과:', {
        isBusinessRegistration,
        confidence,
        reason: result.reason
      });

      // confidence가 low인 경우도 허용 (엄격하지 않게)
      if (isBusinessRegistration) {
        return true;
      }

      // false인 경우에도 키워드 확인으로 재검증
      if (extractedText.toLowerCase().includes('사업자등록증') || 
          extractedText.toLowerCase().includes('business registration') ||
          extractedText.toLowerCase().includes('사업자등록번호')) {
        console.log('✅ 키워드 확인으로 사업자등록증으로 인정');
        return true;
      }

      return false;
    } catch (parseError) {
      console.error('❌ JSON 파싱 실패, 텍스트 확인:', parseError);
      // 파싱 실패 시 텍스트에서 키워드 확인 (더 관대하게)
      const lowerText = extractedText.toLowerCase();
      if (lowerText.includes('사업자등록증') || 
          lowerText.includes('business registration') ||
          lowerText.includes('사업자등록번호') ||
          lowerText.includes('사업자') ||
          lowerText.includes('등록번호')) {
        console.log('✅ 키워드 확인으로 사업자등록증으로 인정');
        return true;
      }
      // 파싱 실패 시에도 엄격하지 않게 true 반환
      console.warn('⚠️ 파싱 실패, 허용으로 처리');
      return true;
    }
  } catch (error) {
    console.error('❌ 이미지 검증 중 오류:', error);
    // 에러 발생 시에도 엄격하지 않게 true 반환
    console.warn('⚠️ 에러 발생, 허용으로 처리');
    return true;
  }
}

async function extractBusinessInfo(image: string, env: Env): Promise<any> {
  const extractionPrompt = `이 한국 사업자등록증 이미지를 분석하여 다음 정보를 JSON 형태로 추출해주세요: business_name, business_number, representative_name, business_address, business_type, business_item`;

  // API 키 검증
  if (!env.GEMINI_API_KEY || env.GEMINI_API_KEY.trim() === '') {
    throw new Error('GEMINI_API_KEY 환경 변수가 설정되지 않았습니다. Workers secrets에 GEMINI_API_KEY를 설정해주세요.');
  }

  const models = ['gemini-2.5-flash-lite', 'gemini-2.5-flash'];
  const errors: string[] = [];
  
  for (let i = 0; i < models.length; i++) {
    const model = models[i];
    try {
      console.log(`🔄 ${model} 모델로 AI 추출 시도 중...`);
      const geminiResponse = await callGeminiAPI(env.GEMINI_API_KEY, model, image, extractionPrompt);
      
      if (!geminiResponse.ok) {
        const errorText = await geminiResponse.text();
        let errorMsg = `${model} API 호출 실패 (${geminiResponse.status}): ${errorText}`;
        
        // 403 에러인 경우 특별 처리
        if (geminiResponse.status === 403) {
          const errorJson = JSON.parse(errorText);
          if (errorJson.error?.message?.includes('unregistered callers')) {
            errorMsg = `${model} API 키 인증 실패 (403): API 키가 유효하지 않거나 설정되지 않았습니다. Workers secrets에서 GEMINI_API_KEY를 확인해주세요.`;
          }
        }
        
        console.error(`❌ ${errorMsg}`);
        errors.push(errorMsg);
        if (i === models.length - 1) {
          throw new Error(`모든 모델 실패. 마지막 에러: ${errorMsg}`);
        }
        continue;
      }

      const geminiData = await geminiResponse.json();
      const extractedText = geminiData.candidates?.[0]?.content?.parts?.[0]?.text;
      
      if (!extractedText) {
        const errorMsg = `${model}: 응답 텍스트 없음`;
        console.error(`❌ ${errorMsg}`);
        errors.push(errorMsg);
        if (i === models.length - 1) {
          throw new Error(`모든 모델 실패. 마지막 에러: ${errorMsg}`);
        }
        continue;
      }

      console.log(`✅ ${model} 응답 텍스트 길이: ${extractedText.length}자`);

      try {
        const jsonMatch = extractedText.match(/```json\s*([\s\S]*?)\s*```/) || 
                         extractedText.match(/```\s*([\s\S]*?)\s*```/) ||
                         [null, extractedText];
        const jsonText = jsonMatch[1] || extractedText;
        const result = JSON.parse(jsonText);
        
        console.log(`✅ ${model} 추출 성공:`, result);
        
        // 사업자등록번호가 있는지 확인
        if (!result.business_number) {
          console.warn(`⚠️ ${model}: 사업자등록번호가 추출되지 않음. 추출된 데이터:`, result);
        }
        
        return result;
      } catch (parseError) {
        const errorMsg = `${model} JSON 파싱 실패: ${parseError instanceof Error ? parseError.message : String(parseError)}. 응답 텍스트: ${extractedText.substring(0, 200)}...`;
        console.error(`❌ ${errorMsg}`);
        errors.push(errorMsg);
        
        // 파싱 실패 시 텍스트에서 정보 추출 시도
        try {
          const patterns = {
            business_name: /상호[:\s]*([^\n\r]+)/i,
            business_number: /등록번호[:\s]*([0-9-]+)/i,
            representative_name: /성명[:\s]*([^\n\r]+)/i,
            business_address: /사업장소재지[:\s]*([^\n\r]+)/i,
            business_type: /업태[:\s]*([^\n\r]+)/i,
            business_item: /종목[:\s]*([^\n\r]+)/i,
          };
          
          const fallbackData: Record<string, string> = {};
          for (const [key, pattern] of Object.entries(patterns)) {
            const match = extractedText.match(pattern);
            if (match && match[1]) {
              fallbackData[key] = match[1].trim();
            }
          }
          
          if (fallbackData.business_number) {
            console.log(`✅ ${model} 텍스트 패턴으로 추출 성공:`, fallbackData);
            return fallbackData;
          }
        } catch (fallbackError) {
          console.error(`❌ ${model} 텍스트 패턴 추출도 실패:`, fallbackError);
        }
        
        if (i === models.length - 1) {
          throw new Error(`모든 모델 실패. JSON 파싱 실패. 에러들: ${errors.join('; ')}`);
        }
        continue;
      }
    } catch (error) {
      const errorMsg = `${model} 모델 처리 중 예외 발생: ${error instanceof Error ? error.message : String(error)}`;
      console.error(`❌ ${errorMsg}`);
      errors.push(errorMsg);
      
      if (i === models.length - 1) {
        throw new Error(`AI 추출 실패. 모든 모델 시도 실패. 에러들: ${errors.join('; ')}`);
      }
      continue;
    }
  }
  
  throw new Error(`AI 추출 실패. 알 수 없는 오류. 에러들: ${errors.join('; ')}`);
}

function validateChecksum(businessNumber: string): boolean {
  const cleanNumber = businessNumber.replaceAll('-', '');
  if (cleanNumber.length !== 10) return false;

  const weights = [1, 3, 7, 1, 3, 7, 1, 3, 5];
  let sum = 0;
  for (let i = 0; i < 9; i++) {
    sum += parseInt(cleanNumber[i]) * weights[i];
  }
  sum += Math.floor((parseInt(cleanNumber[8]) * 5) / 10);
  const remainder = sum % 10;
  const checkDigit = remainder === 0 ? 0 : 10 - remainder;
  return checkDigit === parseInt(cleanNumber[9]);
}

async function validateBusinessNumber(businessNumber: string, env: Env): Promise<any> {
  const cleanNumber = businessNumber.replaceAll('-', '');
  if (!/^\d{10}$/.test(cleanNumber) || !validateChecksum(cleanNumber)) {
    return { isValid: false, errorMessage: '사업자등록번호 형식이 올바르지 않습니다.' };
  }

  const response = await fetch(
    `https://api.odcloud.kr/api/nts-businessman/v1/status?serviceKey=${env.NTS_API_KEY}`,
    {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'Accept': 'application/json' },
      body: JSON.stringify({ b_no: [cleanNumber] }),
    }
  );

  if (!response.ok) {
    const errorText = await response.text();
    console.error('❌ 국세청 API 에러 응답:', {
      status: response.status,
      statusText: response.statusText,
      body: errorText,
      businessNumber: cleanNumber,
    });
    throw new Error(`국세청 API 호출 실패: ${response.status} - ${errorText}`);
  }

  const jsonData = await response.json();
  const statusCode = jsonData.status_code || '';
  const data = jsonData.data || [];

  if (statusCode === 'OK' && data.length > 0) {
    const businessInfo = data[0];
    return {
      isValid: businessInfo.b_stt_cd === '01',
      businessStatus: businessInfo.b_stt || '',
      businessStatusCode: businessInfo.b_stt_cd,
      taxType: businessInfo.tax_type || '',
    };
  }

  return { isValid: false, errorMessage: '사업자 정보를 찾을 수 없습니다.' };
}

// UTC 시간을 한국 시간(KST, UTC+9)으로 변환
function toKST(date: Date): Date {
  const kstOffset = 9 * 60 * 60 * 1000; // 9시간을 밀리초로 변환
  return new Date(date.getTime() + kstOffset);
}

function formatTimestamp(date: Date): string {
  const kstDate = toKST(date);
  const year = kstDate.getUTCFullYear();
  const month = String(kstDate.getUTCMonth() + 1).padStart(2, '0');
  const day = String(kstDate.getUTCDate()).padStart(2, '0');
  const hours = String(kstDate.getUTCHours()).padStart(2, '0');
  const minutes = String(kstDate.getUTCMinutes()).padStart(2, '0');
  const seconds = String(kstDate.getUTCSeconds()).padStart(2, '0');
  return `${year}${month}${day}${hours}${minutes}${seconds}`;
}

// 밀리초까지 포함한 타임스탬프 (중복 파일명 방지용)
function formatTimestampWithMillis(date: Date): string {
  const kstDate = toKST(date);
  const year = kstDate.getUTCFullYear();
  const month = String(kstDate.getUTCMonth() + 1).padStart(2, '0');
  const day = String(kstDate.getUTCDate()).padStart(2, '0');
  const hours = String(kstDate.getUTCHours()).padStart(2, '0');
  const minutes = String(kstDate.getUTCMinutes()).padStart(2, '0');
  const seconds = String(kstDate.getUTCSeconds()).padStart(2, '0');
  const millis = String(kstDate.getUTCMilliseconds()).padStart(3, '0');
  return `${year}${month}${day}${hours}${minutes}${seconds}${millis}`;
}

// 파일명 정규화 함수 (기본적인 특수 문자 처리)
function sanitizeFileName(name: string): string {
  if (!name || name.trim().length === 0) {
    return 'unknown';
  }

  return name
    // 파일 시스템 예약 문자만 제거 (슬래시는 경로 구분자이므로 제거)
    .replace(/[<>:"/\\|?*]/g, '_')
    // 공백을 언더스코어로 변환
    .replace(/\s+/g, '_')
    // 연속된 언더스코어를 하나로
    .replace(/_{2,}/g, '_')
    // 앞뒤 언더스코어 제거
    .replace(/^_+|_+$/g, '')
    .trim() || 'unknown';
}

function generateFilePath(userId: string, fileName: string, companyName?: string): string {
  const now = new Date();
  const timestamp = formatTimestampWithMillis(now);
  const extension = fileName.substring(fileName.lastIndexOf('.'));
  // UUID 생성 (한글/특수문자 문제 해결을 위해 UUID 사용)
  const fileUuid = crypto.randomUUID();
  
  // 사업자등록증: business-registration/{timestamp}_{uuid}.png
  return `business-registration/${timestamp}_${fileUuid}${extension}`;
}

async function uploadBusinessRegistrationFile(
  fileBytes: Uint8Array,
  filePath: string,
  contentType: string,
  userId: string,
  env: Env
): Promise<string> {
  await env.FILES.put(filePath, fileBytes, {
    httpMetadata: { contentType },
    customMetadata: { userId, fileType: 'business_registration', uploadedAt: new Date().toISOString() },
  });
  return `${env.R2_PUBLIC_URL}/${filePath}`;
}

// DB 저장은 Flutter에서 처리하므로 제거됨

// 파일 삭제 API (DB 저장 실패 시 롤백용)
interface DeleteFileRequest {
  fileUrl: string;
}

async function handleDeleteFile(request: Request, env: Env): Promise<Response> {
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

    console.log('🗑️ 파일 삭제 시도:', { originalUrl: fileUrl, extractedPath: filePath });

    // R2에서 파일 삭제
    try {
      await env.FILES.delete(filePath);
      console.log('✅ 파일 삭제 성공:', filePath);
      return new Response(
        JSON.stringify({ success: true, message: '파일이 삭제되었습니다.' }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    } catch (deleteError) {
      console.error('❌ R2 파일 삭제 실패:', deleteError);
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

// ============================================
// 캠페인 이미지 분석
// ============================================

async function handleAnalyzeCampaignImage(request: Request, env: Env): Promise<Response> {
  try {
    // multipart/form-data 파싱
    const formData = await request.formData();
    const imageFile = formData.get('image') as File | null;
    const imageWidthStr = formData.get('imageWidth') as string | null;
    const imageHeightStr = formData.get('imageHeight') as string | null;
    
    if (!imageFile) {
      return new Response(
        JSON.stringify({
          success: false,
          error: '이미지가 제공되지 않았습니다.'
        }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }
    
    // Gemini API 초기화
    const apiKey = env.GEMINI_API_KEY;
    if (!apiKey || apiKey.trim() === '') {
      throw new Error('GEMINI_API_KEY가 설정되지 않았습니다.');
    }
    
    // 여러 모델 시도 (fallback)
    const models = ['gemini-2.5-flash-lite', 'gemini-2.5-flash'];
    
    // 실제 이미지 크기 사용 (Flutter에서 전달받은 값)
    let actualWidth: number;
    let actualHeight: number;
    
    if (imageWidthStr && imageHeightStr) {
      const width = parseInt(imageWidthStr, 10);
      const height = parseInt(imageHeightStr, 10);
      
      if (!isNaN(width) && !isNaN(height) && width > 0 && height > 0) {
        actualWidth = Math.floor(width);
        actualHeight = Math.floor(height);
        console.log(`📏 Flutter에서 전달받은 실제 이미지 크기: ${actualWidth}x${actualHeight}`);
      } else {
        console.warn('⚠️ 이미지 크기 정보가 유효하지 않음. 기본값 사용 (1080x1920)');
        actualWidth = 1080;
        actualHeight = 1920;
      }
    } else {
      console.warn('⚠️ 이미지 크기 정보가 전달되지 않음. 기본값 사용 (1080x1920)');
      actualWidth = 1080;
      actualHeight = 1920;
    }
    
    console.log(`📏 사용할 이미지 크기: ${actualWidth}x${actualHeight}`);
    
    // 이미지를 base64로 변환
    const imageArrayBuffer = await imageFile.arrayBuffer();
    const imageBytes = new Uint8Array(imageArrayBuffer);
    
    // 효율적인 base64 인코딩
    let binaryString = '';
    const chunkSize = 8192;
    for (let i = 0; i < imageBytes.length; i += chunkSize) {
      const chunk = imageBytes.subarray(i, i + chunkSize);
      binaryString += String.fromCharCode(...chunk);
    }
    const imageBase64 = btoa(binaryString);
    
    // MIME 타입 감지
    let mimeType = imageFile.type || "image/png";
    if (mimeType === "application/octet-stream" || !mimeType.startsWith("image/")) {
      if (imageBytes.length >= 4) {
        if (imageBytes[0] === 0xFF && imageBytes[1] === 0xD8 && imageBytes[2] === 0xFF) {
          mimeType = "image/jpeg";
        } else if (imageBytes[0] === 0x89 && 
                   imageBytes[1] === 0x50 && 
                   imageBytes[2] === 0x4E && 
                   imageBytes[3] === 0x47) {
          mimeType = "image/png";
        } else {
          mimeType = "image/png";
        }
      } else {
        mimeType = "image/png";
      }
    }
    
    console.log(`📸 감지된 이미지 타입: ${mimeType}`);
    
    // 🔥 JSON 스키마를 사용한 강제 출력 형식
    const responseSchema = {
      type: "object",
      properties: {
        keyword: { type: "string", description: "제품 카테고리" },
        title: { type: "string", description: "제품명" },
        option: { type: "string", description: "옵션 (예: 색상, 사이즈)" },
        quantity: { type: "integer", description: "수량" },
        seller: { type: "string", description: "판매자" },
        productNumber: { type: "string", description: "상품번호" },
        paymentAmount: { type: "integer", description: "결제 금액" },
        productImageCrop: {
          type: "object",
          description: "제품 이미지의 크롭 영역 (시작점과 종료점, 0.0-1.0 비율)",
          properties: {
            startX: { type: "number", description: "제품이 시작하는 X 위치 (0.0-1.0)", minimum: 0.0, maximum: 1.0 },
            startY: { type: "number", description: "제품이 시작하는 Y 위치 (0.0-1.0)", minimum: 0.0, maximum: 1.0 },
            endX: { type: "number", description: "제품이 끝나는 X 위치 (0.0-1.0)", minimum: 0.0, maximum: 1.0 },
            endY: { type: "number", description: "제품이 끝나는 Y 위치 (0.0-1.0)", minimum: 0.0, maximum: 1.0 }
          },
          required: ["startX", "startY", "endX", "endY"]
        }
      },
      required: ["keyword", "title", "quantity", "paymentAmount", "productImageCrop"]
    };

    // 간소화된 프롬프트
    const prompt = `
이미지에서 다음 정보를 추출하세요:

1. **제품 정보**
   - keyword: 제품 카테고리 (예: "욕실 선반", "키보드", "마우스")
   - title: 제품 전체 이름
   - option: 옵션 (색상, 사이즈 등)
   - quantity: 수량 (숫자만)
   - seller: 판매자명
   - productNumber: 상품번호
   - paymentAmount: 결제 금액 (숫자만, 쉼표 제거)

2. **제품 이미지 크롭 영역**
   - 제품의 메인 사진이 있는 영역을 찾으세요
   - 배경/텍스트는 제외하고 **제품 물체만** 포함하도록 지정하세요
   - **비율(0.0-1.0)로 시작점과 종료점을 반환**하세요:
     * startX: 제품이 시작하는 X 위치 (왼쪽에서, 0.0-1.0)
     * startY: 제품이 시작하는 Y 위치 (위에서, 0.0-1.0)
     * endX: 제품이 끝나는 X 위치 (왼쪽에서, 0.0-1.0)
     * endY: 제품이 끝나는 Y 위치 (위에서, 0.0-1.0)

**예시:**
- 제품이 왼쪽에서 15%, 위에서 10% 지점에서 시작
- 제품이 왼쪽에서 50%, 위에서 80% 지점에서 끝남
→ startX: 0.15, startY: 0.10, endX: 0.50, endY: 0.80

정의된 JSON 스키마 형식으로만 응답하세요.
`;

    // 이미지 데이터 준비
    const imageData = imageBase64;
    
    // 여러 모델 시도
    let lastError: Error | null = null;
    let geminiData: any = null;
    let text: string | null = null;
    let usedModel: string | null = null;
    
    for (let i = 0; i < models.length; i++) {
      const model = models[i];
      try {
        console.log(`🔄 ${model} 모델로 캠페인 이미지 분석 시도 중...`);
        
        // Gemini API 호출
        const geminiUrl = `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${apiKey}`;
        const geminiResponse = await fetch(geminiUrl, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            contents: [{
              parts: [
                { text: prompt },
                { inline_data: { mime_type: mimeType, data: imageData } }
              ]
            }],
            generationConfig: {
              temperature: 0.1,
              maxOutputTokens: 2000,
              responseMimeType: "application/json", // JSON 응답 강제
              responseSchema: responseSchema // 🔥 스키마 강제
            }
          })
        });
        
        if (!geminiResponse.ok) {
          const errorText = await geminiResponse.text();
          console.error(`❌ ${model} API 호출 실패 (${geminiResponse.status}):`, errorText);
          
          let errorMessage = errorText;
          try {
            if (errorText.trim().startsWith('{')) {
              const errorJson = JSON.parse(errorText);
              errorMessage = errorJson.error?.message || errorJson.error || errorText;
            }
          } catch (e) {
            // JSON 파싱 실패 시 원본 사용
          }
          
          lastError = new Error(`${model} API 호출 실패: ${geminiResponse.status} - ${errorMessage}`);
          if (i === models.length - 1) {
            throw lastError;
          }
          continue;
        }
        
        try {
          geminiData = await geminiResponse.json();
        } catch (jsonError) {
          const responseText = await geminiResponse.text();
          console.error(`❌ ${model} JSON 파싱 실패:`, jsonError);
          console.error('응답 텍스트:', responseText.substring(0, 200));
          lastError = new Error(`${model} 응답 JSON 파싱 실패`);
          if (i === models.length - 1) {
            throw lastError;
          }
          continue;
        }
        
        text = geminiData.candidates?.[0]?.content?.parts?.[0]?.text;
        
        if (!text) {
          console.error(`❌ ${model} 응답 텍스트 없음`);
          lastError = new Error(`${model} 응답 텍스트가 없습니다.`);
          if (i === models.length - 1) {
            throw lastError;
          }
          continue;
        }
        
        usedModel = model;
        console.log(`✅ ${model} 모델로 분석 성공`);
        break;
      } catch (error) {
        lastError = error instanceof Error ? error : new Error(String(error));
        console.error(`❌ ${model} 모델 처리 중 오류:`, lastError.message);
        if (i === models.length - 1) {
          throw new Error(`모든 모델 실패. 마지막 에러: ${lastError.message}`);
        }
        continue;
      }
    }
    
    if (!text) {
      throw new Error('모든 모델에서 응답을 받지 못했습니다.');
    }
    
    console.log('✅ Gemini 응답:', text.substring(0, 500));
    
    // JSON 파싱
    let jsonText = text.trim();
    if (jsonText.startsWith('```')) {
      jsonText = jsonText.replace(/```json\n?/g, '').replace(/```\n?/g, '');
    }
    
    const jsonMatch = jsonText.match(/\{[\s\S]*\}/);
    if (!jsonMatch || !jsonMatch[0]) {
      console.error('❌ JSON을 찾을 수 없음:', text);
      throw new Error('응답에서 JSON을 찾을 수 없습니다.');
    }
    
    let extractedData: any;
    try {
      extractedData = JSON.parse(jsonMatch[0]);
    } catch (parseError) {
      console.error('❌ JSON 파싱 실패:', parseError);
      console.error('파싱 시도한 텍스트:', jsonMatch[0].substring(0, 200));
      throw new Error(`JSON 파싱 실패: ${parseError instanceof Error ? parseError.message : String(parseError)}`);
    }
    
    console.log('📦 파싱된 데이터:', JSON.stringify(extractedData, null, 2));
    
    // AI 원본 응답의 productImageCrop 형식 확인
    if (extractedData.productImageCrop) {
      console.log('🔍 AI 원본 productImageCrop 형식:', JSON.stringify(extractedData.productImageCrop));
      const cropKeys = Object.keys(extractedData.productImageCrop);
      console.log('🔑 productImageCrop 키 목록:', cropKeys.join(', '));
    }
    
    // 데이터 타입 검증 및 변환
    if (extractedData.quantity && typeof extractedData.quantity === 'string') {
      extractedData.quantity = parseInt(extractedData.quantity);
    }
    if (extractedData.paymentAmount && typeof extractedData.paymentAmount === 'string') {
      extractedData.paymentAmount = parseInt(extractedData.paymentAmount.replace(/[^0-9]/g, ''));
    }
    
    // 🔥 productImageCrop 처리: 비율 → 픽셀 변환
    let cropData: any = null;
    
    if (extractedData.productImageCrop && 
        typeof extractedData.productImageCrop === 'object') {
      
      const crop = extractedData.productImageCrop;
      
      console.log('🔍 크롭 데이터 형식 감지 중...', {
        hasStartX: crop.startX !== undefined,
        hasStartY: crop.startY !== undefined,
        hasEndX: crop.endX !== undefined,
        hasEndY: crop.endY !== undefined,
      });
      
      // startX, startY, endX, endY가 있는지 확인
      if (crop.startX !== undefined && crop.startY !== undefined &&
          crop.endX !== undefined && crop.endY !== undefined) {
        
        // 비율 값 파싱
        let startX = typeof crop.startX === 'number' ? crop.startX : parseFloat(crop.startX) || 0;
        let startY = typeof crop.startY === 'number' ? crop.startY : parseFloat(crop.startY) || 0;
        let endX = typeof crop.endX === 'number' ? crop.endX : parseFloat(crop.endX) || 0.5;
        let endY = typeof crop.endY === 'number' ? crop.endY : parseFloat(crop.endY) || 0.5;
        
        // 0.0-1.0 범위로 제한
        startX = Math.max(0, Math.min(1, startX));
        startY = Math.max(0, Math.min(1, startY));
        endX = Math.max(0, Math.min(1, endX));
        endY = Math.max(0, Math.min(1, endY));
        
        // 간단한 검증: 시작점 < 종료점
        if (startX >= endX) {
          endX = Math.min(1, startX + 0.3);
        }
        if (startY >= endY) {
          endY = Math.min(1, startY + 0.3);
        }
        
        // 최소 크기 보장
        if (endX - startX < 0.1) {
          endX = Math.min(1, startX + 0.1);
        }
        if (endY - startY < 0.1) {
          endY = Math.min(1, startY + 0.1);
        }
        
        console.log(`📐 비율 좌표: startX=${startX}, startY=${startY}, endX=${endX}, endY=${endY}`);
        
        // 픽셀 좌표로 변환
        const pixelStartX = Math.floor(startX * actualWidth);
        const pixelStartY = Math.floor(startY * actualHeight);
        const pixelEndX = Math.floor(endX * actualWidth);
        const pixelEndY = Math.floor(endY * actualHeight);
        
        // Width/Height 계산
        const pixelW = pixelEndX - pixelStartX;
        const pixelH = pixelEndY - pixelStartY;
        
        console.log(`📐 픽셀 좌표: x=${pixelStartX}, y=${pixelStartY}, width=${pixelW}, height=${pixelH}`);
        
        // 최종 검증
        if (pixelW > 0 && pixelH > 0 && 
            pixelStartX >= 0 && pixelStartY >= 0 &&
            pixelEndX <= actualWidth &&
            pixelEndY <= actualHeight) {
          cropData = {
            x: pixelStartX,
            y: pixelStartY,
            width: pixelW,
            height: pixelH
          };
          console.log('✅ 크롭 좌표 변환 성공:', cropData);
        } else {
          console.warn('⚠️ 크롭 좌표가 유효하지 않음. 기본값 사용');
        }
      } else {
        console.warn('⚠️ startX/startY/endX/endY 형식이 아님. 기본값 사용');
      }
    }
    
    // 크롭 데이터가 없으면 기본값 사용
    if (!cropData) {
      console.log('⚠️ 유효한 크롭 데이터 없음. 기본값 사용 (왼쪽 절반)');
      cropData = {
        x: 0,
        y: 0,
        width: Math.floor(actualWidth * 0.5), // 왼쪽 절반
        height: Math.floor(actualHeight * 0.5) // 상단 절반
      };
      console.log('📐 기본 크롭 좌표:', cropData);
    }
    
    // 최종 데이터 구성
    extractedData.productImageCrop = cropData;
    
    console.log('📤 최종 응답 데이터:', JSON.stringify(extractedData, null, 2));
    
    return new Response(
      JSON.stringify({
        success: true,
        data: extractedData,
        model: usedModel || 'unknown'
      }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
    
  } catch (error: any) {
    console.error('❌ 이미지 분석 실패:', error);
    return new Response(
      JSON.stringify({
        success: false,
        error: error.message || '이미지 분석 중 오류가 발생했습니다.'
      }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }
}
