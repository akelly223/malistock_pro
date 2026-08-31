/// Reçu de paiement : preuve imprimable d'un règlement (vente ou achat),
/// qu'il vienne d'une facture V2, d'une facture V1 ou d'un achat
/// fournisseur. "Montant payé avant" et "nouveau reste" sont calculés à
/// partir de l'historique chronologique des paiements du document
/// concerné, pas depuis son total courant — réimprimer un ancien reçu
/// reste donc exact même après des paiements ultérieurs.
class PaymentReceiptEntity {
  final String source;
  final int paymentId;
  final String numeroRecu;
  final DateTime datePaiement;

  /// 'vente' | 'achat'
  final String typePaiement;

  final String tiersNom;
  final String numeroDocument;
  final double montantTotalDocument;
  final double montantPayeAvant;
  final double montantRecu;
  final String modePaiement;
  final String? utilisateur;

  const PaymentReceiptEntity({
    required this.source,
    required this.paymentId,
    required this.numeroRecu,
    required this.datePaiement,
    required this.typePaiement,
    required this.tiersNom,
    required this.numeroDocument,
    required this.montantTotalDocument,
    required this.montantPayeAvant,
    required this.montantRecu,
    required this.modePaiement,
    this.utilisateur,
  });

  double get nouveauReste =>
      montantTotalDocument - montantPayeAvant - montantRecu;

  bool get factureSoldee => nouveauReste <= 0.01;
}
