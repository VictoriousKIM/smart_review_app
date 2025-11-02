// Supabase Edge Function: 사업자등록증 검증 및 등록 통합 처리
// AI 추출 + 사업자등록번호 검증 + 파일 업로드 + DB 저장을 한 번에 처리
import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

declare const Deno: {
  env: {
    get(key: string): string | undefined;
  };
};

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Max-Age': '86400',
}

interface VerifyAndRegisterRequest {
  image: string  // base64 인코딩된 이미지
  fileName: string
}

interface VerifyAndRegisterResponse {
  success: boolean
  extractedData?: {
    business_name: string
    business_number: string
    representative_name: string
    business_address: string
    business_type: string
    business_item?: string
  }
  validationResult?: {
    isValid: boolean
    businessStatus?: string
    businessStatusCode?: string
    taxType?: string
  }
  companyId?: string
  fileUrl?: string
  error?: string
  step?: string  // 에러 발생 단계
}

// R2 설정 (Workers API 사용)
const WORKERS_API_URL = Deno.env.get('WORKERS_API_URL') || 'https://smart-review-api.nightkille.workers.dev'
const R2_PUBLIC_URL = Deno.env.get('R2_PUBLIC_URL') || 'https://7b72031b240604b8e9f88904de2f127c.r2.cloudflarestorage.com/smart-review-files'

// R2 직접 접근 (사용 안 함 - Workers API 사용)
const R2_ACCOUNT_ID = Deno.env.get('R2_ACCOUNT_ID')
const R2_ACCESS_KEY_ID = Deno.env.get('R2_ACCESS_KEY_ID')
const R2_SECRET_ACCESS_KEY = Deno.env.get('R2_SECRET_ACCESS_KEY')
const R2_BUCKET_NAME = Deno.env.get('R2_BUCKET_NAME') || 'smart-review-files'

// Gemini API 키
const GEMINI_API_KEY = Deno.env.get('GEMINI_API_KEY') || 'AIzaSyCNqb8uWU_-RPm-sY-8xrl8FtbSa8TrNpk'

// 국세청 API 키
const NTS_API_KEY = Deno.env.get('NTS_API_KEY') || 'ee1029d78506a80ebfcb9bff80a6a2b1f8458076330d4d0f7ff3da3bdf2298e6'
const NTS_API_URL = 'https://api.odcloud.kr/api/nts-businessman/v1/status'

// ============================================
// 1. AI 추출 (Gemini API)
// ============================================

async function callGeminiAPI(
  apiKey: string,
  model: string,
  image: string,
  prompt: string
): Promise<Response> {
  return await fetch(
    `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${apiKey}`,
    {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        contents: [
          {
            parts: [
              {
                text: prompt
              },
              {
                inline_data: {
                  mime_type: 'image/png',
                  data: image
                }
              }
            ]
          }
        ],
        generationConfig: {
          temperature: 0.1,
          maxOutputTokens: 1000,
        }
      }),
    }
  )
}

// 이미지가 사업자등록증인지 확인
async function verifyBusinessRegistrationImage(image: string): Promise<boolean> {
  const verificationPrompt = `이 이미지가 한국의 사업자등록증인지 확인해주세요.

다음과 같은 요소가 있는지 확인하세요:
- "사업자등록증" 또는 "사업자등록증명원" 텍스트
- 사업자등록번호 (000-00-00000 형식)
- 상호명, 대표자명, 사업장소재지 등의 정보
- 정부 기관 인증 마크나 도장

응답은 다음 형식의 JSON만 반환해주세요:
{
  "is_business_registration": true 또는 false,
  "confidence": "high" 또는 "medium" 또는 "low",
  "reason": "확인 이유"
}

사업자등록증이 아니거나 확인이 불가능한 경우 "is_business_registration": false로 설정하고 reason에 이유를 설명해주세요.`

  try {
    const geminiResponse = await callGeminiAPI(
      GEMINI_API_KEY,
      'gemini-2.5-flash',
      image,
      verificationPrompt
    )

    if (!geminiResponse.ok) {
      const errorText = await geminiResponse.text()
      console.error('❌ 이미지 검증 실패:', geminiResponse.status, errorText)
      return false
    }

    const geminiData = await geminiResponse.json()
    const extractedText = geminiData.candidates?.[0]?.content?.parts?.[0]?.text

    if (!extractedText) {
      console.error('❌ 이미지 검증 응답이 없습니다')
      return false
    }

    // JSON 파싱
    try {
      const jsonMatch = extractedText.match(/```json\s*([\s\S]*?)\s*```/) ||
                       extractedText.match(/```\s*([\s\S]*?)\s*```/) ||
                       [null, extractedText]
      
      const result = JSON.parse(jsonMatch[1] || extractedText)
      const isBusinessRegistration = result.is_business_registration === true
      const confidence = result.confidence || 'low'
      
      console.log(`📋 이미지 검증 결과:`, {
        isBusinessRegistration,
        confidence,
        reason: result.reason
      })

      // confidence가 low인 경우도 허용하되, false인 경우만 거부
      if (!isBusinessRegistration) {
        throw new Error(`사업자등록증이 아닙니다: ${result.reason || '이미지가 사업자등록증이 아닌 것으로 확인되었습니다'}`)
      }

      return true
    } catch (parseError) {
      console.error('❌ 이미지 검증 결과 파싱 실패:', parseError)
      // 파싱 실패 시 텍스트에서 "사업자등록증" 키워드 확인
      if (extractedText.toLowerCase().includes('사업자등록증') || 
          extractedText.toLowerCase().includes('business registration')) {
        return true
      }
      return false
    }
  } catch (error) {
    console.error('❌ 이미지 검증 중 오류:', error)
    throw error
  }
}

