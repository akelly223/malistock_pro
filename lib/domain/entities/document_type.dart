/// Types de pièces commerciales V2.
enum DocumentType {
  proforma,
  bonCommande,
  preparationLivraison,
  bonLivraison,
  bonRetour,
  avoir,
  facture,
  factureComptabilisee;

  /// Code stocké en base de données.
  String get code => switch (this) {
        DocumentType.proforma => 'proforma',
        DocumentType.bonCommande => 'bon_commande',
        DocumentType.preparationLivraison => 'preparation_livraison',
        DocumentType.bonLivraison => 'bon_livraison',
        DocumentType.bonRetour => 'bon_retour',
        DocumentType.avoir => 'avoir',
        DocumentType.facture => 'facture',
        DocumentType.factureComptabilisee => 'facture_comptabilisee',
      };

  /// Libellé affiché dans l'interface.
  String get libelle => switch (this) {
        DocumentType.proforma => 'Proforma',
        DocumentType.bonCommande => 'Bon de commande',
        DocumentType.preparationLivraison => 'Préparation de livraison',
        DocumentType.bonLivraison => 'Bon de livraison',
        DocumentType.bonRetour => 'Bon de retour',
        DocumentType.avoir => 'Avoir',
        DocumentType.facture => 'Facture',
        DocumentType.factureComptabilisee => 'Facture comptabilisée',
      };

  /// Préfixe de numérotation (ex: 'PRO', 'BC', 'BL', 'FAC').
  String get prefixeNumero => switch (this) {
        DocumentType.proforma => 'PRO',
        DocumentType.bonCommande => 'BC',
        DocumentType.preparationLivraison => 'PL',
        DocumentType.bonLivraison => 'BL',
        DocumentType.bonRetour => 'BR',
        DocumentType.avoir => 'AV',
        DocumentType.facture => 'FAC',
        DocumentType.factureComptabilisee => 'FCO',
      };

  /// Vrai si ce type de pièce impacte le stock à la validation.
  bool get impacteStockValidation => switch (this) {
        DocumentType.bonLivraison => true,  // sortie stock
        DocumentType.bonRetour => true,     // entrée stock
        _ => false,
      };

  /// Vrai si l'impact stock est une sortie (−). Faux = entrée (+).
  bool get estSortieStock => this == DocumentType.bonLivraison;

  static DocumentType fromCode(String code) =>
      DocumentType.values.firstWhere(
        (t) => t.code == code,
        orElse: () => throw ArgumentError('Type de document inconnu : $code'),
      );
}

/// Statuts du cycle de vie d'une pièce commerciale.
enum DocumentStatut {
  brouillon,
  valide,
  transforme,
  annule;

  String get code => switch (this) {
        DocumentStatut.brouillon => 'brouillon',
        DocumentStatut.valide => 'valide',
        DocumentStatut.transforme => 'transforme',
        DocumentStatut.annule => 'annule',
      };

  String get libelle => switch (this) {
        DocumentStatut.brouillon => 'Brouillon',
        DocumentStatut.valide => 'Validé',
        DocumentStatut.transforme => 'Transformé',
        DocumentStatut.annule => 'Annulé',
      };

  bool get estModifiable => this == DocumentStatut.brouillon;
  bool get estActif => this != DocumentStatut.annule;

  static DocumentStatut fromCode(String code) =>
      DocumentStatut.values.firstWhere(
        (s) => s.code == code,
        orElse: () => throw ArgumentError('Statut inconnu : $code'),
      );
}
