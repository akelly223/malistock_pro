import 'package:flutter/material.dart';
import '../../app/theme/app_colors.dart';
import '../../domain/entities/document_type.dart';

/// Badge coloré indiquant le statut d'un document commercial.
class DocumentStatusBadge extends StatelessWidget {
  final DocumentStatut statut;
  final bool small;

  const DocumentStatusBadge({
    super.key,
    required this.statut,
    this.small = false,
  });

  static Color _fg(DocumentStatut s) => switch (s) {
        DocumentStatut.brouillon => AppColors.warning,
        DocumentStatut.valide => AppColors.success,
        DocumentStatut.transforme => AppColors.secondary,
        DocumentStatut.annule => AppColors.danger,
      };

  static Color _bg(DocumentStatut s) => switch (s) {
        DocumentStatut.brouillon => AppColors.warningLight,
        DocumentStatut.valide => AppColors.successLight,
        DocumentStatut.transforme => AppColors.secondaryLight,
        DocumentStatut.annule => AppColors.dangerLight,
      };

  static IconData _icon(DocumentStatut s) => switch (s) {
        DocumentStatut.brouillon => Icons.edit_outlined,
        DocumentStatut.valide => Icons.check_circle_outline,
        DocumentStatut.transforme => Icons.swap_horiz_rounded,
        DocumentStatut.annule => Icons.cancel_outlined,
      };

  @override
  Widget build(BuildContext context) {
    final fg = _fg(statut);
    final bg = _bg(statut);
    final fontSize = small ? 11.0 : 13.0;
    final padding = small
        ? const EdgeInsets.symmetric(horizontal: 8, vertical: 3)
        : const EdgeInsets.symmetric(horizontal: 10, vertical: 5);

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_icon(statut), size: small ? 12 : 14, color: fg),
          const SizedBox(width: 4),
          Text(
            statut.libelle,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w600,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}
