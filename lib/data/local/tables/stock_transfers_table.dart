import 'package:drift/drift.dart';
import 'articles_table.dart';
import 'stores_table.dart';
import 'users_table.dart';

/// Transferts de stock entre deux magasins (module Transferts de stock).
///
/// Chaque transfert génère également deux lignes dans [StockMovements]
/// (une sortie sur le magasin source, une entrée sur le magasin
/// destination) afin de garder un historique unifié.
class StockTransfers extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get articleId => integer().references(Articles, #id)();

  IntColumn get storeFromId => integer().references(Stores, #id)();

  IntColumn get storeToId => integer().references(Stores, #id)();

  RealColumn get quantite => real()();

  DateTimeColumn get dateTransfert =>
      dateTime().withDefault(currentDateAndTime)();

  IntColumn get userId => integer().references(Users, #id)();

  /// 'effectue' | 'annule'
  TextColumn get statut => text().withDefault(const Constant('effectue'))();
}
