/// Statistique d'un titre en dépôt-vente sur une période donnée, pour
/// l'Espace Dépôt-vente (voir [[project_depot_vente_auteurs]]).
///
/// Séparé de [ArticleEntity]/[DashboardStatsEntity] : le tableau de
/// bord général n'affiche jamais ces chiffres, et cet espace ne
/// remonte jamais dans le tableau de bord.
class DepotVenteStatEntity {
  final int articleId;
  final String code;
  final String nom;
  final double prixVente;
  final double stockTotal;
  final int? categorieId;
  final String? categorieNom;
  final int supplierId;
  final String supplierNom;

  /// Pourcentage du prix de vente reversé au fournisseur (auteur ou
  /// maison d'édition), fixe par fournisseur.
  final double partAuteurPct;

  /// Quantité vendue sur la période sélectionnée.
  final double quantiteVendue;

  /// Chiffre d'affaires HT généré sur la période sélectionnée.
  final double caHt;

  const DepotVenteStatEntity({
    required this.articleId,
    required this.code,
    required this.nom,
    required this.prixVente,
    required this.stockTotal,
    this.categorieId,
    this.categorieNom,
    required this.supplierId,
    required this.supplierNom,
    required this.partAuteurPct,
    required this.quantiteVendue,
    required this.caHt,
  });

  /// Part reversée au fournisseur sur la période.
  double get partReversee => caHt * partAuteurPct / 100;

  /// Bénéfice réel du commerce sur la période (ce qui reste après
  /// reversement au fournisseur).
  double get beneficeLibrairie => caHt - partReversee;
}

/// Période de calcul pour l'Espace Dépôt-vente — indépendante de
/// [DashboardPeriode] pour ne pas coupler ce module au tableau de bord
/// général qu'il est justement censé ne pas alimenter.
enum DepotVentePeriode { tout, mois, annee }

extension DepotVentePeriodeLabel on DepotVentePeriode {
  String get libelle => switch (this) {
        DepotVentePeriode.tout => 'Depuis le début',
        DepotVentePeriode.mois => 'Ce mois',
        DepotVentePeriode.annee => 'Cette année',
      };
}
