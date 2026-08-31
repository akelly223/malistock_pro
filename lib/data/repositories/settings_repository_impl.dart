import '../local/database.dart';
import '../../domain/entities/app_settings.dart';
import '../../domain/repositories/settings_repository.dart';

class SettingsRepositoryImpl implements SettingsRepository {
  final AppDatabase db;

  SettingsRepositoryImpl(this.db);

  @override
  Future<AppSettingsEntity> getSettings() async {
    final row = await db.appSettingsDao.getSettings();
    if (row == null) return AppSettingsEntity.defaut;
    return AppSettingsEntity(
      nomEntreprise: row.nomEntreprise,
      telephone: row.telephone,
      adresse: row.adresse,
      logoPath: row.logoPath,
      email: row.email,
      slogan: row.slogan,
      commentairePiedDePage: row.commentairePiedDePage,
      nif: row.nif,
      rccm: row.rccm,
      ifu: row.ifu,
      tvaActive: row.tvaActive,
      tauxTva: row.tauxTva,
      devise: row.devise,
      signaturePath: row.signaturePath,
      cachetPath: row.cachetPath,
    );
  }

  @override
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
  }) {
    return db.appSettingsDao.upsertSettings(
      nomEntreprise: nomEntreprise,
      telephone: telephone,
      adresse: adresse,
      logoPath: logoPath,
      supprimerLogo: supprimerLogo,
      email: email,
      slogan: slogan,
      commentairePiedDePage: commentairePiedDePage,
      nif: nif,
      rccm: rccm,
      ifu: ifu,
      tvaActive: tvaActive,
      tauxTva: tauxTva,
      devise: devise,
      signaturePath: signaturePath,
      supprimerSignature: supprimerSignature,
      cachetPath: cachetPath,
      supprimerCachet: supprimerCachet,
    );
  }
}
