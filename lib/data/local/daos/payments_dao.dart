import 'package:drift/drift.dart';
import '../database.dart';
import '../tables/payments_table.dart';
import '../tables/client_debts_table.dart';

part 'payments_dao.g.dart';

@DriftAccessor(tables: [Payments, ClientDebts])
class PaymentsDao extends DatabaseAccessor<AppDatabase>
    with _$PaymentsDaoMixin {
  PaymentsDao(super.db);

  Future<List<Payment>> getAllPayments() => (select(payments)
        ..orderBy([(p) => OrderingTerm.desc(p.datePaiement)]))
      .get();

  Future<List<Payment>> getPaymentsForInvoice(int invoiceId) =>
      (select(payments)..where((p) => p.invoiceId.equals(invoiceId))).get();

  Future<List<Payment>> getPaymentsForClient(int clientId) =>
      (select(payments)..where((p) => p.clientId.equals(clientId))).get();

  Future<int> createPayment(PaymentsCompanion payment) =>
      into(payments).insert(payment);

  // ---- Dettes clients ----

  Future<List<ClientDebt>> getDebtsForClient(int clientId) =>
      (select(clientDebts)
            ..where((d) => d.clientId.equals(clientId) & d.solde.equals(false)))
          .get();

  Future<List<ClientDebt>> getAllUnsettledDebts() =>
      (select(clientDebts)..where((d) => d.solde.equals(false))).get();

  Future<int> createClientDebt(ClientDebtsCompanion debt) =>
      into(clientDebts).insert(debt);

  Future<void> updateDebtAmount(int debtId, double nouveauMontant) async {
    final solde = nouveauMontant <= 0;
    await (update(clientDebts)..where((d) => d.id.equals(debtId))).write(
      ClientDebtsCompanion(
        montantDu: Value(nouveauMontant),
        solde: Value(solde),
      ),
    );
  }
}
