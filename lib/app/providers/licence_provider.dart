import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/licence/licence_config.dart';
import '../../core/licence/licence_service.dart';
import '../../core/licence/licence_write_guard.dart';

final licenceServiceProvider =
    Provider<LicenceService>((ref) => LicenceService.windows());

/// État calculé dans `main()` AVANT le premier affichage (surchargé via
/// `ProviderScope.overrides`), pour que le verrou lecture seule soit en
/// place avant toute ouverture de fichier. La valeur par défaut (essai
/// complet) ne sert qu'aux tests qui ne la surchargent pas.
final etatLicenceInitialProvider = Provider<EtatLicence>(
  (ref) => const EtatLicence(
    statut: StatutLicence.essai,
    codePc: '',
    joursRestants: LicenceConfig.joursEssai,
  ),
);

class LicenceNotifier extends StateNotifier<EtatLicence> {
  LicenceNotifier(this._service, EtatLicence initial) : super(initial) {
    LicenceWriteGuard.lectureSeule = initial.lectureSeule;
  }

  final LicenceService _service;

  /// Retourne false si la clé est refusée (mauvaise clé, ou clé d'un
  /// autre PC).
  Future<bool> activer(String cle) async {
    final nouvelEtat = await _service.activer(cle);
    if (nouvelEtat == null) return false;
    LicenceWriteGuard.lectureSeule = nouvelEtat.lectureSeule;
    state = nouvelEtat;
    return true;
  }
}

final licenceProvider =
    StateNotifierProvider<LicenceNotifier, EtatLicence>((ref) {
  return LicenceNotifier(
    ref.watch(licenceServiceProvider),
    ref.watch(etatLicenceInitialProvider),
  );
});
