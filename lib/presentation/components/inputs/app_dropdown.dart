import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:safedrive/core/theme/theme_service.dart';

class AppDropdown<T> extends StatelessWidget {
  final T? value;
  final String label;
  final String? hint;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;
  final IconData? prefixIcon;

  const AppDropdown({
    super.key,
    required this.value,
    required this.label,
    this.hint,
    required this.items,
    required this.onChanged,
    this.prefixIcon,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: ThemeService.isDarkMode,
      builder: (context, isDark, _) {
        return DropdownButtonFormField<T>(
          initialValue: value,
          dropdownColor: AppColors.card(isDark),
          style: TextStyle(
            color: AppColors.t1(isDark),
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
          iconEnabledColor: AppColors.t2(isDark),
          decoration: InputDecoration(
            labelText: label,
            labelStyle: TextStyle(
              color: AppColors.t2(isDark),
              fontSize: 14,
            ),
            hintText: hint,
            hintStyle: TextStyle(
              color: AppColors.t3(isDark),
              fontSize: 14,
            ),
            prefixIcon: prefixIcon != null
                ? Icon(prefixIcon, color: AppColors.brand, size: 20)
                : null,
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            isDense: true,
          ),
          items: items,
          onChanged: (val) {
            HapticFeedback.selectionClick();
            onChanged(val);
          },
        );
      },
    );
  }
}
