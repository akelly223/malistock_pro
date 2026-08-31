class QuoteItemEntity {
  final int id;
  final int quoteId;
  final int articleId;
  final String articleNom;
  final double quantite;
  final double prixUnitaire;
  final double remisePourcentage;
  final double remiseMontant;
  final double totalLigne;

  const QuoteItemEntity({
    required this.id,
    required this.quoteId,
    required this.articleId,
    required this.articleNom,
    required this.quantite,
    required this.prixUnitaire,
    required this.remisePourcentage,
    required this.remiseMontant,
    required this.totalLigne,
  });
}

class QuoteEntity {
  final int id;
  final String numero;
  final int? clientId;
  final String? clientNom;
  final int storeId;
  final DateTime dateCreation;
  final String statut; // 'en_attente' | 'converti' | 'expire'
  final double totalHt;
  final double remiseGlobale;
  final double totalFinal;
  final List<QuoteItemEntity> items;

  const QuoteEntity({
    required this.id,
    required this.numero,
    this.clientId,
    this.clientNom,
    required this.storeId,
    required this.dateCreation,
    required this.statut,
    required this.totalHt,
    required this.remiseGlobale,
    required this.totalFinal,
    this.items = const [],
  });

  bool get estConverti => statut == 'converti';
}
