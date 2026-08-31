import 'package:drift/drift.dart';
import 'invoices_table.dart';
import 'purchases_table.dart';
import 'clients_table.dart';
import 'users_table.dart';

/// Table des paiements.
///
/// Un paiement peut être lié à une facture précise ([invoiceId]), à un
/// achat fournisseur précis ([purchaseId]), ou être un règlement
/// global de dette client ([clientId] seul, utilisé pour éponger
/// plusieurs factures impayées).
class Payments extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get invoiceId => integer().nullable().references(Invoices, #id)();

  IntColumn get purchaseId =>
      integer().nullable().references(Purchases, #id)();

  IntColumn get clientId => integer().nullable().references(Clients, #id)();

  RealColumn get montant => real()();

  /// 'especes' | 'orange_money' | 'moov_money' | 'virement' | 'cheque'
  TextColumn get modePaiement => text()();

  DateTimeColumn get datePaiement =>
      dateTime().withDefault(currentDateAndTime)();

  IntColumn get userId => integer().references(Users, #id)();

  /// Numéro du reçu de paiement généré pour ce règlement (ex: REC-2026-0001).
  TextColumn get numeroRecu => text().nullable()();
}
