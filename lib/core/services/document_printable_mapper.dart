import '../../domain/entities/commercial_document.dart';
import '../../domain/entities/printable_document.dart';

extension DocumentToPrintable on DocumentEntity {
  PrintableDocument toPrintableDocument() {
    final brutHt = remiseGlobalePct > 0 && remiseGlobalePct < 100
        ? totalHt / (1.0 - remiseGlobalePct / 100.0)
        : totalHt;

    // Récupère le taux TVA depuis la première ligne (toutes partagent le même
    // taux depuis la V3 — TVA gérée au niveau du document).
    final tvaTaux =
        lignes.isNotEmpty && totalTva > 0 ? lignes.first.tauxTva : null;

    return PrintableDocument(
      typeDocument: type.libelle.toUpperCase(),
      numero: numero,
      dateCreation: dateDocument,
      tiersNom: clientNom ?? 'Client comptoir',
      tiersNif: clientNif,
      storeNom: storeNom,
      lignes: lignes
          .map((l) => PrintableDocumentLine(
                designation: l.articleNom,
                quantite: l.quantite,
                prixUnitaire: l.prixUnitaireHt,
                totalLigne: l.totalHt,
                remisePct: l.remiseLignePct > 0 ? l.remiseLignePct : null,
                tauxTva: l.tauxTva,
                totalHt: l.totalHt,
                totalTtc: l.totalTtc,
              ))
          .toList(),
      sousTotal: brutHt,
      remise: brutHt - totalHt,
      totalHtNet: totalHt,
      totalTva: totalTva > 0 ? totalTva : null,
      tvaGlobalePct: tvaTaux,
      totalFinal: totalTtc,
      montantPaye: montantPaye,
      statutPaiement: statutPaiement,
    );
  }
}
