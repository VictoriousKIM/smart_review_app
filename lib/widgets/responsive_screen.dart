import 'package:flutter/material.dart';
import 'package:responsive_builder/responsive_builder.dart';

/// 모든 스크린의 body를 감싸는 공통 위젯
class ResponsiveScreen extends StatelessWidget {
  final Widget mobile;
  final Widget? tablet;
  final Widget? desktop;
  final EdgeInsets? padding;
  final double? maxWidth;
  final bool centerContent;

  const ResponsiveScreen({
    super.key,
    required this.mobile,
    this.tablet,
    this.desktop,
    this.padding,
    this.maxWidth,
    this.centerContent = false,
  });

  @override
  Widget build(BuildContext context) {
    return ResponsiveBuilder(
      builder: (context, sizingInformation) {
        // 레이아웃 선택
        Widget layout = mobile;
        if (sizingInformation.isTablet && tablet != null) {
          layout = tablet!;
        } else if (sizingInformation.isDesktop && desktop != null) {
          layout = desktop!;
        }

        // 패딩 적용
        if (padding != null) {
          layout = Padding(padding: padding!, child: layout);
        }

        // 최대 너비 제한
        if (maxWidth != null) {
          layout = Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth!),
              child: layout,
            ),
          );
        } else if (centerContent) {
          layout = Center(child: layout);
        }

        return layout;
      },
    );
  }
}
