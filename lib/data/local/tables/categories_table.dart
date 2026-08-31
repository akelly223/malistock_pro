import 'package:drift/drift.dart';

/// Table des catégories d'articles.
class Categories extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get nom => text().withLength(min: 1, max: 100).unique()();
}
