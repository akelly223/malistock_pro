import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/import/import_config.dart';
import '../../../core/import/import_field.dart';
import '../../../core/import/import_result.dart';
import '../../../core/widgets/app_button.dart';
import '../../../presentation/stores/providers/store_provider.dart';
import '../providers/import_wizard_provider.dart';

final _numFmt = NumberFormat.decimalPattern('fr_FR');

class StepSummary extends ConsumerWidget {
  final ImportEntityType entityType;

  const StepSummary({super.key, required this.entityType});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(importWizardProvider(entityType));
    final notifier = ref.read(importWizardProvider(entityType).notifier);

    final isStockImport = entityType == ImportEntityType.stock;
    final total = state.mappedRows.length;
    final nouveaux = total - state.duplicateKeys.length;
    final doublons = state.duplicateKeys.length;

    // Pour l'import stock, le magasin est obligatoire
    final canImport = isStockImport
        ? state.selectedStoreId != null
        : (!state.importerAvecStock || state.selectedStoreId != null);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Stats ───────────────────────────────────────────────────────────
        if (isStockImport)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _StatTile(
                  label: 'Lignes détectées',
                  value: _numFmt.format(total),
                  color: AppColors.primary,
                  bg: AppColors.primaryLight,
                  icon: Icons.list_alt_rounded,
                ),
                const SizedBox(width: 12),
                _StatTile(
                  label: 'Articles à mettre à jour',
                  value: _numFmt.format(total),
                  color: AppColors.success,
                  bg: AppColors.successLight,
                  icon: Icons.update_rounded,
                ),
              ],
            ),
          )
        else
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _StatTile(
                  label: 'Total détecté',
                  value: _numFmt.format(total),
                  color: AppColors.primary,
                  bg: AppColors.primaryLight,
                  icon: Icons.list_alt_rounded,
                ),
                const SizedBox(width: 12),
                _StatTile(
                  label: 'Nouveaux',
                  value: _numFmt.format(nouveaux),
                  color: AppColors.success,
                  bg: AppColors.successLight,
                  icon: Icons.add_circle_rounded,
                ),
                const SizedBox(width: 12),
                _StatTile(
                  label: 'Déjà existants',
                  value: _numFmt.format(doublons),
                  color: doublons > 0 ? AppColors.warning : AppColors.textSecondary,
                  bg: doublons > 0 ? AppColors.warningLight : AppColors.background,
                  icon: Icons.content_copy_rounded,
                ),
              ],
            ),
          ),

        // ── Section stock import ─────────────────────────────────────────────
        if (isStockImport) ...[
          const SizedBox(height: 24),
          _SectionTitle('Mode de mise à jour', Icons.tune_rounded),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                RadioListTile<StockImportMode>(
                  value: StockImportMode.ajouter,
                  groupValue: state.stockImportMode,
                  onChanged: (v) => notifier.setStockImportMode(v!),
                  title: const Text('Ajouter au stock existant'),
                  subtitle: const Text(
                    'La quantité importée est ajoutée au stock actuel.\n'
                    'Exemple : stock actuel 10 + import 15 = 25',
                    style: AppTextStyles.caption,
                  ),
                  activeColor: AppColors.primary,
                  contentPadding: EdgeInsets.zero,
                ),
                RadioListTile<StockImportMode>(
                  value: StockImportMode.remplacer,
                  groupValue: state.stockImportMode,
                  onChanged: (v) => notifier.setStockImportMode(v!),
                  title: const Text('Remplacer le stock actuel'),
                  subtitle: const Text(
                    'Le stock actuel est remplacé par la quantité importée.\n'
                    'Exemple : stock actuel 10 → import 15 = 15',
                    style: AppTextStyles.caption,
                  ),
                  activeColor: AppColors.primary,
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _SectionTitle('Magasin de destination', Icons.store_rounded),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: _StoreSelector(entityType: entityType),
          ),
        ],

        // ── Section doublons (articles/clients/fournisseurs) ────────────────
        if (!isStockImport && doublons > 0) ...[
          const SizedBox(height: 24),
          _SectionTitle('Gestion des doublons', Icons.content_copy_rounded),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                _RadioDoublon(
                  entityType: entityType,
                  valeur: DuplicateStrategy.ignorer,
                  titre: 'Ignorer les doublons',
                  sousTitre:
                      'Les enregistrements existants ne sont pas modifiés.',
                ),
                _RadioDoublon(
                  entityType: entityType,
                  valeur: DuplicateStrategy.mettreAJour,
                  titre: 'Mettre à jour les existants',
                  sousTitre:
                      'Les données seront remplacées par celles du fichier.',
                ),
                _RadioDoublon(
                  entityType: entityType,
                  valeur: DuplicateStrategy.demanderChaque,
                  titre: 'Choisir pour chaque doublon',
                  sousTitre: 'Définissez une action individuelle ci-dessous.',
                ),
              ],
            ),
          ),

          // Liste individuelle si demanderChaque
          if (state.globalStrategy == DuplicateStrategy.demanderChaque) ...[
            const SizedBox(height: 12),
            _ListeDoublonsIndividuelle(entityType: entityType),
          ],
        ],

        // ── Stock initial (articles uniquement) ──────────────────────────────
        if (!isStockImport &&
            entityType == ImportEntityType.articles &&
            state.mappedRows
                .any((r) => r.containsKey(ImportField.stockInitial))) ...[
          const SizedBox(height: 24),
          _SectionTitle('Stock initial', Icons.inventory_rounded),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                CheckboxListTile(
                  value: state.importerAvecStock,
                  onChanged: (v) =>
                      notifier.setImporterAvecStock(v ?? false),
                  title:
                      const Text('Importer les articles avec leur stock initial'),
                  subtitle: const Text(
                    'Le stock sera créé dans le magasin sélectionné.',
                    style: AppTextStyles.caption,
                  ),
                  activeColor: AppColors.primary,
                  contentPadding: EdgeInsets.zero,
                ),
                if (state.importerAvecStock) ...[
                  const Divider(height: 24),
                  _StoreSelector(entityType: entityType),
                ],
              ],
            ),
          ),
        ],

        if (state.errorMessage != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.dangerLight,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(state.errorMessage!,
                style: AppTextStyles.body.copyWith(color: AppColors.danger)),
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
              onPressed: () => notifier.retourEtape(WizardStep.preview),
            ),
            const SizedBox(width: 12),
            AppButton(
              label:
                  'Importer ${_numFmt.format(total)} ${isStockImport ? 'lignes' : 'enregistrements'}',
              icon: Icons.download_rounded,
              onPressed: canImport ? () => notifier.lancerImport() : null,
            ),
          ],
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final Color bg;
  final IconData icon;
  const _StatTile(
      {required this.label,
      required this.value,
      required this.color,
      required this.bg,
      required this.icon});

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
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

