/// Représentation générique d'un document commercial imprimable
/// (facture, achat, devis...), indépendante de l'entité métier
/// d'origine. Le service PDF ne travaille que sur cette structure,
/// ce qui permet de réutiliser le même générateur pour tous les
/// types de documents sans dupliquer la mise en page.
class PrintableDocumentLine {
  final String designation;
  final double quantite;
  final double prixUnitaire;
  final double totalLigne;

  /// Remise appliquée à cette ligne, en %. Null si non applicable
  /// (achats, factures V1 : pas de remise par ligne).
  final double? remisePct;

  /// Taux de TVA appliqué à cette ligne, en %. Null si le document
  /// n'applique pas de TVA (achats, factures V1).
  final double? tauxTva;

  /// Montant HT de la ligne (après remise ligne, avant TVA). Null si
  /// non applicable (documents sans TVA : identique à [totalLigne]).
  final double? totalHt;

  /// Montant TTC de la ligne. Null si non applicable.
  final double? totalTtc;

  const PrintableDocumentLine({
    required this.designation,
    required this.quantite,
    required this.prixUnitaire,
    required this.totalLigne,
    this.remisePct,
    this.tauxTva,
    this.totalHt,
    this.totalTtc,
  });
}

class PrintableDocument {
  /// "FACTURE", "ACHAT", "DEVIS"...
  final String typeDocument;
  final String numero;
  final DateTime dateCreation;

  /// Nom de l'autre partie : client pour une facture, fournisseur
  /// pour un achat.
  final String tiersNom;
  final String? tiersTelephone;
  final String? tiersAdresse;
  final String? tiersNif;

  final String? storeNom;
  final String? userNom;

  final List<PrintableDocumentLine> lignes;

  final double sousTotal;
  final double remise;

  /// Montant HT net (après remise, avant TVA). Null pour les documents
  /// sans TVA (documents V1, achats fournisseurs).
  final double? totalHtNet;

  /// Montant total de TVA. Null si le document n'applique pas de TVA.
  final double? totalTva;

  /// Taux TVA global en % (ex : 18.0). Null si pas de TVA.
  /// Utilisé pour libeller la ligne TVA dans le PDF : "TVA (18%)".
  final double? tvaGlobalePct;

  final double totalFinal;
  final double montantPaye;

  /// "paye" | "partiel" | "non_paye"
  final String statutPaiement;

  const PrintableDocument({
    required this.typeDocument,
    required this.numero,
    required this.dateCreation,
    required this.tiersNom,
    this.tiersTelephone,
    this.tiersAdresse,
    this.tiersNif,
    this.storeNom,
    this.userNom,
    required this.lignes,
    required this.sousTotal,
    required this.remise,
    this.totalHtNet,
    this.totalTva,
    this.tvaGlobalePct,
    required this.totalFinal,
    required this.montantPaye,
    required this.statutPaiement,
  });

  double get resteAPayer => totalFinal - montantPaye;

  double get quantiteTotale =>
      lignes.fold<double>(0, (sum, l) => sum + l.quantite);
}
