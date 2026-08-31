import 'package:drift/drift.dart';
import 'depot_vente_reglements_table.dart';
import 'articles_table.dart';

/// Détail par livre d'un règlement dépôt-vente : snapshot immuable pris au
/// moment du clic « Marquer comme réglé », pour que l'historique et le reçu
/// PDF restent corrects même après que les achats fournisseur fantômes
/// `DEP-...` sous-jacents changent de statut de paiement (voir
/// [[project_depot_vente_auteurs]]).
class DepotVenteReglementLignes extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get reglementId =>
      integer().references(DepotVenteReglements, #id)();

  IntColumn get articleId => integer().references(Articles, #id)();

  TextColumn get articleNom => text()();

  RealColumn get quantite => real()();

  /// Vente totale HT de cet article dans ce règlement (dérivée de
  /// montantAuteur / partAuteurPct au moment du règlement).
  RealColumn get montantVente => real()();

  /// Part reversée à l'auteur pour cet article dans ce règlement.
  RealColumn get montantAuteur => real()();
}
