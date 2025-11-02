var __defProp = Object.defineProperty;
var __name = (target, value) => __defProp(target, "name", { value, configurable: true });

// .wrangler/tmp/bundle-xuGCdD/checked-fetch.js
var urls = /* @__PURE__ */ new Set();
function checkURL(request, init) {
  const url = request instanceof URL ? request : new URL(
    (typeof request === "string" ? new Request(request, init) : request).url
  );
  if (url.port && url.port !== "443" && url.protocol === "https:") {
    if (!urls.has(url.toString())) {
      urls.add(url.toString());
      console.warn(
        `WARNING: known issue with \`fetch()\` requests to custom HTTPS ports in published Workers:
 - ${url.toString()} - the custom port will be ignored when the Worker is published using the \`wrangler deploy\` command.
`
      );
    }
  }
}
__name(checkURL, "checkURL");
globalThis.fetch = new Proxy(globalThis.fetch, {
  apply(target, thisArg, argArray) {
    const [request, init] = argArray;
    checkURL(request, init);
    return Reflect.apply(target, thisArg, argArray);
  }
});

// workers/index.ts
var corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, POST, PUT, DELETE, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type, Authorization"
};
var workers_default = {
  async fetch(request, env) {
    const url = new URL(request.url);
    if (request.method === "OPTIONS") {
      return new Response(null, { headers: corsHeaders });
    }
    if (url.pathname === "/health") {
      return new Response(
        JSON.stringify({
          status: "ok",
          timestamp: (/* @__PURE__ */ new Date()).toISOString(),
          service: "smart-review-api"
        }),
        {
          headers: { ...corsHeaders, "Content-Type": "application/json" }
        }
      );
    }
    if (url.pathname === "/api/presigned-url" && request.method === "POST") {
      return handlePresignedUrl(request, env);
    }
    if (url.pathname === "/api/presigned-url-view" && request.method === "POST") {
      return handlePresignedUrlForViewing(request, env);
    }
    if (url.pathname === "/api/upload" && request.method === "POST") {
      return handleUpload(request, env);
    }
    if (url.pathname.startsWith("/api/files/") && request.method === "GET") {
      return handleGetFile(request, env);
    }
    if (url.pathname === "/api/verify-and-register" && request.method === "POST") {
      return handleVerifyAndRegister(request, env);
    }
    if (url.pathname === "/api/delete-file" && request.method === "POST") {
      return handleDeleteFile(request, env);
    }
    return new Response(
      JSON.stringify({ error: "Not Found", path: url.pathname }),
      { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
};
async function handlePresignedUrlForViewing(request, env) {
  try {
    const { filePath } = await request.json();
    if (!filePath) {
      return new Response(
        JSON.stringify({ success: false, error: "filePath is required" }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" }
        }
      );
    }
    const presignedUrl = await createPresignedUrlSignature(
      "GET",
      filePath,
      "application/octet-stream",
      3600,
      // 1시간 유효
      env
    );
    return new Response(
      JSON.stringify({
        success: true,
        url: presignedUrl,
        filePath,
        expiresIn: 3600,
        expiresAt: Math.floor(Date.now() / 1e3) + 3600,
        method: "GET"
      }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" }
      }
    );
  } catch (error) {
    return new Response(
      JSON.stringify({
        success: false,
        error: error instanceof Error ? error.message : "Unknown error"
      }),
      {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" }
      }
    );
  }
}
__name(handlePresignedUrlForViewing, "handlePresignedUrlForViewing");
async function handlePresignedUrl(request, env) {
  try {
    const { fileName, userId, contentType, fileType, method = "PUT" } = await request.json();
    if (!fileName || !userId || !contentType || !fileType) {
      return new Response(
        JSON.stringify({ success: false, error: "Missing required fields" }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" }
        }
      );
    }
    const date = /* @__PURE__ */ new Date();
    const year = date.getFullYear();
    const month = String(date.getMonth() + 1).padStart(2, "0");
    const day = String(date.getDate()).padStart(2, "0");
    const timestamp = Date.now();
    const filePath = `${fileType}/${year}/${month}/${day}/${userId}_${timestamp}_${fileName}`;
    const expiresIn = method === "GET" ? 3600 : 900;
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
        expiresAt: Math.floor(Date.now() / 1e3) + expiresIn,
        method
      }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" }
      }
    );
  } catch (error) {
    return new Response(
      JSON.stringify({
        success: false,
        error: error instanceof Error ? error.message : "Unknown error"
      }),
      {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" }
      }
    );
  }
}
__name(handlePresignedUrl, "handlePresignedUrl");
async function createPresignedUrlSignature(method, filePath, contentType, expiresIn, env) {
  const region = "auto";
  const service = "s3";
  const algorithm = "AWS4-HMAC-SHA256";
  const url = `https://${env.R2_ACCOUNT_ID}.r2.cloudflarestorage.com/${env.R2_BUCKET_NAME}/${filePath}`;
  const urlObj = new URL(url);
  const date = /* @__PURE__ */ new Date();
  const dateStamp = date.toISOString().slice(0, 10).replace(/-/g, "");
  const amzDate = date.toISOString().replace(/[:\-]|\.\d{3}/g, "");
  const queryParams = new URLSearchParams({
    "X-Amz-Algorithm": algorithm,
    "X-Amz-Credential": `${env.R2_ACCESS_KEY_ID}/${dateStamp}/${region}/${service}/aws4_request`,
    "X-Amz-Date": amzDate,
    "X-Amz-Expires": expiresIn.toString(),
    "X-Amz-SignedHeaders": "host"
  });
  const canonicalHeaders = `host:${urlObj.host}
`;
  const signedHeaders = "host";
  const canonicalRequest = [
    method,
    urlObj.pathname,
    queryParams.toString(),
    canonicalHeaders,
    signedHeaders,
    "UNSIGNED-PAYLOAD"
  ].join("\n");
  const credentialScope = `${dateStamp}/${region}/${service}/aws4_request`;
  const hashedCanonicalRequest = await sha256(canonicalRequest);
  const stringToSign = [
    algorithm,
    amzDate,
    credentialScope,
    hashedCanonicalRequest
  ].join("\n");
  const kSecret = `AWS4${env.R2_SECRET_ACCESS_KEY}`;
  const kDate = await hmacSha256Binary(kSecret, dateStamp);
  const kRegion = await hmacSha256Binary(kDate, region);
  const kService = await hmacSha256Binary(kRegion, service);
  const kSigning = await hmacSha256Binary(kService, "aws4_request");
  const signatureBuffer = await hmacSha256Binary(kSigning, stringToSign);
  const signature = Array.from(signatureBuffer).map((b) => b.toString(16).padStart(2, "0")).join("");
  queryParams.set("X-Amz-Signature", signature);
  return `${url}?${queryParams.toString()}`;
}
__name(createPresignedUrlSignature, "createPresignedUrlSignature");
async function sha256(data) {
  const hashBuffer = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(data));
  return Array.from(new Uint8Array(hashBuffer)).map((b) => b.toString(16).padStart(2, "0")).join("");
}
__name(sha256, "sha256");
async function hmacSha256Binary(key, data) {
  const keyBuffer = typeof key === "string" ? new TextEncoder().encode(key) : new Uint8Array(key);
  const dataBuffer = new TextEncoder().encode(data);
  const cryptoKey = await crypto.subtle.importKey(
    "raw",
    keyBuffer.buffer,
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"]
  );
  const signature = await crypto.subtle.sign("HMAC", cryptoKey, dataBuffer);
  return new Uint8Array(signature);
}
__name(hmacSha256Binary, "hmacSha256Binary");
async function handleUpload(request, env) {
  try {
    const formData = await request.formData();
    const file = formData.get("file");
    const userId = formData.get("userId");
    const fileType = formData.get("fileType");
    if (!file || !userId || !fileType) {
      return new Response(
        JSON.stringify({ success: false, error: "Missing required fields" }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" }
        }
      );
    }
    const date = /* @__PURE__ */ new Date();
    const year = date.getFullYear();
    const month = String(date.getMonth() + 1).padStart(2, "0");
    const day = String(date.getDate()).padStart(2, "0");
    const timestamp = Date.now();
    const key = `${fileType}/${year}/${month}/${day}/${userId}_${timestamp}_${file.name}`;
    await env.FILES.put(key, file.stream(), {
      httpMetadata: {
        contentType: file.type
      },
      customMetadata: {
        userId,
        fileType,
        uploadedAt: (/* @__PURE__ */ new Date()).toISOString()
      }
    });
    const publicUrl = `${env.R2_PUBLIC_URL}/${key}`;
    return new Response(
      JSON.stringify({
        success: true,
        url: publicUrl,
        key
      }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" }
      }
    );
  } catch (error) {
    return new Response(
      JSON.stringify({
        success: false,
        error: error instanceof Error ? error.message : "Unknown error"
      }),
      {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" }
      }
    );
  }
}
__name(handleUpload, "handleUpload");
async function handleGetFile(request, env) {
  try {
    const url = new URL(request.url);
    const key = url.pathname.replace("/api/files/", "");
    if (!key) {
      return new Response(
        JSON.stringify({ error: "File key is required" }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" }
        }
      );
    }
    const object = await env.FILES.get(key);
    if (!object) {
      return new Response(
        JSON.stringify({ error: "File not found" }),
        {
          status: 404,
          headers: { ...corsHeaders, "Content-Type": "application/json" }
        }
      );
    }
    const headers = new Headers(corsHeaders);
    headers.set("Content-Type", object.httpMetadata?.contentType || "application/octet-stream");
    if (object.httpMetadata?.contentEncoding) {
      headers.set("Content-Encoding", object.httpMetadata.contentEncoding);
    }
    return new Response(object.body, { headers });
  } catch (error) {
    return new Response(
      JSON.stringify({
        error: error instanceof Error ? error.message : "Unknown error"
      }),
      {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" }
      }
    );
  }
}
__name(handleGetFile, "handleGetFile");
async function handleVerifyAndRegister(request, env) {
  try {
    let requestData;
    try {
      requestData = await request.json();
    } catch (jsonError2) {
      console.error("\u274C JSON \uD30C\uC2F1 \uC2E4\uD328:", jsonError2);
      return new Response(
        JSON.stringify({
          success: false,
          error: `\uC694\uCCAD \uB370\uC774\uD130 \uD30C\uC2F1 \uC2E4\uD328: ${jsonError2 instanceof Error ? jsonError2.message : String(jsonError2)}`,
          debugInfo: {
            contentType: request.headers.get("content-type"),
            hasBody: !!request.body
          }
        }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }
    const { image, fileName, userId } = requestData;
    const missingFields = [];
    if (!image) missingFields.push("image");
    if (!fileName) missingFields.push("fileName");
    if (!userId) missingFields.push("userId");
    if (missingFields.length > 0) {
      console.error("\u274C \uD544\uC218 \uD544\uB4DC \uB204\uB77D:", missingFields);
      return new Response(
        JSON.stringify({
          success: false,
          error: `Missing required fields: ${missingFields.join(", ")}`,
          debugInfo: {
            receivedFields: {
              hasImage: !!image,
              imageLength: image ? image.length : 0,
              fileName: fileName || null,
              userId: userId || null
            }
          }
        }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }
    let extractedData = null;
    let validationResult = null;
    try {
      const isBusinessRegistration = await verifyBusinessRegistrationImage(image, env);
      if (!isBusinessRegistration) {
        return new Response(
          JSON.stringify({
            success: false,
            error: "\uC5C5\uB85C\uB4DC\uB41C \uC774\uBBF8\uC9C0\uAC00 \uC0AC\uC5C5\uC790\uB4F1\uB85D\uC99D\uC774 \uC544\uB2D9\uB2C8\uB2E4.",
            step: "image_verification"
          }),
          { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }
      try {
        extractedData = await extractBusinessInfo(image, env);
        if (!extractedData.business_number) {
          throw new Error(`\uC0AC\uC5C5\uC790\uB4F1\uB85D\uBC88\uD638\uB97C \uCD94\uCD9C\uD560 \uC218 \uC5C6\uC2B5\uB2C8\uB2E4. \uCD94\uCD9C\uB41C \uB370\uC774\uD130: ${JSON.stringify(extractedData)}`);
        }
      } catch (extractError) {
        const errorMessage = extractError instanceof Error ? extractError.message : String(extractError);
        console.error("\u274C AI \uCD94\uCD9C \uC2E4\uD328:", errorMessage);
        throw new Error(`AI \uCD94\uCD9C \uC2E4\uD328: ${errorMessage}`);
      }
      validationResult = await validateBusinessNumber(extractedData.business_number, env);
      if (!validationResult.isValid) {
        return new Response(
          JSON.stringify({
            success: false,
            extractedData,
            validationResult,
            error: validationResult.errorMessage || "\uC720\uD6A8\uD558\uC9C0 \uC54A\uC740 \uC0AC\uC5C5\uC790\uB4F1\uB85D\uBC88\uD638\uC785\uB2C8\uB2E4.",
            step: "validation"
          }),
          { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }
      const contentType = fileName.toLowerCase().endsWith(".pdf") ? "application/pdf" : "image/png";
      const filePath = generateFilePath(userId, fileName);
      const presignedUrl = await createPresignedUrlSignature(
        "PUT",
        filePath,
        contentType,
        900,
        // 15분 유효
        env
      );
      return new Response(
        JSON.stringify({
          success: true,
          extractedData,
          validationResult,
          presignedUrl,
          filePath,
          publicUrl: `${env.R2_PUBLIC_URL}/${filePath}`
          // DB 저장은 Flutter에서 처리
        }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    } catch (error) {
      return new Response(
        JSON.stringify({
          success: false,
          extractedData: extractedData || void 0,
          validationResult: validationResult || void 0,
          error: error instanceof Error ? error.message : String(error),
          step: validationResult ? "presigned_url" : extractedData ? "validation" : "extraction",
          debugInfo: {
            errorType: error instanceof Error ? error.constructor.name : typeof error,
            errorStack: error instanceof Error ? error.stack : void 0,
            timestamp: (/* @__PURE__ */ new Date()).toISOString()
          }
        }),
        { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }
  } catch (error) {
    console.error("\u274C handleVerifyAndRegister \uC804\uCCB4 \uC624\uB958:", error);
    return new Response(
      JSON.stringify({
        success: false,
        error: error instanceof Error ? error.message : "Unknown error",
        debugInfo: {
          errorType: error instanceof Error ? error.constructor.name : typeof error,
          errorStack: error instanceof Error ? error.stack : void 0,
          timestamp: (/* @__PURE__ */ new Date()).toISOString()
        }
      }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
}
__name(handleVerifyAndRegister, "handleVerifyAndRegister");
async function callGeminiAPI(apiKey, model, image, prompt) {
  if (!apiKey || apiKey.trim() === "") {
    throw new Error("GEMINI_API_KEY\uAC00 \uC124\uC815\uB418\uC9C0 \uC54A\uC558\uC2B5\uB2C8\uB2E4.");
  }
  console.log(`\u{1F511} Gemini API \uD638\uCD9C: \uBAA8\uB378=${model}, API \uD0A4 \uAE38\uC774=${apiKey.length}, \uC2DC\uC791=${apiKey.substring(0, 10)}...`);
  const url = `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${apiKey}`;
  return await fetch(url, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      contents: [{
        parts: [
          { text: prompt },
          { inline_data: { mime_type: "image/png", data: image } }
        ]
      }],
      generationConfig: { temperature: 0.1, maxOutputTokens: 1e3 }
    })
  });
}
__name(callGeminiAPI, "callGeminiAPI");
async function verifyBusinessRegistrationImage(image, env) {
  if (!env.GEMINI_API_KEY || env.GEMINI_API_KEY.trim() === "") {
    console.error("\u274C GEMINI_API_KEY\uAC00 \uC124\uC815\uB418\uC9C0 \uC54A\uC558\uC2B5\uB2C8\uB2E4.");
    return true;
  }
  const verificationPrompt = `\uC774 \uC774\uBBF8\uC9C0\uAC00 \uD55C\uAD6D\uC758 \uC0AC\uC5C5\uC790\uB4F1\uB85D\uC99D\uC778\uC9C0 \uD655\uC778\uD574\uC8FC\uC138\uC694.

\uB2E4\uC74C\uACFC \uAC19\uC740 \uC694\uC18C\uAC00 \uC788\uB294\uC9C0 \uD655\uC778\uD558\uC138\uC694:
- "\uC0AC\uC5C5\uC790\uB4F1\uB85D\uC99D" \uB610\uB294 "\uC0AC\uC5C5\uC790\uB4F1\uB85D\uC99D\uBA85\uC6D0" \uD14D\uC2A4\uD2B8
- \uC0AC\uC5C5\uC790\uB4F1\uB85D\uBC88\uD638 (000-00-00000 \uD615\uC2DD \uB610\uB294 10\uC790\uB9AC \uC22B\uC790)
- \uC0C1\uD638\uBA85, \uB300\uD45C\uC790\uBA85, \uC0AC\uC5C5\uC7A5\uC18C\uC7AC\uC9C0 \uB4F1\uC758 \uC815\uBCF4
- \uC815\uBD80 \uAE30\uAD00 \uC778\uC99D \uB9C8\uD06C\uB098 \uB3C4\uC7A5
- \uAD6D\uC138\uCCAD \uB610\uB294 \uC138\uBB34\uC11C \uAD00\uB828 \uD45C\uC2DC

\uB2E4\uC74C\uACFC \uAC19\uC740 \uACBD\uC6B0\uC5D0\uB3C4 \uC0AC\uC5C5\uC790\uB4F1\uB85D\uC99D\uC73C\uB85C \uC778\uC815\uD569\uB2C8\uB2E4:
- \uC2A4\uCE94\uBCF8, \uC0AC\uC9C4, PDF \uB4F1 \uB2E4\uC591\uD55C \uD615\uC2DD
- \uC77C\uBD80\uAC00 \uAC00\uB824\uC9C0\uAC70\uB098 \uD750\uB9BF\uD55C \uACBD\uC6B0
- \uC0AC\uC5C5\uC790\uB4F1\uB85D\uC99D\uBA85\uC6D0(\uC778\uC1C4\uBCF8)\uB3C4 \uD3EC\uD568
- \uC624\uB798\uB41C \uD615\uC2DD\uC758 \uC0AC\uC5C5\uC790\uB4F1\uB85D\uC99D\uB3C4 \uD3EC\uD568

\uC751\uB2F5\uC740 \uB2E4\uC74C \uD615\uC2DD\uC758 JSON\uB9CC \uBC18\uD658\uD574\uC8FC\uC138\uC694:
{
  "is_business_registration": true \uB610\uB294 false,
  "confidence": "high" \uB610\uB294 "medium" \uB610\uB294 "low",
  "reason": "\uD655\uC778 \uC774\uC720"
}

\uC0AC\uC5C5\uC790\uB4F1\uB85D\uC99D\uC774 \uD655\uC2E4\uD55C \uACBD\uC6B0 "is_business_registration": true\uB85C \uC124\uC815\uD558\uACE0, 
\uC758\uC2EC\uC2A4\uB7EC\uC6B4 \uACBD\uC6B0\uC5D0\uB3C4 \uAC00\uB2A5\uC131\uC774 \uC788\uC73C\uBA74 true\uB85C \uC124\uC815\uD574\uC8FC\uC138\uC694. 
\uBA85\uD655\uD788 \uB2E4\uB978 \uBB38\uC11C(\uC2E0\uBD84\uC99D, \uACC4\uC57D\uC11C \uB4F1)\uC778 \uACBD\uC6B0\uC5D0\uB9CC false\uB85C \uC124\uC815\uD574\uC8FC\uC138\uC694.`;
  try {
    const geminiResponse = await callGeminiAPI(env.GEMINI_API_KEY, "gemini-2.5-flash", image, verificationPrompt);
    if (!geminiResponse.ok) {
      console.error("\u274C Gemini API \uD638\uCD9C \uC2E4\uD328:", geminiResponse.status);
      return true;
    }
    const geminiData = await geminiResponse.json();
    const extractedText = geminiData.candidates?.[0]?.content?.parts?.[0]?.text;
    if (!extractedText) {
      console.warn("\u26A0\uFE0F \uC751\uB2F5 \uD14D\uC2A4\uD2B8 \uC5C6\uC74C, \uD5C8\uC6A9\uC73C\uB85C \uCC98\uB9AC");
      return true;
    }
    try {
      const jsonMatch = extractedText.match(/```json\s*([\s\S]*?)\s*```/) || extractedText.match(/```\s*([\s\S]*?)\s*```/) || [null, extractedText];
      const result = JSON.parse(jsonMatch[1] || extractedText);
      const isBusinessRegistration = result.is_business_registration === true;
      const confidence = result.confidence || "low";
      console.log("\u{1F4CB} \uC774\uBBF8\uC9C0 \uAC80\uC99D \uACB0\uACFC:", {
        isBusinessRegistration,
        confidence,
        reason: result.reason
      });
      if (isBusinessRegistration) {
        return true;
      }
      if (extractedText.toLowerCase().includes("\uC0AC\uC5C5\uC790\uB4F1\uB85D\uC99D") || extractedText.toLowerCase().includes("business registration") || extractedText.toLowerCase().includes("\uC0AC\uC5C5\uC790\uB4F1\uB85D\uBC88\uD638")) {
        console.log("\u2705 \uD0A4\uC6CC\uB4DC \uD655\uC778\uC73C\uB85C \uC0AC\uC5C5\uC790\uB4F1\uB85D\uC99D\uC73C\uB85C \uC778\uC815");
        return true;
      }
      return false;
    } catch (parseError) {
      console.error("\u274C JSON \uD30C\uC2F1 \uC2E4\uD328, \uD14D\uC2A4\uD2B8 \uD655\uC778:", parseError);
      const lowerText = extractedText.toLowerCase();
      if (lowerText.includes("\uC0AC\uC5C5\uC790\uB4F1\uB85D\uC99D") || lowerText.includes("business registration") || lowerText.includes("\uC0AC\uC5C5\uC790\uB4F1\uB85D\uBC88\uD638") || lowerText.includes("\uC0AC\uC5C5\uC790") || lowerText.includes("\uB4F1\uB85D\uBC88\uD638")) {
        console.log("\u2705 \uD0A4\uC6CC\uB4DC \uD655\uC778\uC73C\uB85C \uC0AC\uC5C5\uC790\uB4F1\uB85D\uC99D\uC73C\uB85C \uC778\uC815");
        return true;
      }
      console.warn("\u26A0\uFE0F \uD30C\uC2F1 \uC2E4\uD328, \uD5C8\uC6A9\uC73C\uB85C \uCC98\uB9AC");
      return true;
    }
  } catch (error) {
    console.error("\u274C \uC774\uBBF8\uC9C0 \uAC80\uC99D \uC911 \uC624\uB958:", error);
    console.warn("\u26A0\uFE0F \uC5D0\uB7EC \uBC1C\uC0DD, \uD5C8\uC6A9\uC73C\uB85C \uCC98\uB9AC");
    return true;
  }
}
__name(verifyBusinessRegistrationImage, "verifyBusinessRegistrationImage");
async function extractBusinessInfo(image, env) {
  const extractionPrompt = `\uC774 \uD55C\uAD6D \uC0AC\uC5C5\uC790\uB4F1\uB85D\uC99D \uC774\uBBF8\uC9C0\uB97C \uBD84\uC11D\uD558\uC5EC \uB2E4\uC74C \uC815\uBCF4\uB97C JSON \uD615\uD0DC\uB85C \uCD94\uCD9C\uD574\uC8FC\uC138\uC694: business_name, business_number, representative_name, business_address, business_type, business_item`;
  if (!env.GEMINI_API_KEY || env.GEMINI_API_KEY.trim() === "") {
    throw new Error("GEMINI_API_KEY \uD658\uACBD \uBCC0\uC218\uAC00 \uC124\uC815\uB418\uC9C0 \uC54A\uC558\uC2B5\uB2C8\uB2E4. Workers secrets\uC5D0 GEMINI_API_KEY\uB97C \uC124\uC815\uD574\uC8FC\uC138\uC694.");
  }
  const models = ["gemini-2.5-flash-lite", "gemini-2.5-flash"];
  const errors = [];
  for (let i = 0; i < models.length; i++) {
    const model = models[i];
    try {
      console.log(`\u{1F504} ${model} \uBAA8\uB378\uB85C AI \uCD94\uCD9C \uC2DC\uB3C4 \uC911...`);
      const geminiResponse = await callGeminiAPI(env.GEMINI_API_KEY, model, image, extractionPrompt);
      if (!geminiResponse.ok) {
        const errorText = await geminiResponse.text();
        let errorMsg = `${model} API \uD638\uCD9C \uC2E4\uD328 (${geminiResponse.status}): ${errorText}`;
        if (geminiResponse.status === 403) {
          const errorJson = JSON.parse(errorText);
          if (errorJson.error?.message?.includes("unregistered callers")) {
            errorMsg = `${model} API \uD0A4 \uC778\uC99D \uC2E4\uD328 (403): API \uD0A4\uAC00 \uC720\uD6A8\uD558\uC9C0 \uC54A\uAC70\uB098 \uC124\uC815\uB418\uC9C0 \uC54A\uC558\uC2B5\uB2C8\uB2E4. Workers secrets\uC5D0\uC11C GEMINI_API_KEY\uB97C \uD655\uC778\uD574\uC8FC\uC138\uC694.`;
          }
        }
        console.error(`\u274C ${errorMsg}`);
        errors.push(errorMsg);
        if (i === models.length - 1) {
          throw new Error(`\uBAA8\uB4E0 \uBAA8\uB378 \uC2E4\uD328. \uB9C8\uC9C0\uB9C9 \uC5D0\uB7EC: ${errorMsg}`);
        }
        continue;
      }
      const geminiData = await geminiResponse.json();
      const extractedText = geminiData.candidates?.[0]?.content?.parts?.[0]?.text;
      if (!extractedText) {
        const errorMsg = `${model}: \uC751\uB2F5 \uD14D\uC2A4\uD2B8 \uC5C6\uC74C`;
        console.error(`\u274C ${errorMsg}`);
        errors.push(errorMsg);
        if (i === models.length - 1) {
          throw new Error(`\uBAA8\uB4E0 \uBAA8\uB378 \uC2E4\uD328. \uB9C8\uC9C0\uB9C9 \uC5D0\uB7EC: ${errorMsg}`);
        }
        continue;
      }
      console.log(`\u2705 ${model} \uC751\uB2F5 \uD14D\uC2A4\uD2B8 \uAE38\uC774: ${extractedText.length}\uC790`);
      try {
        const jsonMatch = extractedText.match(/```json\s*([\s\S]*?)\s*```/) || extractedText.match(/```\s*([\s\S]*?)\s*```/) || [null, extractedText];
        const jsonText = jsonMatch[1] || extractedText;
        const result = JSON.parse(jsonText);
        console.log(`\u2705 ${model} \uCD94\uCD9C \uC131\uACF5:`, result);
        if (!result.business_number) {
          console.warn(`\u26A0\uFE0F ${model}: \uC0AC\uC5C5\uC790\uB4F1\uB85D\uBC88\uD638\uAC00 \uCD94\uCD9C\uB418\uC9C0 \uC54A\uC74C. \uCD94\uCD9C\uB41C \uB370\uC774\uD130:`, result);
        }
        return result;
      } catch (parseError) {
        const errorMsg = `${model} JSON \uD30C\uC2F1 \uC2E4\uD328: ${parseError instanceof Error ? parseError.message : String(parseError)}. \uC751\uB2F5 \uD14D\uC2A4\uD2B8: ${extractedText.substring(0, 200)}...`;
        console.error(`\u274C ${errorMsg}`);
        errors.push(errorMsg);
        try {
          const patterns = {
            business_name: /상호[:\s]*([^\n\r]+)/i,
            business_number: /등록번호[:\s]*([0-9-]+)/i,
            representative_name: /성명[:\s]*([^\n\r]+)/i,
            business_address: /사업장소재지[:\s]*([^\n\r]+)/i,
            business_type: /업태[:\s]*([^\n\r]+)/i,
            business_item: /종목[:\s]*([^\n\r]+)/i
          };
          const fallbackData = {};
          for (const [key, pattern] of Object.entries(patterns)) {
            const match = extractedText.match(pattern);
            if (match && match[1]) {
              fallbackData[key] = match[1].trim();
            }
          }
          if (fallbackData.business_number) {
            console.log(`\u2705 ${model} \uD14D\uC2A4\uD2B8 \uD328\uD134\uC73C\uB85C \uCD94\uCD9C \uC131\uACF5:`, fallbackData);
            return fallbackData;
          }
        } catch (fallbackError) {
          console.error(`\u274C ${model} \uD14D\uC2A4\uD2B8 \uD328\uD134 \uCD94\uCD9C\uB3C4 \uC2E4\uD328:`, fallbackError);
        }
        if (i === models.length - 1) {
          throw new Error(`\uBAA8\uB4E0 \uBAA8\uB378 \uC2E4\uD328. JSON \uD30C\uC2F1 \uC2E4\uD328. \uC5D0\uB7EC\uB4E4: ${errors.join("; ")}`);
        }
        continue;
      }
    } catch (error) {
      const errorMsg = `${model} \uBAA8\uB378 \uCC98\uB9AC \uC911 \uC608\uC678 \uBC1C\uC0DD: ${error instanceof Error ? error.message : String(error)}`;
      console.error(`\u274C ${errorMsg}`);
      errors.push(errorMsg);
      if (i === models.length - 1) {
        throw new Error(`AI \uCD94\uCD9C \uC2E4\uD328. \uBAA8\uB4E0 \uBAA8\uB378 \uC2DC\uB3C4 \uC2E4\uD328. \uC5D0\uB7EC\uB4E4: ${errors.join("; ")}`);
      }
      continue;
    }
  }
  throw new Error(`AI \uCD94\uCD9C \uC2E4\uD328. \uC54C \uC218 \uC5C6\uB294 \uC624\uB958. \uC5D0\uB7EC\uB4E4: ${errors.join("; ")}`);
}
__name(extractBusinessInfo, "extractBusinessInfo");
function validateChecksum(businessNumber) {
  const cleanNumber = businessNumber.replaceAll("-", "");
  if (cleanNumber.length !== 10) return false;
  const weights = [1, 3, 7, 1, 3, 7, 1, 3, 5];
  let sum = 0;
  for (let i = 0; i < 9; i++) {
    sum += parseInt(cleanNumber[i]) * weights[i];
  }
  sum += Math.floor(parseInt(cleanNumber[8]) * 5 / 10);
  const remainder = sum % 10;
  const checkDigit = remainder === 0 ? 0 : 10 - remainder;
  return checkDigit === parseInt(cleanNumber[9]);
}
__name(validateChecksum, "validateChecksum");
async function validateBusinessNumber(businessNumber, env) {
  const cleanNumber = businessNumber.replaceAll("-", "");
  if (!/^\d{10}$/.test(cleanNumber) || !validateChecksum(cleanNumber)) {
    return { isValid: false, errorMessage: "\uC0AC\uC5C5\uC790\uB4F1\uB85D\uBC88\uD638 \uD615\uC2DD\uC774 \uC62C\uBC14\uB974\uC9C0 \uC54A\uC2B5\uB2C8\uB2E4." };
  }
  const response = await fetch(
    `https://api.odcloud.kr/api/nts-businessman/v1/status?serviceKey=${env.NTS_API_KEY}`,
    {
      method: "POST",
      headers: { "Content-Type": "application/json", "Accept": "application/json" },
      body: JSON.stringify({ b_no: [cleanNumber] })
    }
  );
  if (!response.ok) {
    const errorText = await response.text();
    console.error("\u274C \uAD6D\uC138\uCCAD API \uC5D0\uB7EC \uC751\uB2F5:", {
      status: response.status,
      statusText: response.statusText,
      body: errorText,
      businessNumber: cleanNumber
    });
    throw new Error(`\uAD6D\uC138\uCCAD API \uD638\uCD9C \uC2E4\uD328: ${response.status} - ${errorText}`);
  }
  const jsonData = await response.json();
  const statusCode = jsonData.status_code || "";
  const data = jsonData.data || [];
  if (statusCode === "OK" && data.length > 0) {
    const businessInfo = data[0];
    return {
      isValid: businessInfo.b_stt_cd === "01",
      businessStatus: businessInfo.b_stt || "",
      businessStatusCode: businessInfo.b_stt_cd,
      taxType: businessInfo.tax_type || ""
    };
  }
  return { isValid: false, errorMessage: "\uC0AC\uC5C5\uC790 \uC815\uBCF4\uB97C \uCC3E\uC744 \uC218 \uC5C6\uC2B5\uB2C8\uB2E4." };
}
__name(validateBusinessNumber, "validateBusinessNumber");
function generateFilePath(userId, fileName) {
  const now = /* @__PURE__ */ new Date();
  const year = now.getFullYear();
  const month = String(now.getMonth() + 1).padStart(2, "0");
  const day = String(now.getDate()).padStart(2, "0");
  const timestamp = now.getTime();
  const extension = fileName.substring(fileName.lastIndexOf("."));
  return `business-registration/${year}/${month}/${day}/${userId}_${timestamp}${extension}`;
}
__name(generateFilePath, "generateFilePath");
async function handleDeleteFile(request, env) {
  try {
    const requestData = await request.json();
    const { fileUrl } = requestData;
    if (!fileUrl) {
      return new Response(
        JSON.stringify({ success: false, error: "fileUrl\uC774 \uD544\uC694\uD569\uB2C8\uB2E4." }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }
    const urlObj = new URL(fileUrl);
    const filePath = urlObj.pathname.substring(1);
    if (!filePath.startsWith("business-registration/")) {
      return new Response(
        JSON.stringify({ success: false, error: "\uC720\uD6A8\uD558\uC9C0 \uC54A\uC740 \uD30C\uC77C \uACBD\uB85C\uC785\uB2C8\uB2E4." }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }
    await env.FILES.delete(filePath);
    return new Response(
      JSON.stringify({ success: true, message: "\uD30C\uC77C\uC774 \uC0AD\uC81C\uB418\uC5C8\uC2B5\uB2C8\uB2E4." }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (error) {
    console.error("\u274C \uD30C\uC77C \uC0AD\uC81C \uC2E4\uD328:", error);
    return new Response(
      JSON.stringify({
        success: false,
        error: error instanceof Error ? error.message : "\uD30C\uC77C \uC0AD\uC81C \uC2E4\uD328"
      }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
}
__name(handleDeleteFile, "handleDeleteFile");

// node_modules/wrangler/templates/middleware/middleware-ensure-req-body-drained.ts
var drainBody = /* @__PURE__ */ __name(async (request, env, _ctx, middlewareCtx) => {
  try {
    return await middlewareCtx.next(request, env);
  } finally {
    try {
      if (request.body !== null && !request.bodyUsed) {
        const reader = request.body.getReader();
        while (!(await reader.read()).done) {
        }
      }
    } catch (e) {
      console.error("Failed to drain the unused request body.", e);
    }
  }
}, "drainBody");
var middleware_ensure_req_body_drained_default = drainBody;

// node_modules/wrangler/templates/middleware/middleware-miniflare3-json-error.ts
function reduceError(e) {
  return {
    name: e?.name,
    message: e?.message ?? String(e),
    stack: e?.stack,
    cause: e?.cause === void 0 ? void 0 : reduceError(e.cause)
  };
}
__name(reduceError, "reduceError");
var jsonError = /* @__PURE__ */ __name(async (request, env, _ctx, middlewareCtx) => {
  try {
    return await middlewareCtx.next(request, env);
  } catch (e) {
    const error = reduceError(e);
    return Response.json(error, {
      status: 500,
      headers: { "MF-Experimental-Error-Stack": "true" }
    });
  }
}, "jsonError");
var middleware_miniflare3_json_error_default = jsonError;

// .wrangler/tmp/bundle-xuGCdD/middleware-insertion-facade.js
var __INTERNAL_WRANGLER_MIDDLEWARE__ = [
  middleware_ensure_req_body_drained_default,
  middleware_miniflare3_json_error_default
];
var middleware_insertion_facade_default = workers_default;

// node_modules/wrangler/templates/middleware/common.ts
var __facade_middleware__ = [];
function __facade_register__(...args) {
  __facade_middleware__.push(...args.flat());
}
__name(__facade_register__, "__facade_register__");
function __facade_invokeChain__(request, env, ctx, dispatch, middlewareChain) {
  const [head, ...tail] = middlewareChain;
  const middlewareCtx = {
    dispatch,
    next(newRequest, newEnv) {
      return __facade_invokeChain__(newRequest, newEnv, ctx, dispatch, tail);
    }
  };
  return head(request, env, ctx, middlewareCtx);
}
__name(__facade_invokeChain__, "__facade_invokeChain__");
function __facade_invoke__(request, env, ctx, dispatch, finalMiddleware) {
  return __facade_invokeChain__(request, env, ctx, dispatch, [
    ...__facade_middleware__,
    finalMiddleware
  ]);
}
__name(__facade_invoke__, "__facade_invoke__");

// .wrangler/tmp/bundle-xuGCdD/middleware-loader.entry.ts
var __Facade_ScheduledController__ = class ___Facade_ScheduledController__ {
  constructor(scheduledTime, cron, noRetry) {
    this.scheduledTime = scheduledTime;
    this.cron = cron;
    this.#noRetry = noRetry;
  }
  static {
    __name(this, "__Facade_ScheduledController__");
  }
  #noRetry;
  noRetry() {
    if (!(this instanceof ___Facade_ScheduledController__)) {
      throw new TypeError("Illegal invocation");
    }
    this.#noRetry();
  }
};
function wrapExportedHandler(worker) {
  if (__INTERNAL_WRANGLER_MIDDLEWARE__ === void 0 || __INTERNAL_WRANGLER_MIDDLEWARE__.length === 0) {
    return worker;
  }
  for (const middleware of __INTERNAL_WRANGLER_MIDDLEWARE__) {
    __facade_register__(middleware);
  }
  const fetchDispatcher = /* @__PURE__ */ __name(function(request, env, ctx) {
    if (worker.fetch === void 0) {
      throw new Error("Handler does not export a fetch() function.");
    }
    return worker.fetch(request, env, ctx);
  }, "fetchDispatcher");
  return {
    ...worker,
    fetch(request, env, ctx) {
      const dispatcher = /* @__PURE__ */ __name(function(type, init) {
        if (type === "scheduled" && worker.scheduled !== void 0) {
          const controller = new __Facade_ScheduledController__(
            Date.now(),
            init.cron ?? "",
            () => {
            }
          );
          return worker.scheduled(controller, env, ctx);
        }
      }, "dispatcher");
      return __facade_invoke__(request, env, ctx, dispatcher, fetchDispatcher);
    }
  };
}
__name(wrapExportedHandler, "wrapExportedHandler");
function wrapWorkerEntrypoint(klass) {
  if (__INTERNAL_WRANGLER_MIDDLEWARE__ === void 0 || __INTERNAL_WRANGLER_MIDDLEWARE__.length === 0) {
    return klass;
  }
  for (const middleware of __INTERNAL_WRANGLER_MIDDLEWARE__) {
    __facade_register__(middleware);
  }
  return class extends klass {
    #fetchDispatcher = /* @__PURE__ */ __name((request, env, ctx) => {
      this.env = env;
      this.ctx = ctx;
      if (super.fetch === void 0) {
        throw new Error("Entrypoint class does not define a fetch() function.");
      }
      return super.fetch(request);
    }, "#fetchDispatcher");
    #dispatcher = /* @__PURE__ */ __name((type, init) => {
      if (type === "scheduled" && super.scheduled !== void 0) {
        const controller = new __Facade_ScheduledController__(
          Date.now(),
          init.cron ?? "",
          () => {
          }
        );
        return super.scheduled(controller);
      }
    }, "#dispatcher");
    fetch(request) {
      return __facade_invoke__(
        request,
        this.env,
        this.ctx,
        this.#dispatcher,
        this.#fetchDispatcher
      );
    }
  };
}
__name(wrapWorkerEntrypoint, "wrapWorkerEntrypoint");
var WRAPPED_ENTRY;
if (typeof middleware_insertion_facade_default === "object") {
  WRAPPED_ENTRY = wrapExportedHandler(middleware_insertion_facade_default);
} else if (typeof middleware_insertion_facade_default === "function") {
  WRAPPED_ENTRY = wrapWorkerEntrypoint(middleware_insertion_facade_default);
}
var middleware_loader_entry_default = WRAPPED_ENTRY;
export {
  __INTERNAL_WRANGLER_MIDDLEWARE__,
  middleware_loader_entry_default as default
};
//# sourceMappingURL=index.js.map
