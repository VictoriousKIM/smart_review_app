// 날짜/시간 관련 유틸리티 함수들

// UTC 시간을 한국 시간(KST, UTC+9)으로 변환
export function toKST(date: Date): Date {
  const kstOffset = 9 * 60 * 60 * 1000; // 9시간을 밀리초로 변환
  return new Date(date.getTime() + kstOffset);
}

export function formatTimestamp(date: Date): string {
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
export function formatTimestampWithMillis(date: Date): string {
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
export function sanitizeFileName(name: string): string {
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

export function generateFilePath(userId: string, fileName: string, companyName?: string): string {
  const now = new Date();
  const timestamp = formatTimestampWithMillis(now);
  const extension = fileName.substring(fileName.lastIndexOf('.'));
  // UUID 생성 (한글/특수문자 문제 해결을 위해 UUID 사용)
  const fileUuid = crypto.randomUUID();
  
  // 사업자등록증: business-registration/{timestamp}_{uuid}.png
  return `business-registration/${timestamp}_${fileUuid}${extension}`;
}