async function extractBusinessInfo(image: string): Promise<any> {
  const extractionPrompt = `이 한국 사업자등록증 이미지를 분석하여 다음 정보를 JSON 형태로 추출해주세요:
- business_name: 상호명
- business_number: 사업자등록번호 (000-00-00000 형식)
- representative_name: 대표자명
- business_address: 사업장 주소
- business_type: 업태
- business_item: 종목

읽을 수 없는 정보는 null로 설정하고, 반드시 유효한 JSON만 반환해주세요.`

  const models = ['gemini-2.5-flash-lite', 'gemini-2.5-flash']
  let extractedText: string | null = null
  
  for (let i = 0; i < models.length; i++) {
    const model = models[i]
    const isLastModel = i === models.length - 1
    
    try {
      console.log(`🔄 ${model} 모델로 시도 중...`)
      const geminiResponse = await callGeminiAPI(GEMINI_API_KEY, model, image, extractionPrompt)
      
      if (!geminiResponse.ok) {
        const errorText = await geminiResponse.text()
        console.error(`❌ ${model} 모델 실패:`, geminiResponse.status, errorText)
        
        if (isLastModel) {
          throw new Error(`AI 서비스 오류: ${errorText}`)
        }
        continue
      }
      
      const geminiData = await geminiResponse.json()
      extractedText = geminiData.candidates?.[0]?.content?.parts?.[0]?.text
      
      if (!extractedText) {
        throw new Error('Gemini API 응답에서 텍스트를 찾을 수 없습니다')
      }
      
      console.log(`✅ ${model} 모델 성공!`)
      break
      
    } catch (error) {
      console.error(`❌ ${model} 모델 호출 중 오류:`, error)
      if (isLastModel) {
        throw error
      }
      continue
    }
  }
  
  if (!extractedText) {
    throw new Error('모든 Gemini 모델 시도 실패')
  }

  // JSON 파싱
  try {
    const jsonMatch = extractedText.match(/```json\s*([\s\S]*?)\s*```/) || 
                     extractedText.match(/```\s*([\s\S]*?)\s*```/) ||
                     [null, extractedText]
    
    return JSON.parse(jsonMatch[1] || extractedText)
  } catch (parseError) {
    // JSON 파싱 실패 시 텍스트에서 정보 추출
    const data: Record<string, string> = {}
    const patterns = {
      business_name: /상호[:\s]*([^\n\r]+)/i,
      business_number: /등록번호[:\s]*([0-9-]+)/i,
      representative_name: /성명[:\s]*([^\n\r]+)/i,
      business_address: /사업장소재지[:\s]*([^\n\r]+)/i,
      business_type: /업태[:\s]*([^\n\r]+)/i,
      business_item: /종목[:\s]*([^\n\r]+)/i,
    }
    
    for (const [key, pattern] of Object.entries(patterns)) {
      const match = extractedText.match(pattern)
      if (match && match[1]) {
        data[key] = match[1].trim()
      }
    }
    
    return data
  }
}

// ============================================
// 2. 사업자등록번호 검증 (국세청 API)
// ============================================

