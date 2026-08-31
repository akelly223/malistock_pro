import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/import/import_config.dart';
import '../../../core/import/import_field.dart';
import '../../../core/widgets/app_button.dart';
import '../providers/import_wizard_provider.dart';

class StepColumnMapping extends ConsumerWidget {
  final ImportEntityType entityType;

  const StepColumnMapping({super.key, required this.entityType});

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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(importWizardProvider(entityType));
    final notifier = ref.read(importWizardProvider(entityType).notifier);
    final config = _config;

    final headers = state.parsedFile?.headers ?? [];
    final mappings = state.columnMappings;

    // Champs déjà assignés (pour éviter les doublons dans les dropdowns)
    final assignedFields =
        mappings.values.whereType<ImportField>().toSet();

    final allMapped = config.requiredFields.every(
      (f) => assignedFields.contains(f),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // En-tête info
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.primaryLight,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.primary.withAlpha(60)),
          ),
          child: Row(
            children: [
              const Icon(Icons.auto_fix_high_rounded,
                  color: AppColors.primary, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'MaliStock Pro a détecté ${headers.length} colonnes. '
                  'Vérifiez les associations ou corrigez-les.',
                  style: AppTextStyles.body,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Tableau de mapping
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              // En-tête tableau
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: const BoxDecoration(
                  color: AppColors.background,
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(12)),
                ),
                child: Row(
                  children: [
                    Expanded(
                        flex: 2,
                        child: Text('Colonne du fichier',
                            style: AppTextStyles.bodyBold)),
                    Expanded(
                        flex: 3,
                        child: Text('Champ MaliStock Pro',
                            style: AppTextStyles.bodyBold)),
                    Expanded(
                        flex: 1,
                        child: Text('Statut',
                            style: AppTextStyles.bodyBold,
                            textAlign: TextAlign.center)),
                  ],
                ),
              ),
              const Divider(height: 1),
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: headers.length,
                separatorBuilder: (_, __) =>
                    const Divider(height: 1, indent: 16, endIndent: 16),
                itemBuilder: (context, i) {
                  final header = headers[i];
                  final currentField = mappings[i];
                  final isAutoDetected = currentField != null;

                  return Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    child: Row(
                      children: [
                        // Nom de la colonne dans le fichier
                        Expanded(
                          flex: 2,
                          child: Text(
                            header.isEmpty ? '(vide)' : header,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 12.5,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        // Dropdown champ cible
                        Expanded(
                          flex: 3,
                          child: DropdownButtonFormField<ImportField?>(
                            value: currentField,
                            decoration: InputDecoration(
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide:
                                    const BorderSide(color: AppColors.border),
                              ),
                              isDense: true,
                            ),
                            isExpanded: true,
                            items: [
                              const DropdownMenuItem<ImportField?>(
                                value: null,
                                child: Text('— Ignorer —',
                                    style: TextStyle(
                                        color: AppColors.textSecondary,
                                        fontStyle: FontStyle.italic)),
                              ),
                              ...config.availableFields.map((f) {
                                final meta = importFieldMeta[f]!;
                                final alreadyUsed =
                                    assignedFields.contains(f) &&
                                        mappings[i] != f;
                                return DropdownMenuItem<ImportField?>(
                                  value: f,
                                  enabled: !alreadyUsed,
                                  child: Text(
                                    '${meta.label}${meta.required ? ' *' : ''}',
                                    style: TextStyle(
                                      color: alreadyUsed
                                          ? AppColors.textSecondary
                                          : null,
                                    ),
                                  ),
                                );
                              }),
                            ],
                            onChanged: (v) =>
                                notifier.setColumnMapping(i, v),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Statut auto-détecté ou pas
                        Expanded(
                          flex: 1,
                          child: Center(
                            child: isAutoDetected
                                ? Tooltip(
                                    message: 'Détecté automatiquement',
                                    child: const Icon(
                                        Icons.auto_awesome_rounded,
                                        color: AppColors.success,
                                        size: 18),
                                  )
                                : const Icon(Icons.remove_rounded,
                                    color: AppColors.textSecondary,
                                    size: 18),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),

        // Champs obligatoires non mappés
        if (!allMapped) ...[
          const SizedBox(height: 12),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.dangerLight,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.danger.withAlpha(60)),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning_rounded,
                    color: AppColors.danger, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Champs obligatoires non assignés : '
                    '${config.requiredFields.where((f) => !assignedFields.contains(f)).map((f) => importFieldMeta[f]!.label).join(', ')}',
                    style: AppTextStyles.caption
                        .copyWith(color: AppColors.danger),
                  ),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 24),

        // Actions
        Row(
          children: [
            AppButton(
              label: 'Retour',
              icon: Icons.arrow_back_rounded,
              isOutlined: true,
              onPressed: () => ref
                  .read(importWizardProvider(entityType).notifier)
                  .retourEtape(WizardStep.fileSelection),
            ),
            const SizedBox(width: 12),
            if (state.isLoading)
              const Padding(
                padding: EdgeInsets.only(left: 16),
                child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2)),
              )
            else
              AppButton(
                label: 'Aperçu',
                icon: Icons.navigate_next_rounded,
                onPressed: allMapped
                    ? () => notifier.validerMapping()
                    : null,
              ),
          ],
        ),
      ],
    );
  }
}
