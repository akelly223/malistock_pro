import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_text_styles.dart';
import '../../app/providers/repository_providers.dart';
import '../../app/providers/session_provider.dart';
import '../../core/services/catalog_export_service.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/access_denied_view.dart';
import '../../core/permissions/permissions.dart';
import '../../domain/entities/supplier.dart';

final suppliersListProvider =
    FutureProvider.autoDispose<List<SupplierEntity>>((ref) async {
  final repo = ref.watch(supplierRepositoryProvider);
  return repo.getAllSuppliers();
});

final supplierByIdProvider =
    FutureProvider.autoDispose.family<SupplierEntity?, int>((ref, id) async {
  final repo = ref.watch(supplierRepositoryProvider);
  return repo.getSupplierById(id);
});

class SuppliersListScreen extends ConsumerStatefulWidget {
  const SuppliersListScreen({super.key});

  @override
  ConsumerState<SuppliersListScreen> createState() =>
      _SuppliersListScreenState();
}

class _SuppliersListScreenState extends ConsumerState<SuppliersListScreen> {
  bool _isExporting = false;

  Future<void> _exporterCsv(List<SupplierEntity> suppliers) async {
    setState(() => _isExporting = true);
    try {
      final path = await FilePicker.platform.saveFile(
        dialogTitle: 'Enregistrer la liste des fournisseurs',
        fileName:
            '${CatalogExportService.nomFichierSuggere('fournisseurs')}.csv',
        allowedExtensions: ['csv'],
      );
      if (path == null) return;
      final content = await CatalogExportService.suppliersCsv(suppliers);
      await File(path).writeAsString(content, flush: true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Liste enregistrée : $path')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erreur export CSV : $e')));
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _afficherFormulaire(
      BuildContext context, WidgetRef ref, SupplierEntity? existant) async {
    final nomController = TextEditingController(text: existant?.nom);
    final telController = TextEditingController(text: existant?.telephone);
    final adresseController = TextEditingController(text: existant?.adresse);

    final confirme = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(existant == null
              ? 'Nouveau fournisseur'
              : 'Modifier le fournisseur'),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppTextField(label: 'Nom', controller: nomController),
                const SizedBox(height: 12),
                AppTextField(label: 'Téléphone', controller: telController),
                const SizedBox(height: 12),
                AppTextField(label: 'Adresse', controller: adresseController),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => context.pop(false),
                child: const Text('Annuler')),
            AppButton(
                label: 'Enregistrer', onPressed: () => context.pop(true)),
          ],
        ),
      ),
    );

    if (confirme == true && nomController.text.trim().isNotEmpty) {
      final repo = ref.read(supplierRepositoryProvider);
      if (existant == null) {
        await repo.createSupplier(
          nom: nomController.text.trim(),
          telephone: telController.text.trim().isEmpty
              ? null
              : telController.text.trim(),
          adresse: adresseController.text.trim().isEmpty
              ? null
              : adresseController.text.trim(),
        );
      } else {
        await repo.updateSupplier(SupplierEntity(
          id: existant.id,
          nom: nomController.text.trim(),
          telephone: telController.text.trim(),
          adresse: adresseController.text.trim(),
          dateCreation: existant.dateCreation,
        ));
      }
      ref.invalidate(suppliersListProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final utilisateur = ref.watch(sessionProvider);
    if (!Permissions.peutVoirFournisseurs(utilisateur)) {
      return const AccessDeniedView(titre: 'Fournisseurs');
    }

    final suppliersAsync = ref.watch(suppliersListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Fournisseurs'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: AppButton(
              label: 'Exporter CSV',
              icon: Icons.file_download_outlined,
              isOutlined: true,
              isLoading: _isExporting,
              onPressed: suppliersAsync.valueOrNull == null ||
                      suppliersAsync.value!.isEmpty
                  ? null
                  : () => _exporterCsv(suppliersAsync.value!),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: AppButton(
              label: 'Nouveau fournisseur',
              icon: Icons.add_rounded,
              onPressed: () => _afficherFormulaire(context, ref, null),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: suppliersAsync.when(
          data: (suppliers) {
            if (suppliers.isEmpty) {
              return const EmptyState(
                icon: Icons.local_shipping_outlined,
                message: 'Aucun fournisseur enregistré.',
              );
            }
            return ListView.separated(
              itemCount: suppliers.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final s = suppliers[index];
                return Material(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => context.push('/suppliers/${s.id}'),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(s.nom, style: AppTextStyles.bodyBold),
                                if (s.telephone != null)
                                  Text(s.telephone!,
                                      style: AppTextStyles.caption),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit_outlined),
                            onPressed: () =>
                                _afficherFormulaire(context, ref, s),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Erreur: $e')),
        ),
      ),
    );
  }
}
