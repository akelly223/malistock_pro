class PurchaseItemEntity {
  final int id;
  final int purchaseId;
  final int articleId;
  final String articleNom;
  final double quantite;
  final double prixAchatUnitaire;
  final double totalLigne;

  const PurchaseItemEntity({
    required this.id,
    required this.purchaseId,
    required this.articleId,
    required this.articleNom,
    required this.quantite,
    required this.prixAchatUnitaire,
    required this.totalLigne,
  });
}

class PurchaseEntity {
  final int id;
  final String numero;
  final int supplierId;
  final String? supplierNom;
  final String? supplierTelephone;
  final String? supplierAdresse;
  final int storeId;
  final String? storeNom;
  final int userId;
  final String? userNom;
  final DateTime dateCreation;
  final double totalHt;
  final double remiseGlobale;
  final double totalFinal;
  final double montantPaye;
  final String statutPaiement;
  final String statut;
  final DateTime? dateModification;
  final String? modifieParNom;
  final List<PurchaseItemEntity> items;

  const PurchaseEntity({
    required this.id,
    required this.numero,
    required this.supplierId,
    this.supplierNom,
    this.supplierTelephone,
    this.supplierAdresse,
    required this.storeId,
    this.storeNom,
    required this.userId,
    this.userNom,
    required this.dateCreation,
    required this.totalHt,
    required this.remiseGlobale,
    required this.totalFinal,
    required this.montantPaye,
    required this.statutPaiement,
    this.statut = 'recu',
    this.dateModification,
    this.modifieParNom,
    this.items = const [],
  });

  double get resteAPayer => totalFinal - montantPaye;

  bool get estPayee => statutPaiement == 'paye';

  /// true si c'est un bon de commande pas encore réceptionné (stock
  /// non impacté).
  bool get estCommande => statut == 'commande';
}
