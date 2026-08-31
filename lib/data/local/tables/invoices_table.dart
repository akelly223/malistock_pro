import 'package:drift/drift.dart';
import 'clients_table.dart';
import 'stores_table.dart';
import 'articles_table.dart';
import 'quotes_table.dart';
import 'users_table.dart';

/// Table des factures.
class Invoices extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// Numéro affiché, ex: FAC-2026-0001.
  TextColumn get numero => text().withLength(min: 1, max: 30).unique()();

  /// NULL = vente au comptoir sans client enregistré.
  IntColumn get clientId => integer().nullable().references(Clients, #id)();

  IntColumn get storeId => integer().references(Stores, #id)();

  /// Renseigné si la facture provient d'un devis converti.
  IntColumn get quoteId => integer().nullable().references(Quotes, #id)();

  IntColumn get userId => integer().references(Users, #id)();

  DateTimeColumn get dateCreation =>
      dateTime().withDefault(currentDateAndTime)();

  RealColumn get totalHt => real().withDefault(const Constant(0))();

  RealColumn get remiseGlobale => real().withDefault(const Constant(0))();

  RealColumn get totalFinal => real().withDefault(const Constant(0))();

  RealColumn get montantPaye => real().withDefault(const Constant(0))();

  /// 'paye' | 'partiel' | 'non_paye'
  TextColumn get statutPaiement =>
      text().withDefault(const Constant('non_paye'))();

  DateTimeColumn get dateModification => dateTime().nullable()();

  IntColumn get modifieParUserId =>
      integer().nullable().references(Users, #id)();
}

/// Lignes d'une facture.
class InvoiceItems extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get invoiceId => integer().references(Invoices, #id)();

  IntColumn get articleId => integer().references(Articles, #id)();

  RealColumn get quantite => real()();

  RealColumn get prixUnitaire => real()();

  RealColumn get remisePourcentage => real().withDefault(const Constant(0))();

  RealColumn get remiseMontant => real().withDefault(const Constant(0))();

  RealColumn get totalLigne => real()();
}
