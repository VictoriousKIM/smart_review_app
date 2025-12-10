import 'package:flutter/material.dart';
import 'package:responsive_builder/responsive_builder.dart';

/// 반응형 Container 위젯
class ResponsiveContainer extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final EdgeInsets? margin;
  final double? width;
  final double? maxWidth;
  final Color? color;
  final BoxDecoration? decoration;
  
  const ResponsiveContainer({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.width,
    this.maxWidth,
    this.color,
    this.decoration,
  });
  
  @override
  Widget build(BuildContext context) {
    return ResponsiveBuilder(
      builder: (context, sizingInformation) {
        // 반응형 패딩
        final responsivePadding = padding != null
            ? getValueForScreenType<EdgeInsets>(
                context: context,
                mobile: padding!,
                tablet: EdgeInsets.all(padding!.horizontal * 1.5),
                desktop: EdgeInsets.all(padding!.horizontal * 2),
              )
            : null;
        
        // 반응형 최대 너비
        final responsiveMaxWidth = maxWidth != null
            ? getValueForScreenType<double>(
                context: context,
                mobile: double.infinity,
                tablet: maxWidth! * 0.9,
                desktop: maxWidth!,
              )
            : null;
        
        return Container(
          padding: responsivePadding,
          margin: margin,
          width: width,
          constraints: responsiveMaxWidth != null
              ? BoxConstraints(maxWidth: responsiveMaxWidth)
              : null,
          color: color,
          decoration: decoration,
          child: child,
        );
      },
    );
  }
}

