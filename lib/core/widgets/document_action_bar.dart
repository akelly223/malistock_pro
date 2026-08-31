import 'package:flutter/material.dart';
import '../../app/theme/app_colors.dart';
import '../../domain/entities/commercial_document.dart';
import '../../domain/entities/document_type.dart';
import '../../core/services/document_transformation_service.dart';
import 'app_button.dart';

/// Barre d'actions contextuelle d'un document commercial.
///
/// Affiche les boutons disponibles selon le type et le statut du document :
/// Modifier, Valider, Transformer (un bouton par cible possible), Imprimer,
/// Annuler. Les callbacks null désactivent le bouton correspondant.
class DocumentActionBar extends StatelessWidget {
  final DocumentEntity document;
  final bool isLoading;
  final VoidCallback? onEditer;
  final VoidCallback? onValider;
  final void Function(DocumentType cible)? onTransformer;
  final VoidCallback? onImprimer;
  final VoidCallback? onExporterPdf;
  final VoidCallback? onAnnuler;

  const DocumentActionBar({
    super.key,
    required this.document,
    this.isLoading = false,
    this.onEditer,
    this.onValider,
    this.onTransformer,
    this.onImprimer,
    this.onExporterPdf,
    this.onAnnuler,
  });

  @override
  Widget build(BuildContext context) {
    final rules = const DocumentTransformationService();
    final transformations = rules.transformationsPossibles(document);
    final estBrouillon = document.statut == DocumentStatut.brouillon;
    final estValide = document.statut == DocumentStatut.valide;
    final estAnnule = document.statut == DocumentStatut.annule;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: const Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          // ── Actions primaires (gauche) ────────────────────────────────
          if (estBrouillon && onEditer != null)
            _Action(
              label: 'Modifier',
              icon: Icons.edit_outlined,
              isOutlined: true,
              onPressed: isLoading ? null : onEditer,
            ),

          if (estBrouillon && onValider != null) ...[
            if (onEditer != null) const SizedBox(width: 10),
            _Action(
              label: 'Valider',
              icon: Icons.check_circle_outline,
              onPressed: isLoading ? null : onValider,
              isLoading: isLoading,
            ),
          ],

          // ── Transformations disponibles ───────────────────────────────
          if (estValide && transformations.isNotEmpty && onTransformer != null)
            ...transformations.map((cible) => Padding(
                  padding: const EdgeInsets.only(left: 10),
                  child: _Action(
                    label: 'Créer ${cible.libelle}',
                    icon: Icons.swap_horiz_rounded,
                    onPressed:
                        isLoading ? null : () => onTransformer!(cible),
                  ),
                )),

          const Spacer(),

          // ── Actions secondaires (droite) ──────────────────────────────
          if (onImprimer != null)
            _Action(
              label: 'Imprimer',
              icon: Icons.print_outlined,
              isOutlined: true,
              onPressed: isLoading ? null : onImprimer,
            ),

          if (onExporterPdf != null) ...[
            const SizedBox(width: 10),
            _Action(
              label: 'Export PDF',
              icon: Icons.picture_as_pdf_outlined,
              onPressed: isLoading ? null : onExporterPdf,
            ),
          ],

          if (!estAnnule && onAnnuler != null) ...[
            const SizedBox(width: 10),
            _Action(
              label: 'Annuler',
              icon: Icons.cancel_outlined,
              isOutlined: true,
              isDanger: true,
              onPressed: isLoading ? null : onAnnuler,
            ),
          ],
        ],
      ),
    );
  }
}

class _Action extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool isOutlined;
  final bool isDanger;
  final bool isLoading;

  const _Action({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.isOutlined = false,
    this.isDanger = false,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return AppButton(
      label: label,
      icon: icon,
      onPressed: onPressed,
      isOutlined: isOutlined,
      isDanger: isDanger,
      isLoading: isLoading,
    );
  }
}
