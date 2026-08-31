import 'package:drift/drift.dart';
import 'clients_table.dart';
import 'invoices_table.dart';

/// Historique des dettes générées par facture.
///
/// Une ligne est créée à chaque facture non totalement payée et
/// marquée [solde] = true lorsque le montant dû atteint zéro.
class ClientDebts extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get clientId => integer().references(Clients, #id)();

  IntColumn get invoiceId => integer().references(Invoices, #id)();

  RealColumn get montantDu => real()();

  DateTimeColumn get dateCreation =>
      dateTime().withDefault(currentDateAndTime)();

  BoolColumn get solde => boolean().withDefault(const Constant(false))();
}
