import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';

/// 에러 로깅 레벨
enum LogLevel {
  debug,
  info,
  warning,
  error,
  critical,
}

/// 에러 타입 분류
enum ErrorType {
  network,
  authentication,
  database,
  validation,
  business,
  system,
  unknown,
}

/// 에러 정보를 담는 클래스
class ErrorInfo {
  final String message;
  final ErrorType type;
  final LogLevel level;
  final String? stackTrace;
  final Map<String, dynamic>? context;
  final DateTime timestamp;

  ErrorInfo({
    required this.message,
    required this.type,
    required this.level,
    this.stackTrace,
    this.context,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'message': message,
    'type': type.name,
    'level': level.name,
    'stackTrace': stackTrace,
    'context': context,
    'timestamp': timestamp.toIso8601String(),
  };
}

/// 통합 에러 처리 및 로깅 시스템
class ErrorHandler {
  static final ErrorHandler _instance = ErrorHandler._internal();
  factory ErrorHandler() => _instance;
  ErrorHandler._internal();

  /// 에러 로깅
  static void logError(
    dynamic error, {
    ErrorType type = ErrorType.unknown,
    LogLevel level = LogLevel.error,
    String? message,
    Map<String, dynamic>? context,
    StackTrace? stackTrace,
  }) {
    final errorInfo = ErrorInfo(
      message: message ?? error.toString(),
      type: type,
      level: level,
      stackTrace: stackTrace?.toString(),
      context: context,
    );

    _logToConsole(errorInfo);
    _logToFile(errorInfo);
  }

  /// 디버그 로깅
  static void logDebug(String message, {Map<String, dynamic>? context}) {
    final errorInfo = ErrorInfo(
      message: message,
      type: ErrorType.system,
      level: LogLevel.debug,
      context: context,
    );

    _logToConsole(errorInfo);
  }

  /// 정보 로깅
  static void logInfo(String message, {Map<String, dynamic>? context}) {
    final errorInfo = ErrorInfo(
      message: message,
      type: ErrorType.system,
      level: LogLevel.info,
      context: context,
    );

    _logToConsole(errorInfo);
  }

  /// 경고 로깅
  static void logWarning(String message, {Map<String, dynamic>? context}) {
    final errorInfo = ErrorInfo(
      message: message,
      type: ErrorType.system,
      level: LogLevel.warning,
      context: context,
    );

    _logToConsole(errorInfo);
  }

  /// 콘솔 로깅
  static void _logToConsole(ErrorInfo errorInfo) {
    if (kDebugMode) {
      final logMessage = '[${errorInfo.level.name.toUpperCase()}] '
          '[${errorInfo.type.name}] '
          '${errorInfo.message}';

      switch (errorInfo.level) {
        case LogLevel.debug:
          developer.log(logMessage, level: 500);
          break;
        case LogLevel.info:
          developer.log(logMessage, level: 800);
          break;
        case LogLevel.warning:
          developer.log(logMessage, level: 900);
          break;
        case LogLevel.error:
          developer.log(logMessage, level: 1000);
          break;
        case LogLevel.critical:
          developer.log(logMessage, level: 1200);
          break;
      }

      if (errorInfo.context != null) {
        developer.log('Context: ${errorInfo.context}', level: 500);
      }

      if (errorInfo.stackTrace != null) {
        developer.log('StackTrace: ${errorInfo.stackTrace}', level: 500);
      }
    }
  }

  /// 파일 로깅 (향후 구현)
  static void _logToFile(ErrorInfo errorInfo) {
    // TODO: 파일 로깅 구현
    // 현재는 콘솔 로깅만 구현
  }

  /// 네트워크 에러 처리
  static void handleNetworkError(dynamic error, {Map<String, dynamic>? context}) {
    logError(
      error,
      type: ErrorType.network,
      level: LogLevel.error,
      context: context,
    );
  }

  /// 인증 에러 처리
  static void handleAuthError(dynamic error, {Map<String, dynamic>? context}) {
    logError(
      error,
      type: ErrorType.authentication,
      level: LogLevel.error,
      context: context,
    );
  }

