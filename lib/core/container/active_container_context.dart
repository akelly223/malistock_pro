/// Pont statique entre le conteneur `.mstk` actuellement ouvert et
/// `AppDatabase.getDatabaseDirectory()`.
///
/// `_openConnection()` (dans `database.dart`) est une fonction
/// top-level appelée par une `LazyDatabase` sans accès à Riverpod
/// (`ref`) — ce petit holder statique est le point d'accroche le plus
/// simple pour lui indiquer "utilise ce dossier temporaire plutôt que
/// le dossier par défaut", sans changer la signature d'aucun des 15
/// repositories qui dépendent de `databaseProvider`.
abstract final class ActiveContainerContext {
  static String? _dossierTravailCourant;

  /// Dossier de travail du conteneur `.mstk` ouvert, ou `null` si
  /// aucun conteneur n'est ouvert (repli sur `DataLocationService`).
  static String? get dossierTravailCourant => _dossierTravailCourant;

  static void definir(String? dossier) {
    _dossierTravailCourant = dossier;
  }
}
