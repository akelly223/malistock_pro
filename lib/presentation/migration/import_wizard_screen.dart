import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_text_styles.dart';
import '../../app/providers/session_provider.dart';
import '../../core/import/import_config.dart';
import '../../core/permissions/permissions.dart';
import '../../core/widgets/access_denied_view.dart';
import 'providers/import_wizard_provider.dart';
import 'widgets/step_column_mapping.dart';
import 'widgets/step_file_selection.dart';
import 'widgets/step_preview.dart';
import 'widgets/step_progress_result.dart';
import 'widgets/step_summary.dart';

/// Écran générique en 5 étapes pour tout type d'import.
/// Configuré par [entityType].
class ImportWizardScreen extends ConsumerWidget {
  final ImportEntityType entityType;

  const ImportWizardScreen({super.key, required this.entityType});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final utilisateur = ref.watch(sessionProvider);
    if (!Permissions.peutImporterDonnees(utilisateur)) {
      return const AccessDeniedView(titre: 'Import de données');
    }

    final state = ref.watch(importWizardProvider(entityType));
    final config = _config;

    return Scaffold(
      appBar: AppBar(
        title: Text('Importer les ${config.displayName.toLowerCase()}'),
        leading: BackButton(onPressed: () {
          ref.read(importWizardProvider(entityType).notifier).reinitialiser();
          context.pop();
        }),
      ),
      body: Column(
        children: [
          // Indicateur de progression en haut
          if (state.step != WizardStep.importing &&
              state.step != WizardStep.result)
            _StepIndicator(currentStep: state.step),

          // Corps de l'étape active
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: _buildStep(state.step),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep(WizardStep step) {
    switch (step) {
      case WizardStep.fileSelection:
        return StepFileSelection(entityType: entityType);
      case WizardStep.columnMapping:
        return StepColumnMapping(entityType: entityType);
      case WizardStep.preview:
        return StepPreview(entityType: entityType);
      case WizardStep.summary:
        return StepSummary(entityType: entityType);
      case WizardStep.importing:
      case WizardStep.result:
        return StepProgressResult(entityType: entityType);
    }
  }

  ImportConfig get _config {
    switch (entityType) {
      case ImportEntityType.articles:
        return ImportConfig.articles;
      case ImportEntityType.clients:
        return ImportConfig.clients;
      case ImportEntityType.fournisseurs:
        return ImportConfig.fournisseurs;
      case ImportEntityType.stock:
        return ImportConfig.stock;
    }
  }
}

// ── Indicateur d'étape ─────────────────────────────────────────────────────────

class _StepIndicator extends StatelessWidget {
  final WizardStep currentStep;
  const _StepIndicator({required this.currentStep});

  static const _labels = [
    'Fichier',
    'Colonnes',
    'Aperçu',
    'Résumé',
  ];

  static const _steps = [
    WizardStep.fileSelection,
    WizardStep.columnMapping,
    WizardStep.preview,
    WizardStep.summary,
  ];

  @override
  Widget build(BuildContext context) {
    final current = _steps.indexOf(currentStep);

    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
      child: Row(
        children: List.generate(_steps.length * 2 - 1, (i) {
          if (i.isOdd) {
            // Ligne de connexion
            final idx = i ~/ 2;
            final passed = current > idx;
            return Expanded(
              child: Container(
                height: 2,
                color: passed ? AppColors.primary : AppColors.border,
              ),
            );
          }
          final idx = i ~/ 2;
          final done = current > idx;
          final active = current == idx;
          return _StepBubble(
            number: idx + 1,
            label: _labels[idx],
            done: done,
            active: active,
          );
        }),
      ),
    );
  }
}

class _StepBubble extends StatelessWidget {
  final int number;
  final String label;
  final bool done;
  final bool active;

  const _StepBubble({
    required this.number,
    required this.label,
    required this.done,
    required this.active,
  });

  @override
  Widget build(BuildContext context) {
    final color = done || active ? AppColors.primary : AppColors.border;
    final textColor =
        done || active ? Colors.white : AppColors.textSecondary;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: done
                ? const Icon(Icons.check_rounded,
                    color: Colors.white, size: 16)
                : Text(
                    '$number',
                    style: TextStyle(
                        color: textColor,
                        fontWeight: FontWeight.w700,
                        fontSize: 13),
                  ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight:
                active ? FontWeight.w700 : FontWeight.w400,
            color: active
                ? AppColors.primary
                : AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}
