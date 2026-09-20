/// Champs possibles dans un fichier d'import.
/// Chaque valeur correspond à une donnée cible dans MaliStock Pro.
enum ImportField {
  // ── Articles ────────────────────────────────────────────────────────────────
  codeArticle,
  famille,
  designation,
  prixAchat,
  prixVente,
  stockInitial,
  stockMinimum,
  codeBarres,

  // ── Clients / Fournisseurs ──────────────────────────────────────────────────
  nom,
  telephone,
  adresse,
  nif,
}

/// Métadonnées d'un champ : libellé, obligatoire, et alias pour la
/// détection automatique.
class ImportFieldMeta {
  final String label;
  final bool required;
  final List<String> aliases;

  const ImportFieldMeta({
    required this.label,
    this.required = false,
    required this.aliases,
  });
}

/// Normalise une chaîne pour la comparaison floue :
/// minuscules, sans accents, sans séparateurs.
String normalizeForDetection(String s) {
  return s
      .toLowerCase()
      .replaceAll(RegExp(r'[àâä]'), 'a')
      .replaceAll(RegExp(r'[éèêë]'), 'e')
      .replaceAll(RegExp(r'[îï]'), 'i')
      .replaceAll(RegExp(r'[ôö]'), 'o')
      .replaceAll(RegExp(r'[ùûü]'), 'u')
      .replaceAll('ç', 'c')
      .replaceAll(RegExp(r'[^a-z0-9]'), '');
}

/// Carte complète des métadonnées par champ.
const Map<ImportField, ImportFieldMeta> importFieldMeta = {
  // ── Articles ──────────────────────────────────────────────────────────────
  ImportField.codeArticle: ImportFieldMeta(
    label: 'Code article',
    required: true,
    aliases: [
      'code', 'codearticle', 'ref', 'reference', 'refarticle',
      'codeproduit', 'sku', 'refproduit', 'identifiant', 'id',
      'articlecode', 'articleref',
    ],
  ),
  ImportField.famille: ImportFieldMeta(
    label: 'Famille / Catégorie',
    aliases: [
      'famille', 'categorie', 'category', 'type', 'groupe',
      'gamme', 'rayon', 'famillearticle', 'famillecode',
    ],
  ),
  ImportField.designation: ImportFieldMeta(
    label: 'Désignation',
    required: true,
    aliases: [
      'designation', 'libelle', 'nom', 'article', 'description',
      'intitule', 'produit', 'label', 'libellearticle',
      'nomarticle', 'designationarticle',
    ],
  ),
  ImportField.prixAchat: ImportFieldMeta(
    label: "Prix d'achat",
    aliases: [
      'prixachat', 'pa', 'achat', 'cout', 'coût', 'coutachat',
      'prixrevient', 'tarif', 'prixfournisseur', 'buyprice',
    ],
  ),
  ImportField.prixVente: ImportFieldMeta(
    label: 'Prix de vente',
    required: true,
    aliases: [
      'prixvente', 'pv', 'vente', 'tarif', 'prix', 'pvente',
      'prixtarif', 'tarifvente', 'sellprice', 'prixttc',
      'prixht', 'prixunitaire', 'pu',
    ],
  ),
  ImportField.stockInitial: ImportFieldMeta(
    label: 'Stock initial',
    aliases: [
      'stock', 'stockinitial', 'quantite', 'qte', 'qteinitiale',
      'stockdispo', 'quantiteinitiale', 'stockactuel',
      'qtedisponible', 'enstock', 'inventory',
    ],
  ),
  ImportField.stockMinimum: ImportFieldMeta(
    label: 'Stock minimum',
    aliases: [
      'stockmin', 'stockminimum', 'seuil', 'seuilalerte',
      'minimumstock', 'qtemin', 'alerte', 'stockseuil',
      'reorderlevel',
    ],
  ),
  ImportField.codeBarres: ImportFieldMeta(
    label: 'Code-barres',
    aliases: [
      'codebarres', 'codebarre', 'barcode', 'ean', 'ean13',
      'gtin', 'upc', 'isbn', 'barres',
    ],
  ),

  // ── Clients / Fournisseurs ────────────────────────────────────────────────
  ImportField.nom: ImportFieldMeta(
    label: 'Nom',
    required: true,
    aliases: [
      'nom', 'client', 'fournisseur', 'raisonsociale', 'societe',
      'entreprise', 'contact', 'name', 'clientnom', 'nomclient',
      'nomsociete', 'denomination',
    ],
  ),
  ImportField.telephone: ImportFieldMeta(
    label: 'Téléphone',
    aliases: [
      'telephone', 'tel', 'mobile', 'portable', 'gsm',
      'phone', 'numtel', 'numero', 'numerotelephone', 'contact',
    ],
  ),
  ImportField.adresse: ImportFieldMeta(
    label: 'Adresse',
    aliases: [
      'adresse', 'address', 'localisation', 'ville', 'domicile',
      'quartier', 'rue', 'lieu', 'localite',
    ],
  ),
  ImportField.nif: ImportFieldMeta(
    label: 'NIF',
    aliases: [
      'nif', 'identifiantfiscal', 'numerofiscal', 'fiscal',
      'numeronif', 'taxid',
    ],
  ),
};
