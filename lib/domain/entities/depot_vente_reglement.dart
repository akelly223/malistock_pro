/// Une ligne « à régler » : quantité vendue et montant dû à un auteur
/// pour un titre donné, pas encore réglé (voir
/// [[project_depot_vente_auteurs]]). Dérivée des achats fournisseur
/// fantômes `DEP-...` impayés, jamais stockée telle quelle.
class DepotVenteLigneARegulerEntity {
  final int supplierId;
  final String supplierNom;
  final int articleId;
  final String articleCode;
  final String articleNom;
  final double quantiteVendue;
  final double montantDu;

  /// Commission fixe de ce fournisseur (auteur), en % du prix de vente —
  /// permet de dériver [venteTotale] et [commission] sans dupliquer le
  /// calcul déjà fait à la vente.
  final double partAuteurPct;

  const DepotVenteLigneARegulerEntity({
    required this.supplierId,
    required this.supplierNom,
    required this.articleId,
    required this.articleCode,
    required this.articleNom,
    required this.quantiteVendue,
    required this.montantDu,
    required this.partAuteurPct,
  });

  /// Vente totale HT (prix payé par le client), reconstituée à partir de
  /// la part auteur : `montantDu` = venteTotale × partAuteurPct / 100.
  double get venteTotale =>
      partAuteurPct > 0 ? montantDu * 100 / partAuteurPct : 0;

  /// Commission conservée par le commerce sur cette ligne.
  double get commission => venteTotale - montantDu;
}

/// Statut d'un règlement dépôt-vente au moment où il a été enregistré :
/// intégral (tout le montant dû à cet instant a été versé) ou partiel.
enum DepotVenteReglementStatut { partiel, regle }

extension DepotVenteReglementStatutLabel on DepotVenteReglementStatut {
  String get libelle => switch (this) {
        DepotVenteReglementStatut.partiel => 'PARTIELLEMENT RÉGLÉ',
        DepotVenteReglementStatut.regle => 'RÉGLÉ',
      };
}

/// Détail d'un livre concerné par un règlement — snapshot immuable pris
/// au moment du règlement (voir [[project_depot_vente_auteurs]]).
class DepotVenteReglementLigneEntity {
  final int articleId;
  final String articleNom;
  final double quantite;
  final double montantVente;
  final double montantAuteur;

  const DepotVenteReglementLigneEntity({
    required this.articleId,
    required this.articleNom,
    required this.quantite,
    required this.montantVente,
    required this.montantAuteur,
  });

  double get commission => montantVente - montantAuteur;
}

/// Un règlement dépôt-vente confirmé : un clic sur « Marquer comme
/// réglé » pour un auteur, avec le détail des livres concernés et le
/// montant effectivement versé à cet instant. Permanent — jamais
/// supprimé automatiquement.
class DepotVenteReglementEntity {
  final int id;
  final int supplierId;
  final String supplierNom;
  final DateTime dateHeure;
  final double quantiteLivres;

  /// Total dû (part auteur) au moment de ce règlement, avant paiement.
  final double montantDu;

  /// Montant effectivement versé lors de cet évènement.
  final double montantPaye;

  final DepotVenteReglementStatut statut;
  final String? note;
  final List<DepotVenteReglementLigneEntity> lignes;

  const DepotVenteReglementEntity({
    required this.id,
    required this.supplierId,
    required this.supplierNom,
    required this.dateHeure,
    required this.quantiteLivres,
    required this.montantDu,
    required this.montantPaye,
    required this.statut,
    this.note,
    this.lignes = const [],
  });

  double get resteAPayer => (montantDu - montantPaye).clamp(0, montantDu);

  /// Vente totale HT couverte par ce règlement (somme des lignes).
  double get venteTotale =>
      lignes.fold<double>(0, (s, l) => s + l.montantVente);

  /// Commission du commerce sur le montant dû de ce règlement.
  double get commission => venteTotale - montantDu;
}
