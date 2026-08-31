class ClientEntity {
  final int id;
  final String nom;
  final String? telephone;
  final String? adresse;
  final String? nif;
  final double detteTotale;
  final DateTime dateCreation;

  const ClientEntity({
    required this.id,
    required this.nom,
    this.telephone,
    this.adresse,
    this.nif,
    required this.detteTotale,
    required this.dateCreation,
  });

  bool get estDebiteur => detteTotale > 0;

  ClientEntity copyWithEdit({
    String? nom,
    String? telephone,
    String? adresse,
    String? nif,
  }) {
    return ClientEntity(
      id: id,
      nom: nom ?? this.nom,
      telephone: telephone?.isEmpty == true ? null : (telephone ?? this.telephone),
      adresse: adresse?.isEmpty == true ? null : (adresse ?? this.adresse),
      nif: nif?.isEmpty == true ? null : (nif ?? this.nif),
      detteTotale: detteTotale,
      dateCreation: dateCreation,
    );
  }
}
