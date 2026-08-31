import 'package:flutter/material.dart';

/// Palette de couleurs. Choix volontairement contrastés et simples
/// pour rester lisibles par des utilisateurs peu à l'aise avec
/// l'informatique (priorité simplicité du cahier des charges).
class AppColors {
  AppColors._();

  static const Color primary = Color(0xFF1E6F46); // vert profond, évoque le commerce/argent
  static const Color primaryDark = Color(0xFF134A2E);
  static const Color primaryLight = Color(0xFFE7F4ED);

  static const Color secondary = Color(0xFFD98C2B); // orange chaleureux (accent Mali)
  static const Color secondaryLight = Color(0xFFFCEFDC);

  static const Color danger = Color(0xFFC23B33);
  static const Color dangerLight = Color(0xFFFBE7E5);

  static const Color success = Color(0xFF2E8B57);
  static const Color successLight = Color(0xFFE5F4EC);

  static const Color warning = Color(0xFFD9A226);
  static const Color warningLight = Color(0xFFFCF3DD);

  static const Color background = Color(0xFFF6F7F9);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color border = Color(0xFFE2E5E9);

  static const Color textPrimary = Color(0xFF1F2430);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textOnPrimary = Color(0xFFFFFFFF);

  static const Color sidebarBackground = Color(0xFF16302A);
  static const Color sidebarItemActive = Color(0xFF1E6F46);
  static const Color sidebarText = Color(0xFFD8E5DF);
}
