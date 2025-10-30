// Supabase Edge Function for R2 Presigned URL Generation
import { serve } from "https://deno.land/std@0.168.0/http/server.ts"

declare const Deno: {
  env: {
    get(key: string): string | undefined;
  };
};

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
}

interface PresignedUrlRequest {
  fileName?: string
  userId?: string
  contentType?: string
  fileType?: string
  filePath?: string  // 기존 파일 경로 (GET용)
  method?: 'GET' | 'PUT'  // GET: 다운로드/조회, PUT: 업로드
}

interface PresignedUrlResponse {
  success: boolean
  presignedUrl?: string
  filePath?: string
  error?: string
}

// R2 설정
const R2_ACCOUNT_ID = Deno.env.get('R2_ACCOUNT_ID')
const R2_ACCESS_KEY_ID = Deno.env.get('R2_ACCESS_KEY_ID')
const R2_SECRET_ACCESS_KEY = Deno.env.get('R2_SECRET_ACCESS_KEY')
const R2_BUCKET_NAME = Deno.env.get('R2_BUCKET_NAME')

// 허용된 파일 타입들
const ALLOWED_FILE_TYPES = {
  'business_registration': {
    extensions: ['.jpg', '.jpeg', '.png', '.pdf'],
    maxSize: 10 * 1024 * 1024, // 10MB
    folder: 'business-registration'
  },
  'profile_image': {
    extensions: ['.jpg', '.jpeg', '.png', '.webp'],
    maxSize: 5 * 1024 * 1024, // 5MB
    folder: 'profile-images'
  },
  'review_image': {
    extensions: ['.jpg', '.jpeg', '.png', '.webp'],
    maxSize: 5 * 1024 * 1024, // 5MB
    folder: 'review-images'
  }
}

// 파일 경로 생성 함수
function generateFilePath(userId: string, fileType: string, fileName: string): string {
  const now = new Date()
  const year = now.getFullYear()
  const month = String(now.getMonth() + 1).padStart(2, '0')
  const day = String(now.getDate()).padStart(2, '0')
  const timestamp = now.getTime()
  
  const extension = fileName.substring(fileName.lastIndexOf('.'))
  const fileTypeConfig = ALLOWED_FILE_TYPES[fileType as keyof typeof ALLOWED_FILE_TYPES]
  
  return `${fileTypeConfig.folder}/${year}/${month}/${day}/${userId}_${timestamp}${extension}`
}

// AWS Signature V4 서명 생성 (Presigned URL용)
async function createPresignedUrlSignature(
  method: string,
  url: string,
  expiresIn: number
): Promise<string> {
  const region = 'auto'
  const service = 's3'
  const algorithm = 'AWS4-HMAC-SHA256'
  
  const urlObj = new URL(url)
  const date = new Date()
  const dateStamp = date.toISOString().slice(0, 10).replace(/-/g, '')
  const amzDate = date.toISOString().replace(/[:\-]|\.\d{3}/g, '')
  const expirationDate = new Date(Date.now() + expiresIn * 1000)
  const expirationDateStamp = expirationDate.toISOString().slice(0, 10).replace(/-/g, '')
  const expirationTime = expirationDate.toISOString().replace(/[:\-]|\.\d{3}/g, '')
  
  // Query string parameters
  const queryParams = new URLSearchParams({
    'X-Amz-Algorithm': algorithm,
    'X-Amz-Credential': `${R2_ACCESS_KEY_ID}/${dateStamp}/${region}/${service}/aws4_request`,
    'X-Amz-Date': amzDate,
    'X-Amz-Expires': expiresIn.toString(),
    'X-Amz-SignedHeaders': 'host',
  })
  
  // Canonical Request
  const canonicalHeaders = `host:${urlObj.host}\n`
  const signedHeaders = 'host'
  const canonicalRequest = [
    method,
    urlObj.pathname,
    queryParams.toString(),
    canonicalHeaders,
    signedHeaders,
    'UNSIGNED-PAYLOAD'
  ].join('\n')
  
  // String to Sign
  const credentialScope = `${dateStamp}/${region}/${service}/aws4_request`
  const hashedCanonicalRequest = await sha256(canonicalRequest)
  const stringToSign = [
    algorithm,
    amzDate,
    credentialScope,
    hashedCanonicalRequest
  ].join('\n')
  
  // 서명 생성
  const kSecret = `AWS4${R2_SECRET_ACCESS_KEY}`
  const kDate = await hmacSha256Binary(kSecret, dateStamp)
  const kRegion = await hmacSha256Binary(kDate, region)
  const kService = await hmacSha256Binary(kRegion, service)
  const kSigning = await hmacSha256Binary(kService, 'aws4_request')
  
  const signatureBuffer = await hmacSha256Binary(kSigning, stringToSign)
  const signature = Array.from(signatureBuffer)
    .map(b => b.toString(16).padStart(2, '0'))
    .join('')
  
  queryParams.set('X-Amz-Signature', signature)
  
  return `${url}?${queryParams.toString()}`
}

