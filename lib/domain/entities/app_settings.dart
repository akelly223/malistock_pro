class AppSettingsEntity {
  final String nomEntreprise;
  final String? telephone;
  final String? adresse;
  final String? logoPath;
  final String? email;
  final String? slogan;
  final String commentairePiedDePage;
  final String? nif;
  final String? rccm;
  final String? ifu;
  final bool tvaActive;
  final double tauxTva;
  final String devise;
  final String? signaturePath;
  final String? cachetPath;

  const AppSettingsEntity({
    required this.nomEntreprise,
    this.telephone,
    this.adresse,
    this.logoPath,
    this.email,
    this.slogan,
    this.commentairePiedDePage = _commentaireParDefaut,
    this.nif,
    this.rccm,
    this.ifu,
    this.tvaActive = false,
    this.tauxTva = 18.0,
    this.devise = 'FCFA',
    this.signaturePath,
    this.cachetPath,
  });

  static const String _commentaireParDefaut =
      'Marchandise vendue ni reprise ni échangée.\nMerci pour votre confiance. Revenez bientôt.';

  static const AppSettingsEntity defaut = AppSettingsEntity(
    nomEntreprise: 'Ma Boutique',
    commentairePiedDePage: _commentaireParDefaut,
  );
}
