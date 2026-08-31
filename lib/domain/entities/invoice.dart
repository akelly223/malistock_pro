class InvoiceItemEntity {
  final int id;
  final int invoiceId;
  final int articleId;
  final String articleNom;
  final double quantite;
  final double prixUnitaire;
  final double remisePourcentage;
  final double remiseMontant;
  final double totalLigne;

  const InvoiceItemEntity({
    required this.id,
    required this.invoiceId,
    required this.articleId,
    required this.articleNom,
    required this.quantite,
    required this.prixUnitaire,
    required this.remisePourcentage,
    required this.remiseMontant,
    required this.totalLigne,
  });
}

class InvoiceEntity {
  final int id;
  final String numero;
  final int? clientId;
  final String? clientNom;
  final String? clientTelephone;
  final String? clientAdresse;
  final String? clientNif;
  final int storeId;
  final String? storeNom;
  final int? quoteId;
  final int userId;
  final String? userNom;
  final DateTime dateCreation;
  final double totalHt;
  final double remiseGlobale;
  final double totalFinal;
  final double montantPaye;
  final String statutPaiement; // 'paye' | 'partiel' | 'non_paye'
  final List<InvoiceItemEntity> items;
  final DateTime? dateModification;
  final String? modifieParNom;

  const InvoiceEntity({
    required this.id,
    required this.numero,
    this.clientId,
    this.clientNom,
    this.clientTelephone,
    this.clientAdresse,
    this.clientNif,
    required this.storeId,
    this.storeNom,
    this.quoteId,
    required this.userId,
    this.userNom,
    required this.dateCreation,
    required this.totalHt,
    required this.remiseGlobale,
    required this.totalFinal,
    required this.montantPaye,
    required this.statutPaiement,
    this.items = const [],
    this.dateModification,
    this.modifieParNom,
  });

  double get resteAPayer => totalFinal - montantPaye;

  bool get estPayee => statutPaiement == 'paye';

  /// Nombre de lignes distinctes (références d'articles) sur la
  /// facture, pour le résumé "informations importantes".
  int get nombreArticlesDistincts => items.length;

  /// Quantité totale d'unités vendues, toutes lignes confondues.
  double get quantiteTotale =>
      items.fold<double>(0, (sum, item) => sum + item.quantite);
}
