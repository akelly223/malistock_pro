import '../entities/depot_vente_stat.dart';
import '../entities/depot_vente_reglement.dart';

abstract class DepotVenteRepository {
  /// Tous les titres en dépôt-vente (articles liés à un fournisseur
  /// `estDepot = true`), avec leurs ventes/bénéfice calculés sur la
  /// période choisie. Filtrable par catégorie et/ou par fournisseur
  /// (auteur/maison d'édition) pour le tri de l'Espace Dépôt-vente.
  Future<List<DepotVenteStatEntity>> getDepotArticlesStats({
    required DepotVentePeriode periode,
    int? categorieId,
    int? supplierId,
  });

  /// Tout ce qui a été vendu pour des auteurs et n'est pas encore réglé,
  /// une ligne par (fournisseur, article). Dérivé des achats fournisseur
  /// fantômes `DEP-...` impayés — aucun filtre serveur par fournisseur :
  /// le tri par auteur se fait côté écran sur cette liste déjà chargée.
  Future<List<DepotVenteLigneARegulerEntity>> getLignesARegler();

  /// Historique permanent des règlements confirmés (jamais supprimé
  /// automatiquement), le plus récent en premier.
  Future<List<DepotVenteReglementEntity>> getHistoriqueReglements();

  /// Règle la dette dépôt-vente d'un fournisseur, en totalité ou en
  /// partie. `montant` null = solder l'intégralité du dû ; sinon, le
  /// montant doit être strictement positif et ne peut excéder le total
  /// dû (le moteur de paiement fournisseur existant applique le montant
  /// en FIFO sur les achats fantômes impayés — voir
  /// `PaymentRepository.registerPaymentForSupplierDebt`). Enregistre un
  /// évènement d'historique avec le détail par livre concerné et une
  /// note optionnelle. Lève une exception si le fournisseur n'a rien à
  /// régler, ou si `montant` est invalide.
  Future<DepotVenteReglementEntity> reglerFournisseur({
    required int supplierId,
    double? montant,
    String? note,
    int? userId,
  });
}
