import 'package:drift/drift.dart';
import 'articles_table.dart';

/// Lignes d'une pièce commerciale (modèle Sage LIGNEPIECE).
///
/// [articleCode] et [articleNom] sont dénormalisés au moment de la saisie :
/// ils gardent la valeur exacte imprimée sur le document, même si l'article
/// est modifié ou supprimé par la suite.
class DocumentLines extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// ON DELETE CASCADE : la suppression du document supprime ses lignes.
  IntColumn get documentId => integer().customConstraint(
      'NOT NULL REFERENCES commercial_documents(id) ON DELETE CASCADE')();

  IntColumn get articleId => integer().references(Articles, #id)();

  /// Valeurs figées au moment de la saisie (historique immuable).
  TextColumn get articleCode => text().withLength(min: 1, max: 50)();
  TextColumn get articleNom => text().withLength(min: 1, max: 150)();

  RealColumn get quantite => real()();
  RealColumn get prixUnitaireHt => real()();

  /// Taux TVA en % (ex: 0.0, 18.0). Copié depuis l'article au moment
  /// de la saisie pour permettre la modification ultérieure sans impact.
  RealColumn get tauxTva => real().withDefault(const Constant(18))();

  RealColumn get remiseLignePct => real().withDefault(const Constant(0))();

  // ── Totaux calculés (total_ht = qte × prix_ht × (1 - remise/100)) ────

  RealColumn get totalHt => real().withDefault(const Constant(0))();
  RealColumn get montantTva => real().withDefault(const Constant(0))();
  RealColumn get totalTtc => real().withDefault(const Constant(0))();

  /// Ordre d'affichage dans le document.
  IntColumn get position => integer().withDefault(const Constant(0))();

  TextColumn get notesLigne => text().nullable()();
}
