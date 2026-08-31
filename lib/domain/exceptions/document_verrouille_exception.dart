/// Levée quand on tente de modifier un document qui n'est plus en brouillon.
class DocumentVerrouillException implements Exception {
  final String numero;
  final String statut;

  const DocumentVerrouillException({
    required this.numero,
    required this.statut,
  });

  @override
  String toString() =>
      'Le document "$numero" est verrouillé (statut : $statut). '
      'Seuls les brouillons peuvent être modifiés.';
}
