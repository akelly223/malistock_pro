import 'package:drift/drift.dart';
import '../database.dart';
import '../tables/commercial_documents_table.dart';
import '../tables/document_lines_table.dart';
import '../tables/document_payments_table.dart';
import '../tables/document_history_table.dart';

part 'commercial_documents_dao.g.dart';

@DriftAccessor(tables: [
  CommercialDocuments,
  DocumentLines,
  DocumentPayments,
  DocumentHistories,
])
class CommercialDocumentsDao extends DatabaseAccessor<AppDatabase>
    with _$CommercialDocumentsDaoMixin {
  CommercialDocumentsDao(super.db);

  // ── Lecture ──────────────────────────────────────────────────────────────

  Future<List<CommercialDocument>> getParType(String type) =>
      (select(commercialDocuments)
            ..where((d) => d.type.equals(type))
            ..orderBy([(d) => OrderingTerm.desc(d.dateDocument)]))
          .get();

  /// Ventes (factures) : les deux états d'une même vente une fois
  /// comptabilisée sont fusionnés en une seule liste. Une facture
  /// 'transforme' a été remplacée par sa comptabilisée (ou un autre
  /// document issu d'une transformation en chaîne) — elle est exclue
  /// pour ne pas afficher deux fois la même vente.
  Future<List<CommercialDocument>> getVentes() => (select(commercialDocuments)
        ..where((d) =>
            d.type.equals('facture_comptabilisee') |
            (d.type.equals('facture') & d.statut.equals('transforme').not()))
        ..orderBy([(d) => OrderingTerm.desc(d.dateDocument)]))
      .get();

  Future<List<CommercialDocument>> getParTypeEtStatut(
          String type, String statut) =>
      (select(commercialDocuments)
            ..where((d) => d.type.equals(type) & d.statut.equals(statut))
            ..orderBy([(d) => OrderingTerm.desc(d.dateDocument)]))
          .get();

  Future<CommercialDocument?> getParId(int id) =>
      (select(commercialDocuments)..where((d) => d.id.equals(id)))
          .getSingleOrNull();

  Future<List<CommercialDocument>> getParClient(int clientId) =>
      (select(commercialDocuments)
            ..where((d) => d.clientId.equals(clientId))
            ..orderBy([(d) => OrderingTerm.desc(d.dateDocument)]))
          .get();

  Future<List<DocumentLine>> getLignesDuDocument(int documentId) =>
      (select(documentLines)
            ..where((l) => l.documentId.equals(documentId))
            ..orderBy([(l) => OrderingTerm.asc(l.position)]))
          .get();

  Future<List<DocumentPayment>> getPaiementsDuDocument(int documentId) =>
      (select(documentPayments)
            ..where((p) => p.documentId.equals(documentId))
            ..orderBy([(p) => OrderingTerm.asc(p.datePaiement)]))
          .get();

  Future<List<DocumentHistoryRecord>> getHistoriqueDuDocument(
          int documentId) =>
      (select(documentHistories)
            ..where((h) => h.documentId.equals(documentId))
            ..orderBy([(h) => OrderingTerm.desc(h.dateAction)]))
          .get();

  /// Retourne les enfants directs d'un document (ex: BL issus d'un BC).
  Future<List<CommercialDocument>> getEnfants(int parentId) =>
      (select(commercialDocuments)
            ..where((d) => d.parentDocumentId.equals(parentId))
            ..orderBy([(d) => OrderingTerm.asc(d.dateDocument)]))
          .get();

  // ── Écriture ─────────────────────────────────────────────────────────────

  /// Crée un document avec ses lignes dans une transaction atomique.
  Future<int> creerAvecLignes(
    CommercialDocumentsCompanion document,
    List<DocumentLinesCompanion> lignes,
  ) {
    return transaction(() async {
      final docId = await into(commercialDocuments).insert(document);
      for (var i = 0; i < lignes.length; i++) {
        await into(documentLines).insert(
          lignes[i].copyWith(documentId: Value(docId), position: Value(i)),
        );
      }
      return docId;
    });
  }

  Future<void> mettreAJourStatut(
    int id,
    String nouveauStatut, {
    String? ancienStatut,
    DateTime? dateValidation,
  }) async {
    await (update(commercialDocuments)..where((d) => d.id.equals(id))).write(
      CommercialDocumentsCompanion(
        statut: Value(nouveauStatut),
        dateModification: Value(DateTime.now()),
        dateValidation: dateValidation != null
            ? Value(dateValidation)
            : const Value.absent(),
      ),
    );
  }

  /// Change le type d'un document sans toucher au reste (statut, montant
  /// payé, paiements...) — utilisé pour "comptabiliser" une facture : ce
  /// n'est pas un nouveau document, seule son type change.
  Future<void> mettreAJourType(int id, String nouveauType) async {
    await (update(commercialDocuments)..where((d) => d.id.equals(id))).write(
      CommercialDocumentsCompanion(
        type: Value(nouveauType),
        dateModification: Value(DateTime.now()),
      ),
    );
  }

  Future<void> mettreAJourTotaux(
    int id, {
    required double totalHt,
    required double totalTva,
    required double totalTtc,
  }) async {
    await (update(commercialDocuments)..where((d) => d.id.equals(id))).write(
      CommercialDocumentsCompanion(
        totalHt: Value(totalHt),
        totalTva: Value(totalTva),
        totalTtc: Value(totalTtc),
        dateModification: Value(DateTime.now()),
      ),
    );
  }

  Future<void> mettreAJourMontantPaye(
      int id, double montantPaye, double totalTtc) async {
    final statut = montantPaye >= totalTtc
        ? 'paye'
        : montantPaye > 0
            ? 'partiel'
            : 'non_paye';
    await (update(commercialDocuments)..where((d) => d.id.equals(id))).write(
      CommercialDocumentsCompanion(
        montantPaye: Value(montantPaye),
        statutPaiement: Value(statut),
      ),
    );
  }

  Future<int> ajouterPaiement(DocumentPaymentsCompanion paiement) =>
      into(documentPayments).insert(paiement);

  Future<void> ajouterHistorique(DocumentHistoriesCompanion entree) =>
      into(documentHistories).insert(entree);

  /// Génère le prochain numéro pour le préfixe donné (ex: 'PRO', 'BL', 'FAC').
  Future<String> genererProchainNumero(String prefixe) =>
      attachedDatabase.documentCountersDao.genererProchainNumero(prefixe);
}
