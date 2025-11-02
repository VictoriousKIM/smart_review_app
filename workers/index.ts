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
    const { fileName, userId, contentType, fileType, method = 'PUT' } = await request.json();

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
    const date = new Date();
    const year = date.getFullYear();
    const month = String(date.getMonth() + 1).padStart(2, '0');
    const day = String(date.getDate()).padStart(2, '0');
    const timestamp = Date.now();

    const filePath = `${fileType}/${year}/${month}/${day}/${userId}_${timestamp}_${fileName}`;

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
  
  const url = `https://${env.R2_ACCOUNT_ID}.r2.cloudflarestorage.com/${env.R2_BUCKET_NAME}/${filePath}`;
  const urlObj = new URL(url);
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
  
  // Canonical Request
  const canonicalHeaders = `host:${urlObj.host}\n`;
  const signedHeaders = 'host';
  const canonicalRequest = [
    method,
    urlObj.pathname,
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
  
  // Presigned URL 생성
  queryParams.set('X-Amz-Signature', signature);
  return `${url}?${queryParams.toString()}`;
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
    const date = new Date();
    const year = date.getFullYear();
    const month = String(date.getMonth() + 1).padStart(2, '0');
    const day = String(date.getDate()).padStart(2, '0');
    const timestamp = Date.now();

    const key = `${fileType}/${year}/${month}/${day}/${userId}_${timestamp}_${file.name}`;

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
        throw new Error(`AI 추출 실패: ${errorMessage}`);
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

      // 3단계: Presigned URL 생성 (Flutter에서 직접 업로드)
      const contentType = fileName.toLowerCase().endsWith('.pdf') ? 'application/pdf' : 'image/png';
      const filePath = generateFilePath(userId, fileName);
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

  try {
    const geminiResponse = await callGeminiAPI(env.GEMINI_API_KEY, 'gemini-2.5-flash', image, verificationPrompt);
    if (!geminiResponse.ok) {
      console.error('❌ Gemini API 호출 실패:', geminiResponse.status);
      // API 호출 실패 시에도 true 반환 (엄격하지 않게)
      return true;
    }

    const geminiData = await geminiResponse.json();
    const extractedText = geminiData.candidates?.[0]?.content?.parts?.[0]?.text;
    if (!extractedText) {
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

function generateFilePath(userId: string, fileName: string): string {
  const now = new Date();
  const year = now.getFullYear();
  const month = String(now.getMonth() + 1).padStart(2, '0');
  const day = String(now.getDate()).padStart(2, '0');
  const timestamp = now.getTime();
  const extension = fileName.substring(fileName.lastIndexOf('.'));
  return `business-registration/${year}/${month}/${day}/${userId}_${timestamp}${extension}`;
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

    // R2 Public URL에서 파일 경로 추출
    // 예: https://7b72031b240604b8e9f88904de2f127c.r2.cloudflarestorage.com/business-registration/2025/11/02/userId_timestamp.png
    const urlObj = new URL(fileUrl);
    const filePath = urlObj.pathname.substring(1); // 첫 번째 '/' 제거

    if (!filePath.startsWith('business-registration/')) {
      return new Response(
        JSON.stringify({ success: false, error: '유효하지 않은 파일 경로입니다.' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // R2에서 파일 삭제
    await env.FILES.delete(filePath);

    return new Response(
      JSON.stringify({ success: true, message: '파일이 삭제되었습니다.' }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
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

