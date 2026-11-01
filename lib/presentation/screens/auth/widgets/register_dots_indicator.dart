import 'package:flutter/material.dart';
import 'package:safedrive/core/theme/theme_service.dart';

class RegisterDotsIndicator extends StatelessWidget {
  final int currentIndex;
  final int totalSteps;

  const RegisterDotsIndicator({
    super.key,
    required this.currentIndex,
    required this.totalSteps,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: ThemeService.isDarkMode,
      builder: (context, isDark, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(totalSteps, (index) {
            final isActive = index == currentIndex;
            final isCompleted = index < currentIndex;

            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: isActive ? 24 : 8,
              height: 8,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                color: isActive
                    ? AppColors.brand
                    : isCompleted
                        ? AppColors.brand.withValues(alpha: 0.5)
                        : (isDark
                            ? Colors.white.withValues(alpha: 0.15)
                            : Colors.black.withValues(alpha: 0.12)),
                boxShadow: isActive
                    ? [
                        BoxShadow(
                          color: AppColors.brand.withValues(alpha: 0.4),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
            );
          }),
        );
      },
    );
  }
}

