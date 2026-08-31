class ClientDebtEntity {
  final int id;
  final int clientId;
  final int invoiceId;
  final String? invoiceNumero;
  final double montantDu;
  final DateTime dateCreation;
  final bool solde;

  const ClientDebtEntity({
    required this.id,
    required this.clientId,
    required this.invoiceId,
    this.invoiceNumero,
    required this.montantDu,
    required this.dateCreation,
    required this.solde,
  });
}