class _SectionTitle extends StatelessWidget {
  final String titre;
  final IconData icon;
  const _SectionTitle(this.titre, this.icon);

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(width: 8),
          Text(titre, style: AppTextStyles.h3),
        ],
      );
}

class _RadioDoublon extends ConsumerWidget {
  final ImportEntityType entityType;
  final DuplicateStrategy valeur;
  final String titre;
  final String sousTitre;

  const _RadioDoublon({
    required this.entityType,
    required this.valeur,
    required this.titre,
    required this.sousTitre,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(importWizardProvider(entityType));
    return RadioListTile<DuplicateStrategy>(
      value: valeur,
      groupValue: state.globalStrategy,
      onChanged: (v) => ref
          .read(importWizardProvider(entityType).notifier)
          .setGlobalStrategy(v!),
      title: Text(titre, style: AppTextStyles.body),
      subtitle: Text(sousTitre, style: AppTextStyles.caption),
      activeColor: AppColors.primary,
      contentPadding: EdgeInsets.zero,
    );
  }
}

class _ListeDoublonsIndividuelle extends ConsumerWidget {
  final ImportEntityType entityType;
  const _ListeDoublonsIndividuelle({required this.entityType});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(importWizardProvider(entityType));
    final doublesRows = state.mappedRows
        .where((r) {
          final id = _identifier(r);
          return state.duplicateKeys.contains(id);
        })
        .take(100) // limiter l'affichage
        .toList();

    return Container(
      decoration: BoxDecoration(
        color: AppColors.warningLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.warning.withAlpha(80)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                const Icon(Icons.warning_amber_rounded,
                    color: AppColors.warning, size: 18),
                const SizedBox(width: 8),
                Text('Action individuelle pour chaque doublon',
                    style: AppTextStyles.bodyBold),
              ],
            ),
          ),
          const Divider(height: 1),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: doublesRows.length,
            separatorBuilder: (_, __) =>
                const Divider(height: 1, indent: 16, endIndent: 16),
            itemBuilder: (_, i) {
              final row = doublesRows[i];
              final id = _identifier(row);
              final strat = state.strategyPerItem[id] ??
                  DuplicateStrategy.ignorer;
              return Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(id,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis),
                    ),
                    const SizedBox(width: 12),
                    DropdownButton<DuplicateStrategy>(
                      value: strat,
                      underline: const SizedBox(),
                      items: const [
                        DropdownMenuItem(
                            value: DuplicateStrategy.ignorer,
                            child: Text('Ignorer')),
                        DropdownMenuItem(
                            value: DuplicateStrategy.mettreAJour,
                            child: Text('Mettre à jour')),
                      ],
                      onChanged: (v) => ref
                          .read(importWizardProvider(entityType).notifier)
                          .setStrategyPerItem(id, v!),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  String _identifier(Map<dynamic, String> row) {
    return (row[ImportField.codeArticle] ??
            row[ImportField.nom] ??
            '')
        .trim();
  }
}

class _StoreSelector extends ConsumerWidget {
  final ImportEntityType entityType;
  const _StoreSelector({required this.entityType});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(importWizardProvider(entityType));
    final storesAsync = ref.watch(storesListProvider);

    return storesAsync.when(
      data: (stores) {
        if (stores.isEmpty) {
          return Text(
            'Aucun magasin disponible. Créez d\'abord un magasin.',
            style: AppTextStyles.caption.copyWith(color: AppColors.danger),
          );
        }
        if (state.selectedStoreId == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ref
                .read(importWizardProvider(entityType).notifier)
                .setSelectedStore(stores.first.id);
          });
        }
        final selected =
            state.selectedStoreId ?? stores.first.id;
        return DropdownButtonFormField<int>(
          value: stores.any((s) => s.id == selected)
              ? selected
              : stores.first.id,
          decoration: const InputDecoration(
            labelText: 'Magasin de destination',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.store_rounded),
          ),
          items: stores
              .map((s) => DropdownMenuItem(value: s.id, child: Text(s.nom)))
              .toList(),
          onChanged: (id) => ref
              .read(importWizardProvider(entityType).notifier)
              .setSelectedStore(id),
        );
      },
      loading: () => const LinearProgressIndicator(),
      error: (e, _) => Text('Erreur : $e'),
    );
  }
}
