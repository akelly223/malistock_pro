/// Levée lorsqu'on tente de créer ou modifier un client avec un nom
/// ET un téléphone identiques à un client déjà existant (comparaison
/// insensible à la casse et aux espaces). Porte l'identité du client
/// existant pour permettre à l'écran d'offrir un raccourci vers sa
/// fiche plutôt qu'une simple erreur bloquante sans recours.
class ClientDoublonException implements Exception {
  final int clientExistantId;
  final String nomExistant;

  const ClientDoublonException({
    required this.clientExistantId,
    required this.nomExistant,
  });

  @override
  String toString() {
    return 'Un client nommé "$nomExistant" existe déjà avec ce numéro de téléphone.';
  }
}
