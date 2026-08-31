import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_text_styles.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_formatter.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/document_status_badge.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/permissions/permissions.dart';
import '../../app/providers/session_provider.dart';
import '../../domain/entities/commercial_document.dart';
import '../../domain/entities/document_type.dart';
import 'providers/commercial_document_providers.dart';

/// Retourne le préfixe de route pour un type de document.
String routePrefixPourType(DocumentType type) => switch (type) {
      DocumentType.proforma => '/proformas',
      DocumentType.bonCommande => '/bons-commande',
      DocumentType.preparationLivraison => '/preparations-livraison',
      DocumentType.bonLivraison => '/bons-livraison',
      DocumentType.bonRetour => '/bons-retour',
      DocumentType.avoir => '/avoirs',
      DocumentType.facture ||
      DocumentType.factureComptabilisee =>
        '/factures-v2',
    };

String _titreEcran(DocumentType type) => switch (type) {
      DocumentType.facture || DocumentType.factureComptabilisee => 'Ventes',
      DocumentType.proforma => 'Proformas',
      DocumentType.bonCommande => 'Bons de commande',
      DocumentType.preparationLivraison => 'Préparations',
      DocumentType.bonLivraison => 'Bons de livraison',
      DocumentType.bonRetour => 'Bons de retour',
      DocumentType.avoir => 'Avoirs',
    };

String _labelBoutonCreation(DocumentType type) => switch (type) {
      DocumentType.facture || DocumentType.factureComptabilisee => 'Nouvelle vente',
      DocumentType.proforma => 'Nouveau proforma',
      DocumentType.bonCommande => 'Nouveau bon',
      DocumentType.preparationLivraison => 'Nouvelle préparation',
      DocumentType.bonLivraison => 'Nouveau bon',
      DocumentType.bonRetour => 'Nouveau retour',
      DocumentType.avoir => 'Nouvel avoir',
    };

/// Liste générique des documents commerciaux V2 pour un type donné.
class DocumentsListScreen extends ConsumerWidget {
  final DocumentType type;

  const DocumentsListScreen({super.key, required this.type});

  AsyncValue<List<DocumentEntity>> _provider(WidgetRef ref) {
    switch (type) {
      case DocumentType.proforma:
        return ref.watch(proformasProvider);
      case DocumentType.bonCommande:
        return ref.watch(bonsCommandeProvider);
      case DocumentType.preparationLivraison:
        return ref.watch(preparationsLivraisonProvider);
      case DocumentType.bonLivraison:
        return ref.watch(bonsLivraisonProvider);
      case DocumentType.bonRetour:
        return ref.watch(bonsRetourProvider);
      case DocumentType.avoir:
        return ref.watch(avoirsProvider);
      default:
        return ref.watch(facturesV2Provider);
    }
  }

  static IconData _icone(DocumentType t) => switch (t) {
        DocumentType.proforma => Icons.description_outlined,
        DocumentType.bonCommande => Icons.assignment_outlined,
        DocumentType.preparationLivraison => Icons.inventory_outlined,
        DocumentType.bonLivraison => Icons.local_shipping_outlined,
        DocumentType.bonRetour => Icons.keyboard_return_outlined,
        DocumentType.avoir => Icons.undo_outlined,
        _ => Icons.receipt_long_outlined,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final utilisateur = ref.watch(sessionProvider);
    // Un employé ne voit que les documents dont il est l'auteur — son
    // "historique de ventes" personnel. Un admin voit tout.
    final docsAsync = _provider(ref).whenData((docs) =>
        (utilisateur?.estAdmin ?? false)
            ? docs
            : docs
                .where((d) => Permissions.peutModifierDocument(
                    utilisateur, d.createdById))
                .toList());
    final prefix = routePrefixPourType(type);

    return Scaffold(
      appBar: AppBar(
        title: Text(_titreEcran(type)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: AppButton(
              label: _labelBoutonCreation(type),
              icon: Icons.add_rounded,
              onPressed: () => context.push('$prefix/new'),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: docsAsync.when(
          data: (docs) {
            if (docs.isEmpty) {
              return EmptyState(
                icon: _icone(type),
                message:
                    'Aucun ${type.libelle.toLowerCase()} pour l\'instant.',
              );
            }
            return ListView.separated(
              itemCount: docs.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final doc = docs[index];
                return _DocumentCard(
                  doc: doc,
                  icone: _icone(type),
                  onTap: () => context.push('$prefix/${doc.id}'),
                );
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Erreur : $e')),
        ),
      ),
    );
  }
}

class _DocumentCard extends StatelessWidget {
  final DocumentEntity doc;
  final IconData icone;
  final VoidCallback onTap;

  const _DocumentCard({
    required this.doc,
    required this.icone,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icone, color: AppColors.primary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(doc.numero, style: AppTextStyles.bodyBold),
                    Text(
                      '${doc.clientNom ?? 'Client comptoir'} · ${DateFormatter.formatDate(doc.dateDocument)}',
                      style: AppTextStyles.caption,
                    ),
                  ],
                ),
              ),
              Text(
                CurrencyFormatter.format(doc.totalTtc),
                style: AppTextStyles.bodyBold,
              ),
              const SizedBox(width: 12),
              DocumentStatusBadge(statut: doc.statut, small: true),
            ],
          ),
        ),
      ),
    );
  }
}
