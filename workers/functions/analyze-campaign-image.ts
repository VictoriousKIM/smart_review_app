import { Env } from '../index';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type, Authorization, X-Requested-With',
  'Access-Control-Expose-Headers': 'Content-Type, Content-Length',
};

export async function handleAnalyzeCampaignImage(request: Request, env: Env): Promise<Response> {
  // CORS 헤더를 항상 포함하도록 함수 시작 부분에서 정의
  const ensureCorsHeaders = (headers: HeadersInit = {}) => {
    return { ...corsHeaders, ...headers };
  };

  try {
    // Content-Type 검증
    const contentType = request.headers.get('content-type') || '';
    if (!contentType.includes('multipart/form-data')) {
      console.warn('⚠️ Content-Type이 multipart/form-data가 아님:', contentType);
      // multipart/form-data가 아니어도 파싱 시도 (일부 클라이언트가 boundary를 포함하지 않을 수 있음)
    }

    // multipart/form-data 파싱 (에러 처리 강화)
    let formData: FormData;
    try {
      formData = await request.formData();
    } catch (formDataError: any) {
      console.error('❌ formData 파싱 실패:', formDataError);
      return new Response(
        JSON.stringify({
          success: false,
          error: `formData 파싱 실패: ${formDataError.message || '알 수 없는 오류'}`
        }),
        { status: 400, headers: ensureCorsHeaders({ 'Content-Type': 'application/json' }) }
      );
    }

    const imageFile = formData.get('image') as File | null;
    const imageWidthStr = formData.get('imageWidth') as string | null;
    const imageHeightStr = formData.get('imageHeight') as string | null;
    
    if (!imageFile) {
      return new Response(
        JSON.stringify({
          success: false,
          error: '이미지가 제공되지 않았습니다.'
        }),
        { status: 400, headers: ensureCorsHeaders({ 'Content-Type': 'application/json' }) }
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
      { headers: ensureCorsHeaders({ 'Content-Type': 'application/json' }) }
    );
    
  } catch (error: any) {
    console.error('❌ 이미지 분석 실패:', error);
    const errorMessage = error.message || '이미지 분석 중 오류가 발생했습니다.';
    const statusCode = error.status || 500;
    
    return new Response(
      JSON.stringify({
        success: false,
        error: errorMessage
      }),
      { 
        status: statusCode, 
        headers: ensureCorsHeaders({ 'Content-Type': 'application/json' }) 
      }
    );
  }
}
