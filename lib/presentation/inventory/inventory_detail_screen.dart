import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_text_styles.dart';
import '../../app/providers/session_provider.dart';
import '../../app/providers/repository_providers.dart';
import '../../app/providers/stock_invalidation.dart';
import '../../core/widgets/app_button.dart';
import '../../core/utils/date_formatter.dart';
import '../../core/services/inventory_export_service.dart';
import '../../core/services/inventory_import_service.dart';
import '../../core/services/inventory_pdf_service.dart';
import '../../domain/entities/inventory.dart';
import '../settings/providers/settings_provider.dart';
import 'providers/inventory_provider.dart';
import 'widgets/inventory_summary_bar.dart';

/// Écran de comptage d'un inventaire : export de la feuille, import
/// du fichier complété, corrections manuelles ligne par ligne, puis
/// validation (mise à jour du stock + mouvement de stock tracé). Une
/// fois validé, l'écran passe en lecture seule et propose
/// impression/export PDF du rapport.
class InventoryDetailScreen extends ConsumerStatefulWidget {
  final int inventoryId;
  const InventoryDetailScreen({super.key, required this.inventoryId});

  @override
  ConsumerState<InventoryDetailScreen> createState() =>
      _InventoryDetailScreenState();
}

class _InventoryDetailScreenState extends ConsumerState<InventoryDetailScreen> {
  bool _isBusy = false;

  void _invalidate() {
    ref.invalidate(inventoryDetailProvider(widget.inventoryId));
    ref.invalidate(inventoryLinesProvider(widget.inventoryId));
    ref.invalidate(inventoriesListProvider);
  }

  void _erreur(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _exporterExcel(
      InventoryEntity inv, List<InventoryLineEntity> lignes) async {
    setState(() => _isBusy = true);
    try {
      final path = await FilePicker.platform.saveFile(
        dialogTitle: 'Enregistrer la feuille d\'inventaire',
        fileName: '${InventoryExportService.nomFichierSuggere(inv)}.xlsx',
        allowedExtensions: ['xlsx'],
      );
      if (path == null) return;
      final bytes = await InventoryExportService.xlsxBytes(inv, lignes);
      await File(path).writeAsBytes(bytes, flush: true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Feuille enregistrée : $path')));
      }
    } catch (e) {
      _erreur('Erreur export Excel : $e');
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _exporterCsv(
      InventoryEntity inv, List<InventoryLineEntity> lignes) async {
    setState(() => _isBusy = true);
    try {
      final path = await FilePicker.platform.saveFile(
        dialogTitle: 'Enregistrer la feuille d\'inventaire',
        fileName: '${InventoryExportService.nomFichierSuggere(inv)}.csv',
        allowedExtensions: ['csv'],
      );
      if (path == null) return;
      final content = await InventoryExportService.csvContent(inv, lignes);
      await File(path).writeAsString(content, flush: true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Feuille enregistrée : $path')));
      }
    } catch (e) {
      _erreur('Erreur export CSV : $e');
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _importerFichier() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'csv', 'txt'],
      dialogTitle: 'Sélectionner le fichier de comptage complété',
    );
    if (result == null || result.files.single.path == null) return;

    setState(() => _isBusy = true);
    try {
      final parse =
          await InventoryImportService.parseFichier(result.files.single.path!);
      final resume =
          await ref.read(inventoryRepositoryProvider).importerComptage(
                inventoryId: widget.inventoryId,
                rows: parse.rows,
              );
      _invalidate();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(
          '${resume.lignesMisesAJour} ligne(s) mise(s) à jour'
          '${resume.nouvellesLignes > 0 ? ', ${resume.nouvellesLignes} nouvelle(s)' : ''}'
          '${resume.codesIntrouvables.isNotEmpty ? ', ${resume.codesIntrouvables.length} code(s) introuvable(s)' : ''}.',
        )));
      }
    } catch (e) {
      _erreur('Erreur import : $e');
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _corrigerLigne(InventoryLineEntity ligne) async {
    final controllerPhysique = TextEditingController(
        text: ligne.stockPhysique?.toStringAsFixed(0) ?? '');
    final controllerObservation =
        TextEditingController(text: ligne.observation ?? '');

    final confirme = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(ligne.articleNom),
        content: SizedBox(
          width: 380,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                  'Code : ${ligne.articleCode}  ·  Théorique : ${ligne.stockTheorique.toStringAsFixed(0)}',
                  style: AppTextStyles.caption),
              const SizedBox(height: 16),
              TextField(
                controller: controllerPhysique,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                    labelText: 'Stock physique', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controllerObservation,
                decoration: const InputDecoration(
                    labelText: 'Observation', border: OutlineInputBorder()),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annuler')),
          AppButton(
              label: 'Enregistrer',
              onPressed: () => Navigator.pop(context, true)),
        ],
      ),
    );

