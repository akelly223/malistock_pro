import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/providers/repository_providers.dart';
import '../../../data/repositories/commercial_document_repository_impl.dart';
import '../../../domain/repositories/commercial_document_repository.dart';
import '../../../domain/entities/commercial_document.dart';
import '../../../domain/entities/document_type.dart';

// ── Repository ──────────────────────────────────────────────────────────────

final commercialDocumentRepositoryProvider =
    Provider<CommercialDocumentRepository>((ref) {
  return CommercialDocumentRepositoryImpl(ref.watch(databaseProvider));
});

// ── Taux TVA ────────────────────────────────────────────────────────────────

final tvaRatesProvider =
    FutureProvider.autoDispose<List<TvaRateEntity>>((ref) async {
  return ref
      .watch(commercialDocumentRepositoryProvider)
      .getTauxTvaActifs();
});

// ── Listes par type ─────────────────────────────────────────────────────────

final proformasProvider =
    FutureProvider.autoDispose<List<DocumentEntity>>((ref) async {
  return ref
      .watch(commercialDocumentRepositoryProvider)
      .getParType(DocumentType.proforma);
});

final bonsCommandeProvider =
    FutureProvider.autoDispose<List<DocumentEntity>>((ref) async {
  return ref
      .watch(commercialDocumentRepositoryProvider)
      .getParType(DocumentType.bonCommande);
});

final preparationsLivraisonProvider =
    FutureProvider.autoDispose<List<DocumentEntity>>((ref) async {
  return ref
      .watch(commercialDocumentRepositoryProvider)
      .getParType(DocumentType.preparationLivraison);
});

final bonsLivraisonProvider =
    FutureProvider.autoDispose<List<DocumentEntity>>((ref) async {
  return ref
      .watch(commercialDocumentRepositoryProvider)
      .getParType(DocumentType.bonLivraison);
});

final bonsRetourProvider =
    FutureProvider.autoDispose<List<DocumentEntity>>((ref) async {
  return ref
      .watch(commercialDocumentRepositoryProvider)
      .getParType(DocumentType.bonRetour);
});

final avoirsProvider =
    FutureProvider.autoDispose<List<DocumentEntity>>((ref) async {
  return ref
      .watch(commercialDocumentRepositoryProvider)
      .getParType(DocumentType.avoir);
});

/// Liste des ventes : inclut les factures ('facture') et les factures
/// comptabilisées ('facture_comptabilisee'), qui sont la même vente une
/// fois marquée comptabilisée — voir [CommercialDocumentRepository.getVentes].
final facturesV2Provider =
    FutureProvider.autoDispose<List<DocumentEntity>>((ref) async {
  return ref.watch(commercialDocumentRepositoryProvider).getVentes();
});

// ── Document unique (avec lignes et paiements) ───────────────────────────────

final documentParIdProvider =
    FutureProvider.autoDispose.family<DocumentEntity?, int>((ref, id) async {
  return ref.watch(commercialDocumentRepositoryProvider).getParId(id);
});

// ── Documents enfants d'un document ─────────────────────────────────────────

final documentsEnfantsProvider =
    FutureProvider.autoDispose.family<List<DocumentEntity>, int>(
        (ref, parentId) async {
  return ref
      .watch(commercialDocumentRepositoryProvider)
      .getEnfants(parentId);
});

// ── Documents par client ─────────────────────────────────────────────────────

final documentsParClientProvider =
    FutureProvider.autoDispose.family<List<DocumentEntity>, int>(
        (ref, clientId) async {
  return ref
      .watch(commercialDocumentRepositoryProvider)
      .getParClient(clientId);
});
