import '../entities/app_settings.dart';

abstract class SettingsRepository {
  Future<AppSettingsEntity> getSettings();

  Future<void> updateSettings({
    String? nomEntreprise,
    String? telephone,
    String? adresse,
    String? logoPath,
    bool supprimerLogo = false,
    String? email,
    String? slogan,
    String? commentairePiedDePage,
    String? nif,
    String? rccm,
    String? ifu,
    bool? tvaActive,
    double? tauxTva,
    String? devise,
    String? signaturePath,
    bool supprimerSignature = false,
    String? cachetPath,
    bool supprimerCachet = false,
  });
}