    if (confirme != true) return;
    final physique =
        double.tryParse(controllerPhysique.text.replaceAll(',', '.'));
    await ref.read(inventoryRepositoryProvider).corrigerLigne(
          lineId: ligne.id,
          stockPhysique: physique,
          observation: controllerObservation.text.isEmpty
              ? null
              : controllerObservation.text,
        );
    _invalidate();
  }

  Future<void> _validerInventaire(InventoryEntity inv) async {
    final confirme = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Valider l\'inventaire ?'),
        content: Text(
          'Le stock des ${inv.nbAvecEcart} article(s) en écart sera mis à '
          'jour et un mouvement de stock "Inventaire" sera créé pour '
          'chacun. Cette action est irréversible.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annuler')),
          AppButton(
              label: 'Valider', onPressed: () => Navigator.pop(context, true)),
        ],
      ),
    );
    if (confirme != true) return;

    setState(() => _isBusy = true);
    try {
      final user = ref.read(sessionProvider);
      await ref.read(inventoryRepositoryProvider).validerInventaire(
            inventoryId: widget.inventoryId,
            userId: user?.id ?? 0,
          );
      _invalidate();
      invalidateStockDependentProviders(ref);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Inventaire validé, stock mis à jour.')));
      }
    } catch (e) {
      _erreur('Erreur validation : $e');
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _imprimerPdf(
      InventoryEntity inv, List<InventoryLineEntity> lignes) async {
    setState(() => _isBusy = true);
    try {
      final settings = await ref.read(appSettingsProvider.future);
      await InventoryPdfService.print(
          inventaire: inv, lignes: lignes, settings: settings);
    } catch (e) {
      _erreur('Erreur impression : $e');
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _exporterPdf(
      InventoryEntity inv, List<InventoryLineEntity> lignes) async {
    setState(() => _isBusy = true);
    try {
      final settings = await ref.read(appSettingsProvider.future);
      final path = await InventoryPdfService.generateAndSave(
          inventaire: inv, lignes: lignes, settings: settings);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('PDF enregistré : $path')));
      }
    } catch (e) {
      _erreur('Erreur export PDF : $e');
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final inventaireAsync =
        ref.watch(inventoryDetailProvider(widget.inventoryId));
    final lignesAsync = ref.watch(inventoryLinesProvider(widget.inventoryId));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(inventaireAsync.valueOrNull?.numero ?? 'Inventaire'),
        leading: BackButton(onPressed: () => context.pop()),
      ),
      body: inventaireAsync.when(
        data: (inv) {
          if (inv == null) {
            return const Center(child: Text('Inventaire introuvable.'));
          }
          return lignesAsync.when(
            data: (lignes) => _buildBody(inv, lignes),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Erreur : $e')),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erreur : $e')),
      ),
    );
  }

  Widget _buildBody(InventoryEntity inv, List<InventoryLineEntity> lignes) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildEntete(inv),
          const SizedBox(height: 16),
          InventorySummaryBar(inventaire: inv),
          const SizedBox(height: 16),
          _buildActions(inv, lignes),
          const SizedBox(height: 20),
          Text('Lignes (${lignes.length})', style: AppTextStyles.h3),
          const SizedBox(height: 8),
          _buildTableHeader(),
          Expanded(
            child: lignes.isEmpty
                ? const Center(child: Text('Aucune ligne.'))
                : Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.border),
                      borderRadius: const BorderRadius.vertical(
                          bottom: Radius.circular(8)),
                    ),
                    child: ListView.builder(
                      itemCount: lignes.length,
                      itemBuilder: (context, i) => _LigneTile(
                        ligne: lignes[i],
                        modifiable: inv.estModifiable,
                        onTap: inv.estModifiable
                            ? () => _corrigerLigne(lignes[i])
                            : null,
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEntete(InventoryEntity inv) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Magasin : ${inv.storeNom}', style: AppTextStyles.bodyBold),
              if (inv.categorieNom != null)
                Text('Catégorie : ${inv.categorieNom}',
                    style: AppTextStyles.caption),
              Text(
                  'Créé par ${inv.createdByNom ?? '—'} le '
                  '${DateFormatter.formatDateTime(inv.dateCreation)}',
                  style: AppTextStyles.caption),
              if (inv.dateValidation != null)
                Text(
                    'Validé par ${inv.validatedByNom ?? '—'} le '
                    '${DateFormatter.formatDateTime(inv.dateValidation!)}',
                    style: AppTextStyles.caption),
            ],
          ),
          _badgeStatut(inv.statut),
        ],
      ),
    );
  }

  Widget _badgeStatut(String statut) {
    final (couleur, libelle) = switch (statut) {
      'valide' => (AppColors.success, 'Validé'),
      'annule' => (AppColors.textSecondary, 'Annulé'),
      _ => (AppColors.warning, 'Brouillon'),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
          color: couleur.withAlpha(30), borderRadius: BorderRadius.circular(20)),
      child: Text(libelle,
          style: TextStyle(color: couleur, fontWeight: FontWeight.w700)),
    );
  }

  Widget _buildActions(InventoryEntity inv, List<InventoryLineEntity> lignes) {
    if (!inv.estModifiable) {
      return Wrap(spacing: 12, runSpacing: 12, children: [
        AppButton(
            label: 'Imprimer',
            icon: Icons.print_rounded,
            isOutlined: true,
            isLoading: _isBusy,
            onPressed: () => _imprimerPdf(inv, lignes)),
        AppButton(
            label: 'Exporter en PDF',
            icon: Icons.picture_as_pdf_rounded,
            isLoading: _isBusy,
            onPressed: () => _exporterPdf(inv, lignes)),
      ]);
    }
    return Wrap(spacing: 12, runSpacing: 12, children: [
      AppButton(
          label: 'Exporter Excel',
          icon: Icons.grid_on_rounded,
          isOutlined: true,
          isLoading: _isBusy,
          onPressed: () => _exporterExcel(inv, lignes)),
      AppButton(
          label: 'Exporter CSV',
          icon: Icons.description_rounded,
          isOutlined: true,
          isLoading: _isBusy,
          onPressed: () => _exporterCsv(inv, lignes)),
      AppButton(
          label: 'Importer le comptage',
          icon: Icons.upload_file_rounded,
          isLoading: _isBusy,
          onPressed: _importerFichier),
      AppButton(
          label: 'Valider l\'inventaire',
          icon: Icons.check_circle_rounded,
          isLoading: _isBusy,
          onPressed: () => _validerInventaire(inv)),
    ]);
  }

  Widget _buildTableHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
      ),
      child: const Row(
        children: [
          Expanded(flex: 3, child: Text('Article', style: AppTextStyles.caption)),
          Expanded(
              flex: 2,
              child: Text('Théorique',
                  style: AppTextStyles.caption, textAlign: TextAlign.right)),
          Expanded(
              flex: 2,
              child: Text('Physique',
                  style: AppTextStyles.caption, textAlign: TextAlign.right)),
          Expanded(
              flex: 2,
              child: Text('Écart',
                  style: AppTextStyles.caption, textAlign: TextAlign.right)),
          Expanded(
              flex: 3, child: Text('Observation', style: AppTextStyles.caption)),
        ],
      ),
    );
  }
}

