/// Constantes liées à la base de données et aux règles métier.
class DbConstants {
  DbConstants._();

  static const String dbFileName = 'malistock_pro.sqlite';

  // Rôles utilisateurs
  static const String roleAdmin = 'admin';
  static const String roleEmploye = 'employe';

  // Statuts devis
  static const String quoteStatusEnAttente = 'en_attente';
  static const String quoteStatusConverti = 'converti';
  static const String quoteStatusExpire = 'expire';

  // Statuts paiement facture
  static const String invoiceStatusPaye = 'paye';
  static const String invoiceStatusPartiel = 'partiel';
  static const String invoiceStatusNonPaye = 'non_paye';

  // Statuts d'un achat fournisseur : 'commande' (bon de commande, stock
  // non impacté) ou 'recu' (marchandise réceptionnée, stock impacté).
  static const String purchaseStatutCommande = 'commande';
  static const String purchaseStatutRecu = 'recu';

  // Modes de paiement
  static const String paymentEspeces = 'especes';
  static const String paymentOrangeMoney = 'orange_money';
  static const String paymentMoovMoney = 'moov_money';
  static const String paymentVirement = 'virement';
  static const String paymentCheque = 'cheque';

  // Types de mouvement de stock
  static const String movementEntree = 'entree';
  static const String movementSortie = 'sortie';
  static const String movementTransfert = 'transfert';
  static const String movementPerte = 'perte';
  static const String movementCasse = 'casse';
  static const String movementInventaire = 'inventaire';

  // Statuts transfert
  static const String transferStatusEffectue = 'effectue';
  static const String transferStatusAnnule = 'annule';

  // Préfixes numérotation
  static const String invoicePrefix = 'FAC';
  static const String quotePrefix = 'DEV';
  static const String inventoryPrefix = 'INV';

  // Statuts inventaire
  static const String inventoryStatusBrouillon = 'brouillon';
  static const String inventoryStatusValide = 'valide';
  static const String inventoryStatusAnnule = 'annule';
}
