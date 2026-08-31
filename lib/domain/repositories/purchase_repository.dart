import '../entities/purchase.dart';
import '../entities/purchase_cart_item_input.dart';

abstract class PurchaseRepository {
  Future<List<PurchaseEntity>> getAllPurchases();
  Future<PurchaseEntity?> getPurchaseById(int id);
  Future<List<PurchaseEntity>> getPurchasesForSupplier(int supplierId);
  Future<List<PurchaseEntity>> searchPurchases(String query);

  /// Crée un achat fournisseur.
  ///
  /// Si [statut] vaut 'recu' (par défaut) : augmente le stock du
  /// magasin pour chaque article, met à jour leur prix d'achat de
  /// référence, crée un mouvement de stock "entrée" par ligne, et
  /// enregistre le paiement initial s'il y en a un.
  ///
  /// Si [statut] vaut 'commande' : crée un simple bon de commande
  /// fournisseur, sans aucun impact sur le stock. Le stock ne sera
  /// impacté qu'au moment de [receptionnerCommande].
  Future<int> createPurchase({
    required int supplierId,
    required int storeId,
    required int userId,
    required List<PurchaseCartItemInput> items,
    double remiseGlobale = 0,
    double montantPayeInitial = 0,
    String? modePaiementInitial,
    String statut = 'recu',
  });

  /// Réceptionne un bon de commande : applique enfin l'entrée de
  /// stock (augmentation, mouvement, mise à jour du prix d'achat) et
  /// fait passer son statut à 'recu'. Sans effet si l'achat n'est pas
  /// un bon de commande en attente.
  Future<void> receptionnerCommande({
    required int purchaseId,
    required int userId,
  });

  /// Modifie un achat existant : annule les effets de l'ancien achat
  /// sur le stock (soustraction des anciennes quantités), puis applique
  /// le nouvel achat (ajout des nouvelles quantités). Enregistre la
  /// date de modification et l'auteur pour la traçabilité.
  Future<void> updatePurchase({
    required int purchaseId,
    required int supplierId,
    required int storeId,
    required int modifieParUserId,
    required List<PurchaseCartItemInput> items,
    double remiseGlobale = 0,
  });

  /// Total cumulé des achats effectués auprès d'un fournisseur,
  /// utilisé sur la fiche fournisseur.
  Future<double> getTotalAchatsForSupplier(int supplierId);

  Future<void> deletePurchase(int id);
}
