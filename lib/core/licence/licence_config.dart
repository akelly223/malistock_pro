/// Paramètres de la licence propres à CETTE application. Les
/// applications sœurs (gestion_commerciale, mali_pneus) ont leur propre
/// [produit] mais partagent la même [clePublique] (une seule clé
/// secrète éditeur pour les trois produits).
abstract final class LicenceConfig {
  /// Identifiant produit (4 caractères) inscrit dans chaque clé.
  static const String produit = 'MSP1';

  /// Durée de l'essai gratuit, à compter du premier lancement sur le PC.
  static const int joursEssai = 90;

  /// Rappel affiché quand il reste moins de jours que ceci.
  static const int joursAvantRappel = 15;

  /// Tolérance sur un recul de l'horloge (changement de fuseau, petite
  /// correction de l'heure) avant de considérer la date du PC comme
  /// incohérente.
  static const Duration toleranceRecul = Duration(hours: 36);

  /// Clé registre (HKCU) où une copie de l'état d'essai est conservée
  /// en plus du fichier dans AppData : supprimer l'un ne suffit pas à
  /// relancer l'essai. Nom volontairement peu parlant.
  static const String cleRegistre = r'Software\MaliCodeCenter\Msp\Cfg';

  /// Clé publique Ed25519 de l'éditeur (MALI_CODE CENTER). Ne permet
  /// que de VÉRIFIER une clé de licence ; la clé secrète correspondante
  /// reste chez l'éditeur (voir tool/generer_licence.dart).
  static const List<int> clePublique = [
    137, 252, 164, 101, 202, 51, 133, 166, 69, 170, 171, 98, 184, 61, 63, 77, //
    30, 170, 222, 145, 16, 30, 124, 199, 190, 174, 191, 40, 71, 126, 126, 232,
  ];
}
