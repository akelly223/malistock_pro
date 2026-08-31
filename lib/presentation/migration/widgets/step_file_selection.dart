import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/import/import_config.dart';
import '../../../core/widgets/app_button.dart';
import '../providers/import_wizard_provider.dart';

class StepFileSelection extends ConsumerWidget {
  final ImportEntityType entityType;

  const StepFileSelection({super.key, required this.entityType});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(importWizardProvider(entityType));
    final config = _config;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.symmetric(vertical: 48, horizontal: 32),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.primary.withAlpha(80),
                  width: 2,
                ),
              ),
              child: Column(
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(36),
                    ),
                    child: const Icon(Icons.upload_file_rounded,
                        size: 36, color: AppColors.primary),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Importer les ${config.displayName.toLowerCase()}',
                    style: AppTextStyles.h3,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Sélectionnez un fichier exporté depuis votre logiciel actuel.\n'
                    'MaliStock Pro détecte automatiquement les colonnes.',
                    style: AppTextStyles.body
                        .copyWith(color: AppColors.textSecondary),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  _FormatsBadges(),
                  const SizedBox(height: 28),
                  if (state.isLoading)
                    const Column(
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 12),
                        Text('Analyse du fichier…'),
                      ],
                    )
                  else
                    AppButton(
                      label: 'Choisir un fichier',
                      icon: Icons.folder_open_rounded,
                      width: 260,
                      onPressed: () => _choisirFichier(ref),
                    ),
                ],
              ),
            ),
            if (state.errorMessage != null) ...[
              const SizedBox(height: 16),
              _ErreurBandeau(state.errorMessage!),
            ],
          ],
        ),
      ),
    );
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

  Future<void> _choisirFichier(WidgetRef ref) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['txt', 'csv', 'xlsx'],
      dialogTitle: 'Sélectionner le fichier à importer',
    );
    final path = result?.files.single.path;
    if (path == null) return;
    await ref.read(importWizardProvider(entityType).notifier).chargerFichier(path);
  }
}

class _FormatsBadges extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      children: [
        _Badge('TXT', Icons.description_outlined),
        _Badge('CSV', Icons.table_chart_outlined),
        _Badge('Excel (.xlsx)', Icons.grid_on_rounded),
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final IconData icon;
  const _Badge(this.label, this.icon);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.primaryLight,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.primary.withAlpha(60)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: AppColors.primary),
            const SizedBox(width: 4),
            Text(label,
                style: TextStyle(
                    fontSize: 12,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      );
}

class _ErreurBandeau extends StatelessWidget {
  final String message;
  const _ErreurBandeau(this.message);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.dangerLight,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.danger.withAlpha(80)),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline_rounded,
                color: AppColors.danger, size: 20),
            const SizedBox(width: 10),
            Expanded(
                child: Text(message,
                    style:
                        AppTextStyles.body.copyWith(color: AppColors.danger))),
          ],
        ),
      );
}
