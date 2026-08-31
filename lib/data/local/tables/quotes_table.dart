import 'package:drift/drift.dart';
import 'clients_table.dart';
import 'stores_table.dart';
import 'articles_table.dart';

/// Table des devis.
///
/// Un devis peut être transformé en facture sans ressaisie
/// (voir InvoiceRepository.createFromQuote).
class Quotes extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// Numéro affiché, ex: DEV-2026-0001.
  TextColumn get numero => text().withLength(min: 1, max: 30).unique()();

  IntColumn get clientId => integer().nullable().references(Clients, #id)();

  IntColumn get storeId => integer().references(Stores, #id)();

  DateTimeColumn get dateCreation =>
      dateTime().withDefault(currentDateAndTime)();

  /// 'en_attente' | 'converti' | 'expire'
  TextColumn get statut => text().withDefault(const Constant('en_attente'))();

  RealColumn get totalHt => real().withDefault(const Constant(0))();

  RealColumn get remiseGlobale => real().withDefault(const Constant(0))();

  RealColumn get totalFinal => real().withDefault(const Constant(0))();
}

/// Lignes d'un devis.
class QuoteItems extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get quoteId => integer().references(Quotes, #id)();

  IntColumn get articleId => integer().references(Articles, #id)();

  RealColumn get quantite => real()();

  RealColumn get prixUnitaire => real()();

  RealColumn get remisePourcentage => real().withDefault(const Constant(0))();

  RealColumn get remiseMontant => real().withDefault(const Constant(0))();

  RealColumn get totalLigne => real()();
}
