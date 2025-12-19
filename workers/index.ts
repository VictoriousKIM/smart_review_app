// 라우팅만 담당하는 메인 파일

// 핸들러 함수들 import
import handleNaverAuth from './functions/naver-auth';
import { handlePresignedUrl, handlePresignedUrlForViewing } from './functions/presigned-url';
import { handleUpload } from './functions/upload';
import { handleGetFile } from './functions/get-file';
import { handleVerifyAndRegister } from './functions/verify-and-register';
import { handleDeleteFile } from './functions/delete-file';
import { handleAnalyzeCampaignImage } from './functions/analyze-campaign-image';

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
  NAVER_CLIENT_ID: string;
  NAVER_CLIENT_SECRET: string;
  NAVER_REDIRECT_URI: string;
  JWT_SECRET: string;
}

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type, Authorization, X-Requested-With',
  'Access-Control-Expose-Headers': 'Content-Type, Content-Length',
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

    if (url.pathname === '/api/naver-auth' && request.method === 'POST') {
      return handleNaverAuth(request, env);
    }

    return new Response(
      JSON.stringify({ error: 'Not Found', path: url.pathname }),
      { status: 404, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  },
};
