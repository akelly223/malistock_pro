import 'package:drift/drift.dart';
import 'suppliers_table.dart';
import 'stores_table.dart';
import 'articles_table.dart';
import 'users_table.dart';

/// Table des achats fournisseurs.
///
/// Symétrique à [Invoices] mais le flux de stock est inversé : la
/// validation d'un achat AUGMENTE le stock (entrée) au lieu de le
/// diminuer. Numérotation séquentielle ACH-YYYY-NNNN.
class Purchases extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// Numéro affiché, ex: ACH-2026-0001.
  TextColumn get numero => text().withLength(min: 1, max: 30).unique()();

  IntColumn get supplierId => integer().references(Suppliers, #id)();

  /// Magasin qui reçoit le stock de cet achat.
  IntColumn get storeId => integer().references(Stores, #id)();

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

  /// 'commande' (bon de commande, stock non impacté) | 'recu'
  /// (marchandise réceptionnée, stock impacté). Défaut 'recu' pour
  /// préserver le comportement historique (achat = réception immédiate).
  TextColumn get statut => text().withDefault(const Constant('recu'))();

  /// Date de la dernière modification (null si jamais modifié).
  DateTimeColumn get dateModification => dateTime().nullable()();

  /// Identifiant de l'utilisateur ayant effectué la dernière
  /// modification (null si jamais modifié).
  IntColumn get modifieParUserId =>
      integer().nullable().references(Users, #id)();
}

/// Lignes d'un achat fournisseur.
class PurchaseItems extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get purchaseId => integer().references(Purchases, #id)();

  IntColumn get articleId => integer().references(Articles, #id)();

  RealColumn get quantite => real()();

  RealColumn get prixAchatUnitaire => real()();

  RealColumn get totalLigne => real()();
}
