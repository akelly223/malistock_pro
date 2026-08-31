import 'package:drift/drift.dart';
import '../database.dart';
import '../tables/app_settings_table.dart';

part 'app_settings_dao.g.dart';

@DriftAccessor(tables: [AppSettings])
class AppSettingsDao extends DatabaseAccessor<AppDatabase>
    with _$AppSettingsDaoMixin {
  AppSettingsDao(super.db);

  Future<AppSetting?> getSettings() =>
      (select(appSettings)..limit(1)).getSingleOrNull();

  Future<void> upsertSettings({
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
  }) async {
    final existing = await getSettings();

    final valeurLogo = supprimerLogo
        ? const Value<String?>(null)
        : (logoPath != null ? Value(logoPath) : const Value<String?>.absent());

    final valeurSignature = supprimerSignature
        ? const Value<String?>(null)
        : (signaturePath != null
            ? Value(signaturePath)
            : const Value<String?>.absent());

    final valeurCachet = supprimerCachet
        ? const Value<String?>(null)
        : (cachetPath != null
            ? Value(cachetPath)
            : const Value<String?>.absent());

    if (existing == null) {
      await into(appSettings).insert(AppSettingsCompanion.insert(
        nomEntreprise: Value(nomEntreprise ?? 'Ma Boutique'),
        telephone: Value(telephone),
        adresse: Value(adresse),
        logoPath: supprimerLogo ? const Value(null) : Value(logoPath),
        email: Value(email),
        slogan: Value(slogan),
        commentairePiedDePage: commentairePiedDePage != null
            ? Value(commentairePiedDePage)
            : const Value.absent(),
        nif: Value(nif),
        rccm: Value(rccm),
        ifu: Value(ifu),
        tvaActive:
            tvaActive != null ? Value(tvaActive) : const Value.absent(),
        tauxTva: tauxTva != null ? Value(tauxTva) : const Value.absent(),
        devise: devise != null ? Value(devise) : const Value.absent(),
        signaturePath:
            supprimerSignature ? const Value(null) : Value(signaturePath),
        cachetPath: supprimerCachet ? const Value(null) : Value(cachetPath),
      ));
    } else {
      await (update(appSettings)..where((s) => s.id.equals(existing.id)))
          .write(AppSettingsCompanion(
        nomEntreprise: nomEntreprise != null
            ? Value(nomEntreprise)
            : const Value.absent(),
        telephone:
            telephone != null ? Value(telephone) : const Value.absent(),
        adresse: adresse != null ? Value(adresse) : const Value.absent(),
        logoPath: valeurLogo,
        email: email != null ? Value(email) : const Value.absent(),
        slogan: slogan != null ? Value(slogan) : const Value.absent(),
        commentairePiedDePage: commentairePiedDePage != null
            ? Value(commentairePiedDePage)
            : const Value.absent(),
        nif: nif != null ? Value(nif) : const Value.absent(),
        rccm: rccm != null ? Value(rccm) : const Value.absent(),
        ifu: ifu != null ? Value(ifu) : const Value.absent(),
        tvaActive:
            tvaActive != null ? Value(tvaActive) : const Value.absent(),
        tauxTva: tauxTva != null ? Value(tauxTva) : const Value.absent(),
        devise: devise != null ? Value(devise) : const Value.absent(),
        signaturePath: valeurSignature,
        cachetPath: valeurCachet,
      ));
    }
  }
}
