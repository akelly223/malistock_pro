class PaymentEntity {
  final int id;
  final int? invoiceId;
  final int? clientId;
  final double montant;
  final String modePaiement;
  final DateTime datePaiement;
  final int userId;
  final String? numeroRecu;

  const PaymentEntity({
    required this.id,
    this.invoiceId,
    this.clientId,
    required this.montant,
    required this.modePaiement,
    required this.datePaiement,
    required this.userId,
    this.numeroRecu,
  });
}
