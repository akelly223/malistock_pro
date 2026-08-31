import 'package:drift/drift.dart';

/// Compteurs de numérotation séquentielle pour les documents
/// (factures, achats, devis), un par type de document et par année.
///
/// Contrairement à un simple COUNT(*) sur la table des documents, ce
/// compteur n'est JAMAIS décrémenté, même si un document est
/// supprimé : une fois le numéro FAC-2026-0003 attribué, il ne sera
/// plus jamais réutilisé, ce qui garantit qu'un numéro imprimé sur
/// papier ou enregistré en comptabilité reste unique pour toujours.
class DocumentCounters extends Table {
  /// Clé composite sous forme de texte, ex: "FAC-2026", "ACH-2026".
  /// Utiliser une seule colonne texte comme clé primaire est plus
  /// simple ici qu'une clé composite (prefix, annee) pour ce cas
  /// d'usage restreint.
  TextColumn get cle => text()();

  /// Dernier numéro attribué pour ce préfixe et cette année.
  IntColumn get dernierNumero => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {cle};
}
