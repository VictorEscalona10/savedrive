import 'package:flutter/material.dart';
import 'package:safedrive/core/theme/theme_service.dart';

class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final Border? border;
  final Gradient? gradient;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18.0),
    this.margin,
    this.onTap,
    this.border,
    this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: ThemeService.isDarkMode,
      builder: (context, isDark, _) {
        final cardBox = Container(
          margin: margin,
          padding: padding,
          decoration: BoxDecoration(
            color: gradient == null ? AppColors.card(isDark) : null,
            gradient: gradient,
            borderRadius: BorderRadius.circular(22),
            border: border ??
                Border.all(
                  color: AppColors.border(isDark),
                  width: 1.2,
                ),
            boxShadow: [
              BoxShadow(
                color: isDark ? const Color(0x18000000) : const Color(0x08000000),
                blurRadius: 12,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: child,
        );

        if (onTap != null) {
          return Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(22),
              onTap: onTap,
              child: cardBox,
            ),
          );
        }

        return cardBox;
      },
    );
  }
}
