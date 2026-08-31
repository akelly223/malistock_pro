import 'package:flutter/material.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_text_styles.dart';

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  final Widget? action;

  const EmptyState({
    super.key,
    required this.icon,
    required this.message,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 56, color: AppColors.textSecondary),
          const SizedBox(height: 16),
          Text(
            message,
            style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
          if (action != null) ...[
            const SizedBox(height: 20),
            action!,
          ],
        ],
      ),
    );
  }
}
