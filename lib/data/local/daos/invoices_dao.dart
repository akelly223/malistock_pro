import 'package:drift/drift.dart';
import '../database.dart';
import '../tables/invoices_table.dart';

part 'invoices_dao.g.dart';

@DriftAccessor(tables: [Invoices, InvoiceItems])
class InvoicesDao extends DatabaseAccessor<AppDatabase>
    with _$InvoicesDaoMixin {
  InvoicesDao(super.db);

  Future<List<Invoice>> getAllInvoices() => (select(invoices)
        ..orderBy([(i) => OrderingTerm.desc(i.dateCreation)]))
      .get();

  Future<Invoice?> getInvoiceById(int id) =>
      (select(invoices)..where((i) => i.id.equals(id))).getSingleOrNull();

  Future<List<InvoiceItem>> getItemsForInvoice(int invoiceId) =>
      (select(invoiceItems)..where((i) => i.invoiceId.equals(invoiceId)))
          .get();

  Future<List<Invoice>> getInvoicesForClient(int clientId) =>
      (select(invoices)..where((i) => i.clientId.equals(clientId))).get();

  Future<List<Invoice>> getInvoicesBetween(DateTime start, DateTime end) =>
      (select(invoices)
            ..where((i) =>
                i.dateCreation.isBiggerOrEqualValue(start) &
                i.dateCreation.isSmallerThanValue(end)))
          .get();

  Future<List<Invoice>> getUnpaidOrPartialInvoices() => (select(invoices)
        ..where((i) =>
            i.statutPaiement.equals('partiel') |
            i.statutPaiement.equals('non_paye')))
      .get();

  /// Crée une facture avec ses lignes en une seule transaction.
  Future<int> createInvoiceWithItems(
    InvoicesCompanion invoice,
    List<InvoiceItemsCompanion> items,
  ) {
    return transaction(() async {
      final invoiceId = await into(invoices).insert(invoice);
      for (final item in items) {
        await into(invoiceItems)
            .insert(item.copyWith(invoiceId: Value(invoiceId)));
      }
      return invoiceId;
    });
  }

  Future<bool> updateInvoice(Invoice invoice) =>
      update(invoices).replace(invoice);

  /// Remplace les lignes d'une facture et met à jour son en-tête.
  Future<void> updateInvoiceWithItems(
    int invoiceId,
    InvoicesCompanion companion,
    List<InvoiceItemsCompanion> newItems,
  ) {
    return transaction(() async {
      await (delete(invoiceItems)
            ..where((i) => i.invoiceId.equals(invoiceId)))
          .go();
      await (update(invoices)..where((i) => i.id.equals(invoiceId)))
          .write(companion);
      for (final item in newItems) {
        await into(invoiceItems)
            .insert(item.copyWith(invoiceId: Value(invoiceId)));
      }
    });
  }

  /// Met à jour le montant payé et recalcule le statut de paiement.
  Future<void> updateMontantPaye(int invoiceId, double nouveauMontantPaye,
      double totalFinal) async {
    String statut;
    if (nouveauMontantPaye >= totalFinal) {
      statut = 'paye';
    } else if (nouveauMontantPaye > 0) {
      statut = 'partiel';
    } else {
      statut = 'non_paye';
    }
    await (update(invoices)..where((i) => i.id.equals(invoiceId))).write(
      InvoicesCompanion(
        montantPaye: Value(nouveauMontantPaye),
        statutPaiement: Value(statut),
      ),
    );
  }

  /// Génère le prochain numéro séquentiel de facture pour l'année en
  /// cours, ex: FAC-2026-0001. Délègue à un compteur dédié, jamais
  /// décrémenté même si une facture est supprimée, pour garantir
  /// l'unicité du numéro dans le temps (voir DocumentCountersDao).
  Future<String> generateNextNumero() =>
      attachedDatabase.documentCountersDao.genererProchainNumero('FAC');
}
