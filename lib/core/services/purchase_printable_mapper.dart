import '../../domain/entities/purchase.dart';
import '../../domain/entities/printable_document.dart';

extension PurchaseToPrintable on PurchaseEntity {
  PrintableDocument toPrintableDocument() {
    return PrintableDocument(
      typeDocument: estCommande ? 'BON DE COMMANDE' : 'ACHAT',
      numero: numero,
      dateCreation: dateCreation,
      tiersNom: supplierNom ?? 'Fournisseur',
      tiersTelephone: supplierTelephone,
      tiersAdresse: supplierAdresse,
      storeNom: storeNom,
      userNom: userNom,
      lignes: items
          .map((item) => PrintableDocumentLine(
                designation: item.articleNom,
                quantite: item.quantite,
                prixUnitaire: item.prixAchatUnitaire,
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
