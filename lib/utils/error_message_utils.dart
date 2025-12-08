/// 에러 메시지를 유저 친화적인 메시지로 변환하는 유틸리티
class ErrorMessageUtils {
  /// 에러 메시지를 유저 친화적인 메시지로 변환
  static String getUserFriendlyMessage(dynamic error) {
    if (error == null) {
      return '알 수 없는 오류가 발생했습니다. 잠시 후 다시 시도해주세요.';
    }

    final errorString = error.toString().toLowerCase();

    // 네트워크 관련 에러
    if (errorString.contains('socketexception') ||
        errorString.contains('timeout') ||
        errorString.contains('connection') ||
        errorString.contains('network') ||
        errorString.contains('failed host lookup')) {
      return '네트워크 연결에 문제가 있습니다. 인터넷 연결을 확인하고 다시 시도해주세요.';
    }

    // 로그인 관련 에러
    if (errorString.contains('로그인이 필요') ||
        errorString.contains('login') ||
        errorString.contains('unauthorized') ||
        errorString.contains('인증')) {
      return '로그인이 필요합니다. 다시 로그인해주세요.';
    }

    // DB 저장 관련 에러
    if (errorString.contains('db 저장') ||
        errorString.contains('database') ||
        errorString.contains('중복') ||
        errorString.contains('duplicate') ||
        errorString.contains('unique constraint')) {
      if (errorString.contains('사업자등록번호') ||
          errorString.contains('사업자번호') ||
          errorString.contains('business')) {
        return '이미 등록된 사업자등록번호입니다.';
      }
      if (errorString.contains('계정') || errorString.contains('account')) {
        return '이미 등록된 계정입니다.';
      }
      return '이미 등록된 정보입니다.';
    }

    // 파일 업로드 관련 에러
    if (errorString.contains('파일 업로드') ||
        errorString.contains('upload') ||
        errorString.contains('파일 선택') ||
        errorString.contains('file')) {
      return '파일 업로드에 실패했습니다. 다시 시도해주세요.';
    }

    // AI 추출 관련 에러
    if (errorString.contains('ai 추출') ||
        errorString.contains('extraction') ||
        errorString.contains('추출')) {
      return '사업자등록증 정보를 읽을 수 없습니다. 이미지가 선명한지 확인하고 다시 시도해주세요.';
    }

    // 검증 관련 에러
    if (errorString.contains('검증') ||
        errorString.contains('validation') ||
        errorString.contains('유효하지')) {
      return '입력한 정보가 유효하지 않습니다. 다시 확인해주세요.';
    }

    // 이미지 검증 관련 에러
    if (errorString.contains('이미지 검증') ||
        errorString.contains('image_verification') ||
        errorString.contains('사업자등록증이 아닙니다')) {
      return '업로드된 이미지가 사업자등록증이 아닙니다. 사업자등록증 이미지를 업로드해주세요.';
    }

    // 권한 관련 에러
    if (errorString.contains('권한') ||
        errorString.contains('permission') ||
        errorString.contains('forbidden') ||
        errorString.contains('access denied')) {
      return '권한이 없습니다. 관리자에게 문의해주세요.';
    }

    // 회원가입 관련 에러
    if (errorString.contains('회원가입') ||
        errorString.contains('signup') ||
        errorString.contains('sign up')) {
      return '회원가입에 실패했습니다. 입력한 정보를 확인하고 다시 시도해주세요.';
    }

    // 프로필 관련 에러
    if (errorString.contains('프로필') ||
        errorString.contains('profile')) {
      if (errorString.contains('로드') || errorString.contains('load')) {
        return '프로필 정보를 불러올 수 없습니다. 잠시 후 다시 시도해주세요.';
      }
      if (errorString.contains('저장') || errorString.contains('save')) {
        return '프로필 저장에 실패했습니다. 다시 시도해주세요.';
      }
    }

    // 포인트/지갑 관련 에러
    if (errorString.contains('포인트') ||
        errorString.contains('지갑') ||
        errorString.contains('wallet') ||
        errorString.contains('point')) {
      if (errorString.contains('불러') || errorString.contains('load')) {
        return '포인트 정보를 불러올 수 없습니다. 잠시 후 다시 시도해주세요.';
      }
      if (errorString.contains('충전') || errorString.contains('charge')) {
        return '포인트 충전에 실패했습니다. 다시 시도해주세요.';
      }
      if (errorString.contains('출금') || errorString.contains('withdraw')) {
        return '출금 신청에 실패했습니다. 다시 시도해주세요.';
      }
    }

    // 거래 관련 에러
    if (errorString.contains('거래') ||
        errorString.contains('transaction')) {
      if (errorString.contains('불러') || errorString.contains('load')) {
        return '거래 내역을 불러올 수 없습니다. 잠시 후 다시 시도해주세요.';
      }
    }

    // 계좌 관련 에러
    if (errorString.contains('계좌') ||
        errorString.contains('account') ||
        errorString.contains('은행')) {
      if (errorString.contains('저장') || errorString.contains('save')) {
        return '계좌 정보 저장에 실패했습니다. 다시 시도해주세요.';
      }
    }

    // 승인/거절 관련 에러
    if (errorString.contains('승인') || errorString.contains('approve')) {
      return '승인 처리에 실패했습니다. 다시 시도해주세요.';
    }
    if (errorString.contains('거절') || errorString.contains('reject')) {
      return '거절 처리에 실패했습니다. 다시 시도해주세요.';
    }

    // 활성화/비활성화 관련 에러
    if (errorString.contains('활성화') || errorString.contains('activate')) {
      return '활성화 처리에 실패했습니다. 다시 시도해주세요.';
    }
    if (errorString.contains('비활성화') ||
        errorString.contains('deactivate')) {
      return '비활성화 처리에 실패했습니다. 다시 시도해주세요.';
    }

    // 제거 관련 에러
    if (errorString.contains('제거') ||
        errorString.contains('remove') ||
        errorString.contains('delete')) {
      return '삭제에 실패했습니다. 다시 시도해주세요.';
    }

    // 목록 조회 관련 에러
    if (errorString.contains('목록') ||
        errorString.contains('불러') ||
        errorString.contains('load') ||
        errorString.contains('list')) {
      if (errorString.contains('회사')) {
        return '회사 목록을 불러올 수 없습니다. 잠시 후 다시 시도해주세요.';
      }
      if (errorString.contains('캠페인')) {
        return '캠페인 목록을 불러올 수 없습니다. 잠시 후 다시 시도해주세요.';
      }
      if (errorString.contains('리뷰')) {
        return '리뷰 목록을 불러올 수 없습니다. 잠시 후 다시 시도해주세요.';
      }
      if (errorString.contains('사용자') || errorString.contains('user')) {
        return '사용자 목록을 불러올 수 없습니다. 잠시 후 다시 시도해주세요.';
      }
      if (errorString.contains('통계') || errorString.contains('statistics')) {
        return '통계를 불러올 수 없습니다. 잠시 후 다시 시도해주세요.';
      }
      return '정보를 불러올 수 없습니다. 잠시 후 다시 시도해주세요.';
    }

    // 상태 변경 관련 에러
    if (errorString.contains('상태 변경') ||
        errorString.contains('status')) {
      return '상태 변경에 실패했습니다. 다시 시도해주세요.';
    }

    // 권한 변경 관련 에러
    if (errorString.contains('권한 변경') ||
        errorString.contains('role')) {
      return '권한 변경에 실패했습니다. 다시 시도해주세요.';
    }

    // 요청 취소 관련 에러
    if (errorString.contains('요청 취소') ||
        errorString.contains('cancel')) {
      return '요청 취소에 실패했습니다. 다시 시도해주세요.';
    }

    // 신청 관련 에러
    if (errorString.contains('신청') ||
        errorString.contains('apply') ||
        errorString.contains('application')) {
      if (errorString.contains('실패') || errorString.contains('fail')) {
        return '신청 처리에 실패했습니다. 다시 시도해주세요.';
      }
    }

    // PostgrestException 처리
    if (errorString.contains('postgresterror') ||
        errorString.contains('postgrestexception')) {
      // "message: 이미 등록된 계정입니다" 형식에서 메시지 추출
      final messageMatch = RegExp(r'message:\s*([^,]+)').firstMatch(error.toString());
      if (messageMatch != null) {
        final extractedMessage = messageMatch.group(1)?.trim();
        if (extractedMessage != null && extractedMessage.isNotEmpty) {
          return extractedMessage;
        }
      }
    }

    // Exception: 메시지 형식 처리
    if (errorString.startsWith('exception: ')) {
      final message = error.toString().substring(11).trim();
      if (message.isNotEmpty) {
        // 이미 유저 친화적인 메시지인 경우 그대로 반환
        if (!message.contains('exception') &&
            !message.contains('error') &&
            !message.toLowerCase().contains('failed')) {
          return message;
        }
      }
    }

    // 기본 에러 메시지
    return '처리 중 오류가 발생했습니다. 잠시 후 다시 시도해주세요.';
  }
}

