import 'package:flutter/material.dart';
import 'package:safedrive/core/theme/theme_service.dart';

class UserAvatar extends StatelessWidget {
  final String? avatarUrl;
  final String name;
  final double size;
  final double borderWidth;

  const UserAvatar({
    super.key,
    this.avatarUrl,
    required this.name,
    this.size = 48.0,
    this.borderWidth = 2.0,
  });

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : 'U';

    return ValueListenableBuilder<bool>(
      valueListenable: ThemeService.isDarkMode,
      builder: (context, isDark, _) {
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.brand, width: borderWidth),
            color: AppColors.cardSecondary(isDark),
          ),
          child: ClipOval(
            child: avatarUrl != null && avatarUrl!.isNotEmpty
                ? Image.network(
                    avatarUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => _fallbackInitial(initial),
                  )
                : _fallbackInitial(initial),
          ),
        );
      },
    );
  }

  Widget _fallbackInitial(String initial) {
    return Center(
      child: Text(
        initial,
        style: TextStyle(
          color: AppColors.brand,
          fontSize: size * 0.42,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
