import { GoogleGenerativeAI } from '@google/generative-ai';

interface Env {
  GEMINI_API_KEY: string;
}

interface CampaignExtractRequest {
  image: string;  // base64 encoded image
}

interface CampaignExtractResponse {
  success: boolean;
  data?: {
    keyword?: string;
    title?: string;
    option?: string;
    quantity?: number;
    seller?: string;
    productNumber?: string;
    paymentAmount?: number;
    purchaseMethod?: string;
    reviewReward?: number;
    productImageCrop?: {
      x: number;
      y: number;
      width: number;
      height: number;
    };
  };
  error?: string;
}

export async function analyzeCampaignImage(
  request: Request,
  env: Env
): Promise<Response> {
  try {
    const { image } = await request.json() as CampaignExtractRequest;
    
    if (!image) {
      return Response.json({
        success: false,
        error: '이미지가 제공되지 않았습니다.'
      }, { status: 400 });
    }
    
    // Gemini API 초기화
    const genAI = new GoogleGenerativeAI(env.GEMINI_API_KEY);
    const model = genAI.getGenerativeModel({ model: "gemini-2.5-flash-lite" });
    
    // 이미지 크기 추정 (base64 데이터 크기로 대략 계산)
    // base64 데이터 크기로 원본 이미지 크기 추정
    const imageDataSize = imageData.length;
    // base64는 원본보다 약 33% 큼
    const estimatedOriginalSize = Math.floor(imageDataSize * 0.75);
    // 일반적인 압축률을 고려하여 실제 픽셀 수 추정
    // 대략적인 계산: 1픽셀 = 3-4바이트 (RGB)
    const estimatedPixels = Math.floor(estimatedOriginalSize / 3.5);
    // 일반적인 모바일 스크린샷 비율 (9:16 또는 3:4)
    const estimatedWidth = Math.floor(Math.sqrt(estimatedPixels * (9/16)));
    const estimatedHeight = Math.floor(estimatedWidth * (16/9));
    
    console.log(`📏 추정 이미지 크기: ${estimatedWidth}x${estimatedHeight}`);
    
    // 프롬프트 작성
    const prompt = `
다음 이미지는 온라인 쇼핑몰 제품 상세 페이지 스크린샷입니다.
이미지의 추정 크기는 약 ${estimatedWidth}x${estimatedHeight} 픽셀입니다.

아래 정보를 추출하여 JSON 형식으로 반환해주세요:

{
  "keyword": "제품 카테고리 또는 키워드 (예: 화장실 선반, 노트북 거치대)",
  "title": "제품명 (브랜드명 포함)",
  "option": "선택된 옵션 (색상, 사이즈 등)",
  "quantity": 구매 개수 (숫자만),
  "seller": "판매자명 또는 브랜드명",
  "productNumber": "상품번호 또는 SKU",
  "paymentAmount": 결제금액 (숫자만, 쉼표 제거),
  "purchaseMethod": "모바일 또는 PC",
  "reviewReward": 리뷰비 또는 적립금 (있다면, 숫자만),
  "productImageCrop": {
    "x": 상품 메인 이미지의 왼쪽 상단 x 좌표 (픽셀, 정수, 필수),
    "y": 상품 메인 이미지의 왼쪽 상단 y 좌표 (픽셀, 정수, 필수),
    "width": 상품 메인 이미지의 너비 (픽셀, 정수, 필수),
    "height": 상품 메인 이미지의 높이 (픽셀, 정수, 필수)
  }
}

중요 규칙:
1. 정보가 명확하지 않거나 없는 필드는 null로 반환 (단, productImageCrop은 예외)
2. 숫자 필드는 반드시 숫자 타입으로 (문자열 X)
3. paymentAmount에서 쉼표, "원", "₩" 등 제거
4. purchaseMethod는 "mobile" 또는 "pc"만 사용
5. productImageCrop은 반드시 제공해야 합니다 (null 금지):
   - 이미지에서 가장 크고 명확한 제품 메인 이미지의 위치를 찾아주세요
   - 보통 왼쪽 절반 또는 중앙에 위치한 큰 제품 이미지입니다
   - 썸네일이나 작은 이미지가 아닌 메인 제품 사진을 찾아주세요
   - 이미지의 전체 크기(${estimatedWidth}x${estimatedHeight})를 기준으로 픽셀 좌표를 계산해주세요
   - 제품 이미지가 왼쪽 절반에 있다면: x=0, y=0, width=${Math.floor(estimatedWidth/2)}, height=${estimatedHeight}
   - 제품 이미지가 중앙에 있다면: x=${Math.floor(estimatedWidth/4)}, y=0, width=${Math.floor(estimatedWidth/2)}, height=${estimatedHeight}
   - 정확한 위치를 찾을 수 없어도 대략적인 위치를 추정해서 반환해주세요
   - productImageCrop은 절대 null이면 안 됩니다
6. JSON만 반환하고 다른 설명은 하지 마세요
7. 마크다운 코드 블록 없이 순수 JSON만 반환

예시:
{
  "keyword": "화장실 선반",
  "title": "브림유 BRIMU 무타공 흡착식 욕실선반",
  "option": "투명실버",
  "quantity": 1,
  "seller": "브림유",
  "productNumber": "8325154393",
  "paymentAmount": 13800,
  "purchaseMethod": "mobile",
  "reviewReward": 1000,
  "productImageCrop": {
    "x": 0,
    "y": 0,
    "width": ${Math.floor(estimatedWidth/2)},
    "height": ${estimatedHeight}
  }
}
`;

    // 이미지 분석
    const imageData = image.includes(',') ? image.split(',')[1] : image;
    const imagePart = {
      inlineData: {
        data: imageData,
        mimeType: image.startsWith('data:image/png') ? "image/png" : 
                  image.startsWith('data:image/jpg') || image.startsWith('data:image/jpeg') ? "image/jpeg" : 
                  "image/png"
      }
    };
    
    const result = await model.generateContent([prompt, imagePart]);
    const response = await result.response;
    const text = response.text();
    
    console.log('Gemini Response:', text);
    
    // JSON 파싱 (마크다운 코드 블록 제거)
    let jsonText = text.trim();
    
    // 마크다운 코드 블록 제거
    if (jsonText.startsWith('```')) {
      jsonText = jsonText.replace(/```json\n?/g, '').replace(/```\n?/g, '');
    }
    
    // JSON 추출
    const jsonMatch = jsonText.match(/\{[\s\S]*\}/);
    if (!jsonMatch) {
      console.error('No JSON found in response:', text);
      throw new Error('응답에서 JSON을 찾을 수 없습니다.');
    }
    
    const extractedData = JSON.parse(jsonMatch[0]);
    
    console.log('Parsed extracted data:', JSON.stringify(extractedData, null, 2));
    
    // 데이터 타입 검증 및 변환
    if (extractedData.quantity && typeof extractedData.quantity === 'string') {
      extractedData.quantity = parseInt(extractedData.quantity);
    }
    if (extractedData.paymentAmount && typeof extractedData.paymentAmount === 'string') {
      extractedData.paymentAmount = parseInt(extractedData.paymentAmount.replace(/[^0-9]/g, ''));
    }
    if (extractedData.reviewReward && typeof extractedData.reviewReward === 'string') {
      extractedData.reviewReward = parseInt(extractedData.reviewReward.replace(/[^0-9]/g, ''));
    }
    
    // purchaseMethod 정규화
    if (extractedData.purchaseMethod) {
      const method = extractedData.purchaseMethod.toLowerCase();
      extractedData.purchaseMethod = method.includes('mobile') || method.includes('모바일') ? 'mobile' : 'pc';
    }
    
    // productImageCrop 처리 및 기본값 설정
    const hasValidCrop = extractedData.productImageCrop && 
                         typeof extractedData.productImageCrop === 'object' &&
                         extractedData.productImageCrop.x !== undefined &&
                         extractedData.productImageCrop.y !== undefined &&
                         extractedData.productImageCrop.width !== undefined &&
                         extractedData.productImageCrop.height !== undefined;
    
    if (!hasValidCrop) {
      console.log('⚠️ productImageCrop이 없거나 유효하지 않음. 기본값 사용');
      console.log('extractedData.productImageCrop:', extractedData.productImageCrop);
      
      // 이미지 크기를 추정하기 위해 base64 이미지 크기로 대략 계산
      // 일반적인 모바일 스크린샷 크기: 1080x1920 또는 750x1334
      // 제품 이미지는 보통 왼쪽 절반에 위치
      const estimatedWidth = 1080; // 일반적인 모바일 화면 너비
      const estimatedHeight = 1920; // 일반적인 모바일 화면 높이
      
      extractedData.productImageCrop = {
        x: 0,
        y: 0,
        width: Math.floor(estimatedWidth / 2), // 왼쪽 절반
        height: estimatedHeight
      };
      
      console.log('✅ 기본 크롭 좌표 설정:', JSON.stringify(extractedData.productImageCrop));
    } else {
      // 크롭 좌표 타입 변환
      extractedData.productImageCrop = {
        x: typeof extractedData.productImageCrop.x === 'string' 
          ? parseInt(extractedData.productImageCrop.x) 
          : Math.floor(extractedData.productImageCrop.x || 0),
        y: typeof extractedData.productImageCrop.y === 'string' 
          ? parseInt(extractedData.productImageCrop.y) 
          : Math.floor(extractedData.productImageCrop.y || 0),
        width: typeof extractedData.productImageCrop.width === 'string' 
          ? parseInt(extractedData.productImageCrop.width) 
          : Math.floor(extractedData.productImageCrop.width || 0),
        height: typeof extractedData.productImageCrop.height === 'string' 
          ? parseInt(extractedData.productImageCrop.height) 
          : Math.floor(extractedData.productImageCrop.height || 0),
      };
      
      console.log('✅ 크롭 좌표 파싱 완료:', JSON.stringify(extractedData.productImageCrop));
    }
    
    // 최종 확인: productImageCrop이 반드시 있어야 함
    if (!extractedData.productImageCrop) {
      console.error('❌ productImageCrop이 여전히 없음! 강제로 기본값 설정');
      extractedData.productImageCrop = {
        x: 0,
        y: 0,
        width: 540,
        height: 1920
      };
    }
    
    console.log('📤 최종 응답 데이터:', JSON.stringify(extractedData, null, 2));
    
    return Response.json({
      success: true,
      data: extractedData
    });
    
  } catch (error: any) {
    console.error('Image analysis error:', error);
    return Response.json({
      success: false,
      error: error.message || '이미지 분석 중 오류가 발생했습니다.'
    }, { status: 500 });
  }
}