  /// OAuth 클라이언트 ID 관련 에러 확인
  static bool isOAuthClientIdError(dynamic error) {
    final errorString = error.toString().toLowerCase();
    return errorString.contains('oauth_client_id') ||
        errorString.contains('missing destination name oauth_client_id');
  }

  /// 손상된 세션 에러 확인
  static bool isCorruptedSessionError(dynamic error) {
    final errorString = error.toString().toLowerCase();
    return isOAuthClientIdError(error) ||
        errorString.contains('disposed') ||
        errorString.contains('session') && errorString.contains('invalid');
  }

  /// 데이터베이스 에러 처리
  static void handleDatabaseError(dynamic error, {Map<String, dynamic>? context}) {
    logError(
      error,
      type: ErrorType.database,
      level: LogLevel.error,
      context: context,
    );
  }

  /// 검증 에러 처리
  static void handleValidationError(dynamic error, {Map<String, dynamic>? context}) {
    logError(
      error,
      type: ErrorType.validation,
      level: LogLevel.warning,
      context: context,
    );
  }

  /// 비즈니스 로직 에러 처리
  static void handleBusinessError(dynamic error, {Map<String, dynamic>? context}) {
    logError(
      error,
      type: ErrorType.business,
      level: LogLevel.error,
      context: context,
    );
  }

  /// 시스템 에러 처리
  static void handleSystemError(dynamic error, {Map<String, dynamic>? context}) {
    logError(
      error,
      type: ErrorType.system,
      level: LogLevel.critical,
      context: context,
    );
  }

  /// 사용자 친화적 에러 메시지 생성
  static String getUserFriendlyMessage(ErrorType type, String originalMessage) {
    switch (type) {
      case ErrorType.network:
        return '네트워크 연결에 문제가 있습니다. 인터넷 연결을 확인해주세요.';
      case ErrorType.authentication:
        return '로그인이 필요합니다. 다시 로그인해주세요.';
      case ErrorType.database:
        return '데이터 처리 중 오류가 발생했습니다. 잠시 후 다시 시도해주세요.';
      case ErrorType.validation:
        return '입력한 정보를 확인해주세요.';
      case ErrorType.business:
        return '요청을 처리할 수 없습니다. 잠시 후 다시 시도해주세요.';
      case ErrorType.system:
        return '시스템 오류가 발생했습니다. 고객센터에 문의해주세요.';
      case ErrorType.unknown:
        return '알 수 없는 오류가 발생했습니다. 잠시 후 다시 시도해주세요.';
    }
  }

  /// 에러 타입 자동 감지
  static ErrorType detectErrorType(dynamic error) {
    final errorString = error.toString().toLowerCase();

    if (errorString.contains('network') || 
        errorString.contains('connection') ||
        errorString.contains('timeout')) {
      return ErrorType.network;
    }

    if (errorString.contains('auth') || 
        errorString.contains('login') ||
        errorString.contains('unauthorized')) {
      return ErrorType.authentication;
    }

    if (errorString.contains('database') || 
        errorString.contains('sql') ||
        errorString.contains('constraint')) {
      return ErrorType.database;
    }

    if (errorString.contains('validation') || 
        errorString.contains('invalid') ||
        errorString.contains('required')) {
      return ErrorType.validation;
    }

    if (errorString.contains('business') || 
        errorString.contains('logic') ||
        errorString.contains('rule')) {
      return ErrorType.business;
    }

    return ErrorType.unknown;
  }
}

/// 에러 처리 확장 메서드
extension ErrorHandlerExtension on Object {
  /// 에러 로깅 확장 메서드
  void logError({
    ErrorType type = ErrorType.unknown,
    LogLevel level = LogLevel.error,
    String? message,
    Map<String, dynamic>? context,
    StackTrace? stackTrace,
  }) {
    ErrorHandler.logError(
      this,
      type: type,
      level: level,
      message: message,
      context: context,
      stackTrace: stackTrace,
    );
  }

  /// 사용자 친화적 에러 메시지 생성
  String get userFriendlyMessage {
    final errorType = ErrorHandler.detectErrorType(this);
    return ErrorHandler.getUserFriendlyMessage(errorType, toString());
  }
}
