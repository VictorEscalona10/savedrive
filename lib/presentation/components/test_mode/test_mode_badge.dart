import 'package:flutter/material.dart';
import 'package:safedrive/core/theme/app_colors.dart';

/// Chip reutilizable que avisa de que el modo de prueba está activo
/// (RF-3 en el dashboard y RF-11 en la cabina).
///
/// Usa colores fijos para poder probarse aislado, sin depender de
/// [ThemeService]: fondo naranja de la paleta y texto oscuro con contraste
/// superior a 4.5:1.
class TestModeBadge extends StatelessWidget {
  /// Reduce el relleno y el tamaño de fuente para paneles compactos.
  final bool compact;

  const TestModeBadge({super.key, this.compact = false});

  /// Texto oscuro legible sobre el naranja de [AppColors.orange].
  static const Color _contentColor = Color(0xFF0B0F14);

  @override
  Widget build(BuildContext context) {
    final double iconSize = compact ? 13 : 16;
    final double fontSize = compact ? 10 : 11.5;
    final double gap = compact ? 4 : 6;
    final EdgeInsets padding = compact
        ? const EdgeInsets.symmetric(horizontal: 8, vertical: 3)
        : const EdgeInsets.symmetric(horizontal: 11, vertical: 6);

    return Semantics(
      label: 'Modo de prueba activo',
      container: true,
      excludeSemantics: true,
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          color: AppColors.orange,
          borderRadius: BorderRadius.circular(compact ? 9 : 999),
          border: Border.all(color: const Color(0x330B0F14), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.science_rounded, size: iconSize, color: _contentColor),
            SizedBox(width: gap),
            Text(
              'MODO PRUEBA',
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.visible,
              style: TextStyle(
                color: _contentColor,
                fontSize: fontSize,
                fontWeight: FontWeight.w800,
                letterSpacing: compact ? 0.4 : 0.6,
                height: 1.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
