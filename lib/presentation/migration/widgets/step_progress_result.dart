import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/import/import_config.dart';
import '../../../core/import/import_result.dart';
import '../../../core/widgets/app_button.dart';
import '../providers/import_wizard_provider.dart';

final _numFmt = NumberFormat.decimalPattern('fr_FR');

/// Affiche soit la barre de progression pendant l'import, soit les résultats finaux.
class StepProgressResult extends ConsumerWidget {
  final ImportEntityType entityType;

  const StepProgressResult({super.key, required this.entityType});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(importWizardProvider(entityType));

    if (state.step == WizardStep.importing) {
      return _buildProgress(state);
    }
    return _buildResult(context, ref, state);
  }

  // ── Progression ────────────────────────────────────────────────────────────

  Widget _buildProgress(ImportWizardState state) {
    final done =
        (state.progress * state.mappedRows.length).round();
    final total = state.mappedRows.length;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.sync_rounded,
                size: 52, color: AppColors.primary),
            const SizedBox(height: 20),
            Text('Import en cours…', style: AppTextStyles.h3),
            const SizedBox(height: 8),
            Text(
              '${_numFmt.format(done)} / ${_numFmt.format(total)} traités',
              style: AppTextStyles.caption,
            ),
            const SizedBox(height: 24),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: state.progress,
                minHeight: 12,
                backgroundColor: AppColors.border,
                valueColor: const AlwaysStoppedAnimation<Color>(
                    AppColors.primary),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              '${(state.progress * 100).toStringAsFixed(0)} %',
              style: AppTextStyles.bodyBold,
            ),
          ],
        ),
      ),
    );
  }

  // ── Résultats ──────────────────────────────────────────────────────────────

  Widget _buildResult(
      BuildContext context, WidgetRef ref, ImportWizardState state) {
    final r = state.result!;
    final ok = r.errors.isEmpty;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(
              ok ? Icons.check_circle_rounded : Icons.warning_amber_rounded,
              size: 56,
              color: ok ? AppColors.success : AppColors.warning,
            ),
            const SizedBox(height: 12),
            Text(
              ok ? 'Import terminé' : 'Import terminé avec des erreurs',
              style: AppTextStyles.h2,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),

            // Tuiles stats
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Tuile(
                      '${_numFmt.format(r.created)}', 'Importés',
                      AppColors.success, AppColors.successLight,
                      Icons.add_circle_rounded),
                  const SizedBox(width: 10),
                  _Tuile(
                      '${_numFmt.format(r.updated)}', 'Mis à jour',
                      AppColors.secondary, AppColors.secondaryLight,
                      Icons.update_rounded),
                  const SizedBox(width: 10),
                  _Tuile(
                      '${_numFmt.format(r.ignored)}', 'Ignorés',
                      AppColors.textSecondary, AppColors.background,
                      Icons.skip_next_rounded),
                  const SizedBox(width: 10),
                  _Tuile(
                      '${r.errors.length}', 'Erreurs',
                      AppColors.danger, AppColors.dangerLight,
                      Icons.error_outline_rounded),
                ],
              ),
            ),

            // Erreurs
            if (r.errors.isNotEmpty) ...[
              const SizedBox(height: 20),
              _ErreurSection(errors: r.errors, result: r),
            ],

            const SizedBox(height: 28),

            // Boutons
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AppButton(
                  label: 'Nouvel import',
                  icon: Icons.upload_file_rounded,
                  isOutlined: true,
                  onPressed: () => ref
                      .read(importWizardProvider(entityType).notifier)
                      .reinitialiser(),
                ),
                const SizedBox(width: 12),
                AppButton(
                  label: _destinationLabel,
                  icon: Icons.arrow_forward_rounded,
                  onPressed: () => context.go(_destinationRoute),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String get _destinationLabel {
    switch (entityType) {
      case ImportEntityType.articles:
        return 'Voir les articles';
      case ImportEntityType.clients:
        return 'Voir les clients';
      case ImportEntityType.fournisseurs:
        return 'Voir les fournisseurs';
      case ImportEntityType.stock:
        return 'Voir le stock';
    }
  }

  String get _destinationRoute {
    switch (entityType) {
      case ImportEntityType.articles:
        return '/articles';
      case ImportEntityType.clients:
        return '/clients';
      case ImportEntityType.fournisseurs:
        return '/suppliers';
      case ImportEntityType.stock:
        return '/stock';
    }
  }
}

class _Tuile extends StatelessWidget {
  final String value;
  final String label;
  final Color color;
  final Color bg;
  final IconData icon;

  const _Tuile(this.value, this.label, this.color, this.bg, this.icon);

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withAlpha(60)),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 26),
              const SizedBox(height: 6),
              Text(value,
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: color)),
              const SizedBox(height: 2),
              Text(label,
                  style: AppTextStyles.caption,
                  textAlign: TextAlign.center),
            ],
          ),
        ),
      );
}

class _ErreurSection extends StatelessWidget {
  final List<ImportError> errors;
  final ImportResult result;
  const _ErreurSection({required this.errors, required this.result});

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      title: Text('Détail des erreurs (${errors.length})',
          style: AppTextStyles.bodyBold.copyWith(color: AppColors.danger)),
      leading: const Icon(Icons.error_outline_rounded, color: AppColors.danger),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextButton.icon(
            icon: const Icon(Icons.download_rounded, size: 16),
            label: const Text('Télécharger le rapport'),
            style:
                TextButton.styleFrom(foregroundColor: AppColors.danger),
            onPressed: () => _exporterRapport(result),
          ),
          const Icon(Icons.expand_more),
        ],
      ),
      backgroundColor: AppColors.dangerLight,
      collapsedBackgroundColor: AppColors.dangerLight,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      collapsedShape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      children: errors
          .take(50)
          .map((e) => ListTile(
                dense: true,
                leading: const Icon(Icons.chevron_right_rounded,
                    size: 16, color: AppColors.danger),
                title: Text(
                  'Ligne ${e.rowNumber}'
                  '${e.identifier != null ? ' (${e.identifier})' : ''}'
                  ' : ${e.message}',
                  style: AppTextStyles.caption,
                ),
              ))
          .toList(),
    );
  }

  Future<void> _exporterRapport(ImportResult result) async {
    final path = await FilePicker.platform.saveFile(
      dialogTitle: 'Enregistrer le rapport d\'erreurs',
      fileName: 'rapport_import_erreurs.txt',
      allowedExtensions: ['txt'],
    );
    if (path == null) return;
    await File(path).writeAsString(result.errorReport, flush: true);
  }
}
