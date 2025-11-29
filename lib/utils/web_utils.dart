import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:universal_html/html.dart' as html;

/// 웹 전용 유틸리티 함수
class WebUtils {
  /// 페이지 언로드 시 콜백 등록 (웹에서만 작동)
  /// 
  /// [onUnload]: 페이지 언로드 시 실행할 콜백
  /// 
  /// Returns: 구독 해제 함수 (선택사항)
  static void Function()? setupBeforeUnload(void Function() onUnload) {
    if (!kIsWeb) {
      return null; // 웹이 아니면 아무것도 하지 않음
    }

    html.window.onBeforeUnload.listen((event) {
      onUnload();
    });

    // 구독 해제 함수 반환 (필요한 경우)
    return () {
      // beforeunload 이벤트는 일반적으로 구독 해제가 필요 없지만,
      // 필요시 여기에 추가할 수 있음
    };
  }
}