function validateChecksum(businessNumber: string): boolean {
  const cleanNumber = businessNumber.replaceAll('-', '')
  if (cleanNumber.length !== 10) return false

  const weights = [1, 3, 7, 1, 3, 7, 1, 3, 5]
  let sum = 0

  for (let i = 0; i < 9; i++) {
    const digit = parseInt(cleanNumber[i])
    sum += digit * weights[i]
  }

  const lastDigit = parseInt(cleanNumber[8])
  sum += Math.floor((lastDigit * 5) / 10)

  const remainder = sum % 10
  const checkDigit = remainder === 0 ? 0 : 10 - remainder

  return checkDigit === parseInt(cleanNumber[9])
}

async function validateBusinessNumber(businessNumber: string): Promise<any> {
  const cleanNumber = businessNumber.replaceAll('-', '')
  
  // 기본 형식 검증
  if (!/^\d{10}$/.test(cleanNumber)) {
    throw new Error('사업자등록번호는 10자리 숫자여야 합니다.')
  }

  // 체크섬 검증
  if (!validateChecksum(cleanNumber)) {
    throw new Error('사업자등록번호 형식이 올바르지 않습니다.')
  }

  // 국세청 API 호출
  console.log('🔍 국세청 API 호출 시작:', cleanNumber)
  
  const response = await fetch(`${NTS_API_URL}?serviceKey=${NTS_API_KEY}`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    },
    body: JSON.stringify({
      b_no: [cleanNumber]
    }),
  })

  if (!response.ok) {
    throw new Error(`국세청 API 호출 실패: ${response.status}`)
  }

  const jsonData = await response.json()
  const statusCode = jsonData.status_code || ''
  const data = jsonData.data || []

  if (statusCode === 'OK' && data.length > 0) {
    const businessInfo = data[0]
    const bSttCd = businessInfo.b_stt_cd || ''
    
    return {
      isValid: bSttCd === '01', // 계속사업자
      businessStatus: businessInfo.b_stt || '',
      businessStatusCode: bSttCd,
      taxType: businessInfo.tax_type || '',
      taxTypeCode: businessInfo.tax_type_cd || '',
    }
  } else {
    return {
      isValid: false,
      errorMessage: '사업자 정보를 찾을 수 없습니다.',
    }
  }
}

// ============================================
// 3. R2 파일 업로드 및 삭제
// ============================================

function generateFilePath(userId: string, fileName: string): string {
  const now = new Date()
  const year = now.getFullYear()
  const month = String(now.getMonth() + 1).padStart(2, '0')
  const day = String(now.getDate()).padStart(2, '0')
  const timestamp = now.getTime()
  
  const extension = fileName.substring(fileName.lastIndexOf('.'))
  return `business-registration/${year}/${month}/${day}/${userId}_${timestamp}${extension}`
}

async function sha256(data: string | Uint8Array): Promise<string> {
  const dataBuffer = typeof data === 'string' 
    ? new TextEncoder().encode(data)
    : data
  
  const hashBuffer = await crypto.subtle.digest('SHA-256', dataBuffer)
  return Array.from(new Uint8Array(hashBuffer))
    .map(b => b.toString(16).padStart(2, '0'))
    .join('')
}

async function hmacSha256Binary(key: string | Uint8Array, data: string): Promise<Uint8Array> {
  const encoder = new TextEncoder()
  const keyBuffer = typeof key === 'string' ? encoder.encode(key) : key
  const dataBuffer = encoder.encode(data)
  
  const cryptoKey = await crypto.subtle.importKey(
    'raw', keyBuffer,
    { name: 'HMAC', hash: 'SHA-256' },
    false, ['sign']
  )
  
  const signature = await crypto.subtle.sign('HMAC', cryptoKey, dataBuffer)
  return new Uint8Array(signature)
}

async function uploadToR2(
  fileBytes: Uint8Array,
  filePath: string,
  contentType: string,
  userId: string
): Promise<string> {
  // Workers API를 통해 파일 업로드
  const formData = new FormData()
  const blob = new Blob([fileBytes], { type: contentType })
  const fileName = filePath.split('/').pop() || 'file'
  formData.append('file', blob, fileName)
  formData.append('userId', userId)
  formData.append('fileType', 'business_registration')
  
  const uploadResponse = await fetch(`${WORKERS_API_URL}/api/upload`, {
    method: 'POST',
    body: formData,
  })
  
  if (!uploadResponse.ok) {
    const errorText = await uploadResponse.text()
    throw new Error(`Workers API 업로드 실패: ${uploadResponse.status} - ${errorText}`)
  }
  
  const result = await uploadResponse.json()
  return result.url || `${R2_PUBLIC_URL}/${filePath}`
}

async function deleteFromR2(filePath: string): Promise<void> {
  // Workers API를 통해 파일 삭제 (필요한 경우)
  // 현재는 삭제 기능이 Workers API에 없으므로 무시
  console.log(`파일 삭제 스킵: ${filePath} (Workers API에서 삭제 기능 지원 필요)`)
}

