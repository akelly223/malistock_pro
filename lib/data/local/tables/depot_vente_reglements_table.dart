import 'package:drift/drift.dart';
import 'suppliers_table.dart';
import 'users_table.dart';

/// Journal des règlements dépôt-vente : un règlement = un clic sur
/// « Marquer comme réglé » pour un auteur, qui solde d'un coup tous ses
/// achats fournisseur fantômes `DEP-...` impayés (voir
/// [[project_depot_vente_auteurs]]). Ne duplique aucune donnée de vente :
/// seulement un total figé, pour donner à l'historique un évènement daté
/// unique au lieu de N reçus épars difficiles à regrouper à l'affichage.
class DepotVenteReglements extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get supplierId => integer().references(Suppliers, #id)();

  DateTimeColumn get dateHeure =>
      dateTime().withDefault(currentDateAndTime)();

  RealColumn get quantiteLivres => real()();

  /// Total dû (part auteur) au moment du clic « Marquer comme réglé »,
  /// avant application de ce paiement — permet de calculer le statut
  /// (réglé / partiellement réglé) de cet évènement précis, indépendamment
  /// du solde live qui continue d'évoluer avec les ventes suivantes.
  RealColumn get montantDu => real().withDefault(const Constant(0))();

  /// Montant réellement versé lors de cet évènement — peut être inférieur
  /// à [montantDu] pour un règlement partiel (voir
  /// [[project_depot_vente_auteurs]]).
  RealColumn get montantPaye => real()();

  /// 'regle' ou 'partiel' — voir [DbConstants] pour le vocabulaire déjà
  /// utilisé côté factures (invoiceStatusPartiel).
  TextColumn get statut => text().withDefault(const Constant('regle'))();

  TextColumn get note => text().nullable()();

  IntColumn get userId => integer().nullable().references(Users, #id)();
}
