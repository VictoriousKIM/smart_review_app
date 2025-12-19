import { createPresignedUrlSignature } from '../utils/r2-helpers';
import { generateFilePath, sanitizeFileName } from '../utils/date-helpers';
import { verifyBusinessRegistrationImage, extractBusinessInfo, validateBusinessNumber } from '../utils/business-helpers';
import { Env } from '../index';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type, Authorization',
};

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

export async function handleVerifyAndRegister(request: Request, env: Env): Promise<Response> {
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

