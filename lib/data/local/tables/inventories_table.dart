import 'package:drift/drift.dart';
import 'stores_table.dart';
import 'categories_table.dart';
import 'users_table.dart';
import 'articles_table.dart';

/// En-tête d'un inventaire physique (module Inventaire).
///
/// Un inventaire porte toujours sur un magasin précis, avec un filtre
/// optionnel par catégorie (base pour l'inventaire tournant / partiel
/// à venir). Les compteurs (nbArticles, nbSansEcart, ...) sont
/// dénormalisés pour un affichage rapide de l'historique sans
/// recalcul à chaque frame.
class Inventories extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// Numéro séquentiel, ex: "INV-2026-0001".
  TextColumn get numero => text().unique()();

  IntColumn get storeId => integer().references(Stores, #id)();

  IntColumn get categorieId =>
      integer().nullable().references(Categories, #id)();

  /// 'brouillon' (comptage en cours) | 'valide' (verrouillé, stock
  /// mis à jour) | 'annule'.
  TextColumn get statut => text().withDefault(const Constant('brouillon'))();

  DateTimeColumn get dateCreation =>
      dateTime().withDefault(currentDateAndTime)();

  DateTimeColumn get dateValidation => dateTime().nullable()();

  IntColumn get createdByUserId => integer().references(Users, #id)();

  IntColumn get validatedByUserId =>
      integer().nullable().references(Users, #id)();

  IntColumn get nbArticles => integer().withDefault(const Constant(0))();

  IntColumn get nbSansEcart => integer().withDefault(const Constant(0))();

  IntColumn get nbAvecEcart => integer().withDefault(const Constant(0))();

  IntColumn get nbIntrouvables => integer().withDefault(const Constant(0))();

  TextColumn get observation => text().nullable()();
}

/// Ligne de comptage d'un inventaire.
///
/// Le code et le nom de l'article sont dupliqués (snapshot) plutôt
/// que lus via jointure à chaque fois : un inventaire validé doit
/// rester lisible même si l'article est renommé ou désactivé plus
/// tard, exactement comme document_lines le fait pour les pièces
/// commerciales.
class InventoryLines extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get inventoryId => integer().references(Inventories, #id)();

  /// Null si le code lu à l'import ne correspond à aucun article
  /// connu (voir [introuvable]).
  IntColumn get articleId =>
      integer().nullable().references(Articles, #id)();

  TextColumn get articleCode => text()();

  TextColumn get articleNom => text()();

  TextColumn get categorieNom => text().nullable()();

  RealColumn get stockTheorique => real()();

  /// Null tant que la ligne n'a pas été comptée (ni import, ni saisie
  /// manuelle).
  RealColumn get stockPhysique => real().nullable()();

  /// stockPhysique - stockTheorique. Null tant que non compté.
  RealColumn get ecart => real().nullable()();

  TextColumn get observation => text().nullable()();

  /// Vrai si cette ligne provient d'un import dont le code ne
  /// correspondait à aucun article du catalogue.
  BoolColumn get introuvable => boolean().withDefault(const Constant(false))();
}
