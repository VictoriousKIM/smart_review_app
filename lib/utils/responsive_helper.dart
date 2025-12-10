import 'package:flutter/material.dart';
import 'package:responsive_builder/responsive_builder.dart';

/// 반응형 레이아웃 헬퍼 유틸리티
class ResponsiveHelper {
  /// 반응형 값 반환 (Mobile, Tablet, Desktop)
  static T responsiveValue<T>({
    required BuildContext context,
    required T mobile,
    T? tablet,
    T? desktop,
  }) {
    return getValueForScreenType<T>(
      context: context,
      mobile: mobile,
      tablet: tablet ?? mobile,
      desktop: desktop ?? tablet ?? mobile,
    );
  }
  
  /// 반응형 패딩 반환
  static EdgeInsets responsivePadding({
    required BuildContext context,
    required EdgeInsets mobile,
    EdgeInsets? tablet,
    EdgeInsets? desktop,
  }) {
    return responsiveValue<EdgeInsets>(
      context: context,
      mobile: mobile,
      tablet: tablet,
      desktop: desktop,
    );
  }
  
  /// 반응형 폰트 크기 반환
  static double responsiveFontSize({
    required BuildContext context,
    required double mobile,
    double? tablet,
    double? desktop,
  }) {
    return responsiveValue<double>(
      context: context,
      mobile: mobile,
      tablet: tablet,
      desktop: desktop,
    );
  }
  
  /// 반응형 아이콘 크기 반환
  static double responsiveIconSize({
    required BuildContext context,
    required double mobile,
    double? tablet,
    double? desktop,
  }) {
    return responsiveValue<double>(
      context: context,
      mobile: mobile,
      tablet: tablet,
      desktop: desktop,
    );
  }
  
  /// 반응형 최대 너비 반환
  static double responsiveMaxWidth({
    required BuildContext context,
    required double mobile,
    double? tablet,
    double? desktop,
  }) {
    return responsiveValue<double>(
      context: context,
      mobile: mobile,
      tablet: tablet,
      desktop: desktop,
    );
  }
  
  /// 반응형 그리드 열 개수 반환
  static int responsiveGridColumns({
    required BuildContext context,
    required int mobile,
    int? tablet,
    int? desktop,
  }) {
    return responsiveValue<int>(
      context: context,
      mobile: mobile,
      tablet: tablet,
      desktop: desktop,
    );
  }
}