class _LigneTile extends StatelessWidget {
  final InventoryLineEntity ligne;
  final bool modifiable;
  final VoidCallback? onTap;

  const _LigneTile({required this.ligne, required this.modifiable, this.onTap});

  @override
  Widget build(BuildContext context) {
    final ecart = ligne.ecart;
    final couleurEcart = ligne.introuvable || ecart == null
        ? AppColors.textSecondary
        : ecart == 0
            ? AppColors.success
            : (ecart > 0 ? AppColors.primary : AppColors.danger);

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.border)),
        ),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(ligne.articleNom,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodyBold),
                  Text(
                    '${ligne.articleCode}'
                    '${ligne.categorieNom != null ? ' · ${ligne.categorieNom}' : ''}'
                    '${ligne.introuvable ? ' · introuvable' : ''}',
                    style: AppTextStyles.caption.copyWith(
                        color: ligne.introuvable
                            ? AppColors.danger
                            : AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            Expanded(
                flex: 2,
                child: Text(ligne.stockTheorique.toStringAsFixed(0),
                    textAlign: TextAlign.right)),
            Expanded(
                flex: 2,
                child: Text(ligne.stockPhysique?.toStringAsFixed(0) ?? '—',
                    textAlign: TextAlign.right)),
            Expanded(
              flex: 2,
              child: Text(
                ecart == null
                    ? '—'
                    : '${ecart > 0 ? '+' : ''}${ecart.toStringAsFixed(0)}',
                textAlign: TextAlign.right,
                style:
                    TextStyle(color: couleurEcart, fontWeight: FontWeight.w700),
              ),
            ),
            Expanded(
              flex: 3,
              child: Text(ligne.observation ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption),
            ),
            if (modifiable)
              const Icon(Icons.edit_rounded,
                  size: 16, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}
