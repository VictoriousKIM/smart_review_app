// 사업자등록증 관련 유틸리티 함수들

export interface Env {
  GEMINI_API_KEY: string;
  NTS_API_KEY: string;
}

// Gemini 모델 목록 (fallback 순서대로)
const GEMINI_MODELS = ['gemini-2.5-flash-lite', 'gemini-2.5-flash'] as const;

// Gemini API 호출 헬퍼
export async function callGeminiAPI(apiKey: string, model: string, image: string, prompt: string): Promise<Response> {
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

// 사업자등록증 이미지 검증
export async function verifyBusinessRegistrationImage(image: string, env: Env): Promise<boolean> {
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
  const models = GEMINI_MODELS;
  
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

// 사업자 정보 추출
export async function extractBusinessInfo(image: string, env: Env): Promise<any> {
  const extractionPrompt = `이 한국 사업자등록증 이미지를 분석하여 다음 정보를 JSON 형태로 추출해주세요: business_name, business_number, representative_name, business_address, business_type, business_item`;

  // API 키 검증
  if (!env.GEMINI_API_KEY || env.GEMINI_API_KEY.trim() === '') {
    throw new Error('GEMINI_API_KEY 환경 변수가 설정되지 않았습니다. Workers secrets에 GEMINI_API_KEY를 설정해주세요.');
  }

  const models = GEMINI_MODELS;
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
          try {
            const errorJson = JSON.parse(errorText);
            if (errorJson.error?.message?.includes('unregistered callers')) {
              errorMsg = `${model} API 키 인증 실패 (403): API 키가 유효하지 않거나 설정되지 않았습니다. Workers secrets에서 GEMINI_API_KEY를 확인해주세요.`;
            }
          } catch (e) {
            // JSON 파싱 실패 시 원본 메시지 사용
          }
        }
        
        // 429 에러인 경우 (Quota 초과) 특별 처리
        if (geminiResponse.status === 429) {
          try {
            const errorJson = JSON.parse(errorText);
            const quotaMessage = errorJson.error?.message || '';
            if (quotaMessage.includes('quota') || quotaMessage.includes('Quota')) {
              errorMsg = `${model} API 호출 실패 (429): 무료 티어 한도 초과. 하루 20회 제한을 초과했습니다. 잠시 후 다시 시도하거나 유료 플랜으로 업그레이드하세요.`;
            }
          } catch (e) {
            // JSON 파싱 실패 시 원본 메시지 사용
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
        // 마크다운 코드 블록 제거 (더 강력한 전처리)
        let jsonText = extractedText.trim();
        
        // ```json ... ``` 형식 제거
        if (jsonText.startsWith('```')) {
          jsonText = jsonText.replace(/^```json\s*/i, '').replace(/^```\s*/, '');
          jsonText = jsonText.replace(/\s*```\s*$/, '');
        }
        
        // 정규식으로 JSON 객체 추출 (중괄호로 시작하고 끝나는 부분)
        const jsonMatch = jsonText.match(/\{[\s\S]*\}/);
        if (jsonMatch && jsonMatch[0]) {
          jsonText = jsonMatch[0];
        }
        
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

// 사업자등록번호 체크섬 검증
export function validateChecksum(businessNumber: string): boolean {
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

// 사업자등록번호 검증 (국세청 API)
export async function validateBusinessNumber(businessNumber: string, env: Env): Promise<any> {
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

