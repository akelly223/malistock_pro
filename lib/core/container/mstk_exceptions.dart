/// Erreurs de lecture d'un fichier .mstk, distinguées pour permettre des
/// messages clairs côté UI (voir le plan de conception du format).
///
/// Non scellée (contrairement à un premier essai) : `MstkVerrouilleException`
/// (fichier déjà ouvert) vit dans `mstk_container_service.dart`, pas ici,
/// pour ne pas mélanger les préoccupations "format" et "accès concurrent".
abstract class MstkException implements Exception {
  final String message;
  const MstkException(this.message);

  @override
  String toString() => message;
}

/// En-tête structurellement invalide (signature ou CRC ne correspondent
/// pas) : détectée AVANT toute tentative de déchiffrement, donc jamais
/// confondue avec un mot de passe incorrect.
final class MstkCorrompuException extends MstkException {
  const MstkCorrompuException([super.message = 'Fichier corrompu ou invalide.']);
}

/// Le fichier a été écrit par une version du format plus récente que ce
/// que cette version de l'application sait lire.
final class MstkVersionFutureException extends MstkException {
  final int versionFichier;
  final int versionSupportee;

  MstkVersionFutureException(this.versionFichier, this.versionSupportee)
      : super(
          'Ce fichier a été créé par une version plus récente de MaliStock Pro '
          '(format v$versionFichier, cette version ne lit que jusqu\'à v$versionSupportee). '
          'Mettez à jour l\'application.',
        );
}

/// Échec de déchiffrement : soit le mot de passe est incorrect, soit le
/// contenu chiffré a été altéré. Un chiffrement authentifié (AES-GCM) ne
/// permet structurellement pas de distinguer ces deux cas — le message
/// reste donc volontairement combiné plutôt que de risquer d'induire en
/// erreur.
final class MstkAuthentificationException extends MstkException {
  const MstkAuthentificationException(
      [super.message = 'Mot de passe incorrect ou fichier corrompu.']);
}
