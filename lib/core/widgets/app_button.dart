import 'package:flutter/material.dart';
import '../../app/theme/app_colors.dart';

/// Bouton standard utilisé partout dans l'application : grande zone
/// cliquable, icône optionnelle, état de chargement intégré.
class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  final bool isOutlined;
  final bool isDanger;
  final double? width;

  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.isOutlined = false,
    this.isDanger = false,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    final child = isLoading
        ? const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
          )
        : Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 22),
                const SizedBox(width: 10),
              ],
              Text(label),
            ],
          );

    final button = isOutlined
        ? OutlinedButton(
            onPressed: isLoading ? null : onPressed,
            style: isDanger
                ? OutlinedButton.styleFrom(
                    foregroundColor: AppColors.danger,
                    side: const BorderSide(color: AppColors.danger, width: 1.5),
                  )
                : null,
            child: child,
          )
        : ElevatedButton(
            onPressed: isLoading ? null : onPressed,
            style: isDanger
                ? ElevatedButton.styleFrom(backgroundColor: AppColors.danger)
                : null,
            child: child,
          );

    return width != null ? SizedBox(width: width, child: button) : button;
  }
}