// ============================================
// 4. 메인 처리 함수
// ============================================

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // 환경 변수 검증
    if (!R2_ACCOUNT_ID || !R2_ACCESS_KEY_ID || !R2_SECRET_ACCESS_KEY || !R2_BUCKET_NAME) {
      throw new Error('R2 설정이 완료되지 않았습니다.')
    }

    // 인증 확인
    const authHeader = req.headers.get('Authorization')
    if (!authHeader) {
      throw new Error('인증이 필요합니다.')
    }

    // Supabase 클라이언트 생성
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    const supabase = createClient(supabaseUrl, supabaseKey, {
      global: {
        headers: { Authorization: authHeader },
      },
    })

    // 사용자 정보 확인
    const { data: { user }, error: userError } = await supabase.auth.getUser()
    if (userError || !user) {
      throw new Error('인증된 사용자를 찾을 수 없습니다.')
    }

    // 요청 데이터 파싱
    const requestData: VerifyAndRegisterRequest = await req.json()
    const { image, fileName } = requestData

    if (!image || !fileName) {
      throw new Error('필수 파라미터가 누락되었습니다.')
    }

    console.log('🔄 검증 및 등록 프로세스 시작:', { userId: user.id, fileName })

    let extractedData: any = null
    let validationResult: any = null
    let uploadedFileUrl: string | null = null
    let companyId: string | null = null

    try {
      // 0단계: 이미지 검증 (사업자등록증인지 확인)
      console.log('🔍 0단계: 이미지 검증 시작 (사업자등록증 확인)')
      try {
        const isBusinessRegistration = await verifyBusinessRegistrationImage(image)
        if (!isBusinessRegistration) {
          throw new Error('업로드된 이미지가 사업자등록증이 아닙니다. 정확한 사업자등록증 이미지를 업로드해주세요.')
        }
        console.log('✅ 이미지 검증 완료: 사업자등록증 확인됨')
      } catch (verificationError) {
        const errorResponse: VerifyAndRegisterResponse = {
          success: false,
          error: verificationError instanceof Error ? verificationError.message : '이미지 검증 실패',
          step: 'image_verification',
        }
        return new Response(
          JSON.stringify(errorResponse),
          {
            headers: { ...corsHeaders, 'Content-Type': 'application/json' },
            status: 200, // 검증 실패는 정상 응답 (200)
          }
        )
      }

      // 1단계: AI 추출
      console.log('🤖 1단계: AI 추출 시작')
      extractedData = await extractBusinessInfo(image)
      console.log('✅ AI 추출 완료:', extractedData)

      if (!extractedData.business_number) {
        throw new Error('사업자등록번호를 추출할 수 없습니다.')
      }

      // 2단계: 사업자등록번호 검증
      console.log('🔍 2단계: 사업자등록번호 검증 시작')
      validationResult = await validateBusinessNumber(extractedData.business_number)
      console.log('✅ 검증 완료:', validationResult)

      if (!validationResult.isValid) {
        const errorResponse: VerifyAndRegisterResponse = {
          success: false,
          extractedData: extractedData,
          validationResult: validationResult,
          error: validationResult.errorMessage || '유효하지 않은 사업자등록번호입니다.',
          step: 'validation',
        }
        return new Response(
          JSON.stringify(errorResponse),
          {
            headers: { ...corsHeaders, 'Content-Type': 'application/json' },
            status: 200, // 검증 실패는 정상 응답 (200)
          }
        )
      }

      // 3단계: 파일 업로드
      console.log('📁 3단계: 파일 업로드 시작')
      const fileBytes = Uint8Array.from(atob(image), c => c.charCodeAt(0))
      const contentType = fileName.toLowerCase().endsWith('.pdf') ? 'application/pdf' : 'image/png'
      const filePath = generateFilePath(user.id, fileName)
      
      uploadedFileUrl = await uploadToR2(fileBytes, filePath, contentType, user.id)
      console.log('✅ 파일 업로드 완료:', uploadedFileUrl)

      // 4단계: DB 저장
      console.log('💾 4단계: DB 저장 시작')
      
      const businessNumber = extractedData.business_number
      const businessName = extractedData.business_name || ''
      const businessAddress = extractedData.business_address || ''
      const representativeName = extractedData.representative_name || ''
      const businessType = extractedData.business_type || ''

      // 기존 회사 확인 (이미 등록된 사업자번호인지 확인)
      const { data: existingCompany } = await supabase
        .from('companies')
        .select('id')
        .eq('business_number', businessNumber)
        .maybeSingle()

      if (existingCompany) {
        // 이미 등록된 사업자번호 - 업로드된 파일 삭제 후 에러 반환
        console.log('⚠️ 이미 등록된 사업자번호:', businessNumber)
        
        // 업로드된 파일 삭제
        if (uploadedFileUrl) {
          try {
            const filePath = uploadedFileUrl.split(`${R2_BUCKET_NAME}/`)[1]
            if (filePath) {
              await deleteFromR2(filePath)
              console.log('🗑️ 중복 등록 방지: 업로드된 파일 삭제 완료')
            }
          } catch (deleteError) {
            console.error('⚠️ 파일 삭제 실패:', deleteError)
          }
        }

        const errorResponse: VerifyAndRegisterResponse = {
          success: false,
          extractedData: extractedData,
          validationResult: validationResult,
          error: '이미 등록된 사업자번호입니다. 관리자에게 문의 주시기 바랍니다.',
          step: 'duplicate',
        }

        return new Response(
          JSON.stringify(errorResponse),
          {
            headers: { ...corsHeaders, 'Content-Type': 'application/json' },
            status: 200, // 정상 응답 (에러는 응답 데이터에 포함)
          }
        )
      }

      // 새 회사 생성
      const { data: newCompany, error: insertError } = await supabase
        .from('companies')
        .insert({
          user_id: user.id,
          business_name: businessName,
          business_number: businessNumber,
          address: businessAddress,
          representative_name: representativeName,
          business_type: businessType,
          registration_file_url: uploadedFileUrl,
          contact_email: '',
          contact_phone: '',
        })
        .select('id')
        .single()

      if (insertError) {
        throw new Error(`DB 저장 실패: ${insertError.message}`)
      }

      companyId = newCompany.id
      console.log('✅ 회사 정보 저장 완료')

      // company_users 관계 추가
      const { error: relationError } = await supabase
        .from('company_users')
        .insert({
          company_id: companyId,
          user_id: user.id,
          company_role: 'owner',
        })

      if (relationError) {
        throw new Error(`회사-사용자 관계 추가 실패: ${relationError.message}`)
      }

      console.log('✅ 회사-사용자 관계 추가 완료')

      // 성공 응답
      const successResponse: VerifyAndRegisterResponse = {
        success: true,
        extractedData: extractedData,
        validationResult: validationResult,
        companyId: companyId!,
        fileUrl: uploadedFileUrl,
      }

      console.log('🎉 검증 및 등록 완료:', companyId)

      return new Response(
        JSON.stringify(successResponse),
        {
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
          status: 200,
        }
      )

    } catch (error) {
      console.error('❌ 처리 중 오류:', error)

      // 롤백: 업로드된 파일 삭제
      if (uploadedFileUrl) {
        try {
          // Workers API를 통해 업로드된 파일이므로 삭제는 스킵
          // (필요시 Workers API에 DELETE 엔드포인트 추가 필요)
          console.log('🗑️ 롤백: 파일 삭제 스킵 (Workers API 삭제 기능 필요)')
        } catch (deleteError) {
          console.error('⚠️ 롤백: 파일 삭제 실패:', deleteError)
        }
      }

      // 롤백: DB 삭제 (새로 생성된 경우만)
      if (companyId) {
        try {
          await supabase.from('companies').delete().eq('id', companyId)
          console.log('🗑️ 롤백: DB 삭제 완료')
        } catch (dbError) {
          console.error('⚠️ 롤백: DB 삭제 실패:', dbError)
        }
      }

      const errorResponse: VerifyAndRegisterResponse = {
        success: false,
        extractedData: extractedData || undefined,
        validationResult: validationResult || undefined,
        error: error instanceof Error ? error.message : String(error),
        step: uploadedFileUrl ? 'database' : validationResult ? 'upload' : extractedData ? 'validation' : 'extraction',
      }

      // 이미지 검증 단계에서 실패한 경우 특별 처리
      if (error instanceof Error && error.message.includes('사업자등록증이 아닙니다')) {
        errorResponse.step = 'image_verification'
      }

      return new Response(
        JSON.stringify(errorResponse),
        {
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
          status: 500,
        }
      )
    }

  } catch (error) {
    console.error('❌ Edge Function 오류:', error)

    const errorResponse: VerifyAndRegisterResponse = {
      success: false,
      error: error instanceof Error ? error.message : String(error),
    }

    return new Response(
      JSON.stringify(errorResponse),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 500,
      }
    )
  }
})

