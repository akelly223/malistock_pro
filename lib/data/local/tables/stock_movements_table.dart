import 'package:drift/drift.dart';
import 'articles_table.dart';
import 'stores_table.dart';
import 'users_table.dart';

/// Historique complet des mouvements de stock.
///
/// Couvre entrée, sortie, transfert, perte et casse. Chaque vente,
/// transfert ou ajustement de stock génère une ligne ici, permettant
/// une traçabilité totale (module Mouvements de stock).
class StockMovements extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get articleId => integer().references(Articles, #id)();

  IntColumn get storeId => integer().references(Stores, #id)();

  /// 'entree' | 'sortie' | 'transfert' | 'perte' | 'casse'
  TextColumn get typeMouvement => text()();

  RealColumn get quantite => real()();

  /// Référence libre : numéro de facture, motif perte/casse, etc.
  TextColumn get reference => text().nullable()();

  /// Identifiant commun à toutes les lignes créées en une seule fois
  /// depuis le dialogue "Mouvement manuel" (un même lot de réception
  /// dépôt-vente) — permet de les regrouper dans l'historique et de
  /// régénérer le reçu correspondant après coup.
  TextColumn get groupeId => text().nullable()();

  DateTimeColumn get dateMouvement =>
      dateTime().withDefault(currentDateAndTime)();

  IntColumn get userId => integer().references(Users, #id)();
}