// SHA256 해시
async function sha256(data: string): Promise<string> {
  const encoder = new TextEncoder()
  const dataBuffer = encoder.encode(data)
  
  const hashBuffer = await crypto.subtle.digest('SHA-256', dataBuffer)
  return Array.from(new Uint8Array(hashBuffer))
    .map(b => b.toString(16).padStart(2, '0'))
    .join('')
}

// HMAC-SHA256 (binary output)
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

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // 환경 변수 검증
    if (!R2_ACCOUNT_ID || !R2_ACCESS_KEY_ID || !R2_SECRET_ACCESS_KEY || !R2_BUCKET_NAME) {
      throw new Error('R2 설정이 완료되지 않았습니다.')
    }

    const { fileName, userId, contentType, fileType, filePath, method = 'PUT' }: PresignedUrlRequest = await req.json()

    let finalFilePath: string
    let finalMethod: string
    
    if (method === 'GET' && filePath) {
      // GET: 기존 파일 경로 사용 (조회용)
      finalFilePath = filePath
      finalMethod = 'GET'
    } else if (method === 'PUT' && fileName && userId && contentType && fileType) {
      // PUT: 새 파일 업로드용
      // 파일 타입 검증
      const fileTypeConfig = ALLOWED_FILE_TYPES[fileType as keyof typeof ALLOWED_FILE_TYPES]
      if (!fileTypeConfig) {
        throw new Error(`지원하지 않는 파일 타입: ${fileType}`)
      }

      // 파일 확장자 검증
      const extension = fileName.substring(fileName.lastIndexOf('.'))
      if (!fileTypeConfig.extensions.includes(extension.toLowerCase())) {
        throw new Error(`지원하지 않는 파일 확장자: ${extension}`)
      }

      // 파일 경로 생성
      finalFilePath = generateFilePath(userId, fileType, fileName)
      finalMethod = 'PUT'
    } else {
      throw new Error('필수 파라미터가 누락되었습니다. (PUT: fileName, userId, contentType, fileType) (GET: filePath)')
    }

    const url = `https://${R2_ACCOUNT_ID}.r2.cloudflarestorage.com/${R2_BUCKET_NAME}/${finalFilePath}`

    // Presigned URL 생성 (GET: 1시간, PUT: 15분)
    const expiresIn = finalMethod === 'GET' ? 60 * 60 : 15 * 60
    const presignedUrl = await createPresignedUrlSignature(finalMethod, url, expiresIn)

    const response: PresignedUrlResponse = {
      success: true,
      presignedUrl,
      filePath: finalFilePath,
    }

    return new Response(
      JSON.stringify(response),
      { 
        headers: { 
          ...corsHeaders, 
          'Content-Type': 'application/json' 
        } 
      }
    )

  } catch (error) {
    console.error('Presigned URL 생성 오류:', error)
    
    const response: PresignedUrlResponse = {
      success: false,
      error: error.message
    }

    return new Response(
      JSON.stringify(response),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 500,
      }
    )
  }
})

