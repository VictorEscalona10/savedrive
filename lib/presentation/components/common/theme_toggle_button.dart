import 'package:flutter/material.dart';
import 'package:safedrive/core/theme/theme_service.dart';

class ThemeToggleButton extends StatelessWidget {
  const ThemeToggleButton({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: ThemeService.isDarkMode,
      builder: (context, isDark, _) {
        return Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: ThemeService.toggleTheme,
            child: Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: AppColors.card(isDark),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border(isDark), width: 1.2),
                boxShadow: [
                  BoxShadow(
                    color: isDark ? const Color(0x1F000000) : const Color(0x0A000000),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                transitionBuilder: (child, anim) => RotationTransition(
                  turns: anim,
                  child: FadeTransition(opacity: anim, child: child),
                ),
                child: Icon(
                  isDark ? Icons.wb_sunny_rounded : Icons.nightlight_round,
                  key: ValueKey<bool>(isDark),
                  color: isDark ? const Color(0xFFF59E0B) : const Color(0xFF3B82F6),
                  size: 22,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
