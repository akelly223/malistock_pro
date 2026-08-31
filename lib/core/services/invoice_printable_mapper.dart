import '../../domain/entities/invoice.dart';
import '../../domain/entities/printable_document.dart';

extension InvoiceToPrintable on InvoiceEntity {
  PrintableDocument toPrintableDocument() {
    return PrintableDocument(
      typeDocument: 'FACTURE',
      numero: numero,
      dateCreation: dateCreation,
      tiersNom: clientNom ?? 'Client comptoir',
      tiersTelephone: clientTelephone,
      tiersAdresse: clientAdresse,
      tiersNif: clientNif,
      storeNom: storeNom,
      userNom: userNom,
      lignes: items
          .map((item) => PrintableDocumentLine(
                designation: item.articleNom,
                quantite: item.quantite,
                prixUnitaire: item.prixUnitaire,
                totalLigne: item.totalLigne,
              ))
          .toList(),
      sousTotal: totalHt,
      remise: remiseGlobale,
      totalFinal: totalFinal,
      montantPaye: montantPaye,
      statutPaiement: statutPaiement,
    );
  }
}
