import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/import/import_config.dart';
import '../../../core/import/import_field.dart';
import '../../../core/widgets/app_button.dart';
import '../providers/import_wizard_provider.dart';

final _numFmt = NumberFormat.decimalPattern('fr_FR');

class StepPreview extends ConsumerWidget {
  final ImportEntityType entityType;

  const StepPreview({super.key, required this.entityType});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(importWizardProvider(entityType));
    final notifier = ref.read(importWizardProvider(entityType).notifier);

    final rows = state.mappedRows;
    final preview = rows.take(20).toList();
    final total = rows.length;

    // Champs présents dans les données mappées
    final presentFields = <ImportField>{};
    for (final row in preview) {
      presentFields.addAll(row.keys);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Bandeau résumé
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.primaryLight,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.primary.withAlpha(60)),
          ),
          child: Row(
            children: [
              const Icon(Icons.check_circle_rounded,
                  color: AppColors.primary, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: RichText(
                  text: TextSpan(
                    style: AppTextStyles.body,
                    children: [
                      TextSpan(
                        text: '${_numFmt.format(total)} enregistrements détectés',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      TextSpan(
                        text: '  ·  Aperçu des 20 premières lignes ci-dessous',
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Tableau de prévisualisation
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor:
                    WidgetStateProperty.all(AppColors.background),
                columnSpacing: 20,
                columns: presentFields
                    .map((f) => DataColumn(
                          label: Text(
                            importFieldMeta[f]?.label ?? f.name,
                            style: AppTextStyles.bodyBold,
                          ),
                        ))
                    .toList(),
                rows: preview.map((row) {
                  return DataRow(
                    cells: presentFields.map((f) {
                      final val = row[f] ?? '';
                      return DataCell(
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 200),
                          child: Text(
                            val.isEmpty ? '—' : val,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: val.isEmpty
                                  ? AppColors.textSecondary
                                  : null,
                              fontStyle: val.isEmpty
                                  ? FontStyle.italic
                                  : FontStyle.normal,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  );
                }).toList(),
              ),
            ),
          ),
        ),

        if (total > 20) ...[
          const SizedBox(height: 6),
          Text(
            '… et ${_numFmt.format(total - 20)} lignes supplémentaires non affichées.',
            style: AppTextStyles.caption,
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
              onPressed: () =>
                  notifier.retourEtape(WizardStep.columnMapping),
            ),
            const SizedBox(width: 12),
            AppButton(
              label: 'Continuer',
              icon: Icons.navigate_next_rounded,
              onPressed: () => notifier.allerAuResume(),
            ),
          ],
        ),
      ],
    );
  }
}
