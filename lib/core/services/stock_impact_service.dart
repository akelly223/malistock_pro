import 'package:drift/drift.dart';
import '../../data/local/database.dart';
import '../../domain/entities/commercial_document.dart';
import '../../domain/entities/document_type.dart';

/// Applique ou reverse les impacts de stock liés aux pièces commerciales.
///
/// Seuls le BL (sortie) et le BR (entrée) ont un impact stock.
/// Chaque opération est idempotente via la transaction SQLite.
class StockImpactService {
  final AppDatabase _db;

  StockImpactService(this._db);

  /// Décrémente le stock pour chaque ligne du BL.
  /// Appelé lors de la validation d'un bon de livraison.
  Future<void> appliquerSortieBonLivraison(
      DocumentEntity bl, int userId) async {
    assert(bl.type == DocumentType.bonLivraison,
        'appliquerSortieBonLivraison appelé sur ${bl.type.libelle}');

    for (final ligne in bl.lignes) {
      await _db.articlesDao.adjustStock(
        articleId: ligne.articleId,
        storeId: bl.storeId,
        delta: -ligne.quantite,
      );
      await _db.stockDao.createMovement(
        StockMovementsCompanion.insert(
          articleId: ligne.articleId,
          storeId: bl.storeId,
          typeMouvement: 'sortie',
          quantite: ligne.quantite,
          reference: Value('BL:${bl.numero}'),
          userId: userId,
        ),
      );
    }
  }

  /// Reverse la sortie stock d'un BL (lors de son annulation).
  Future<void> reverserSortieBonLivraison(
      DocumentEntity bl, int userId) async {
    assert(bl.type == DocumentType.bonLivraison);

    for (final ligne in bl.lignes) {
      await _db.articlesDao.adjustStock(
        articleId: ligne.articleId,
        storeId: bl.storeId,
        delta: ligne.quantite,
      );
      await _db.stockDao.createMovement(
        StockMovementsCompanion.insert(
          articleId: ligne.articleId,
          storeId: bl.storeId,
          typeMouvement: 'entree',
          quantite: ligne.quantite,
          reference: Value('BL-ANNULE:${bl.numero}'),
          userId: userId,
        ),
      );
    }
  }

  /// Reverse le stock d'une vente comptoir directe (facture créée déjà
  /// validée par `creerVenteRapide`, sans BL en amont). Ce cas ne passe pas
  /// par [DocumentType.impacteStockValidation] : le stock est décrémenté à
  /// la création avec `reference == numéro du document` (pas de préfixe,
  /// contrairement aux mouvements BL/BR). On cible donc les mouvements de
  /// sortie réellement enregistrés pour ce document plutôt que de
  /// recalculer depuis ses lignes — no-op si le document n'a jamais
  /// décrémenté le stock lui-même (facture normale, issue d'un BL, etc.).
  Future<void> reverserVenteDirecte(DocumentEntity doc, int userId) async {
    final mouvements =
        await _db.stockDao.getMovementsByReference(doc.numero);

    for (final m in mouvements) {
      if (m.typeMouvement != 'sortie') continue;
      await _db.articlesDao.adjustStock(
        articleId: m.articleId,
        storeId: m.storeId,
        delta: m.quantite,
      );
      await _db.stockDao.createMovement(
        StockMovementsCompanion.insert(
          articleId: m.articleId,
          storeId: m.storeId,
          typeMouvement: 'entree',
          quantite: m.quantite,
          reference: Value('VENTE-ANNULEE:${doc.numero}'),
          userId: userId,
        ),
      );
    }
  }

  /// Incrémente le stock pour chaque ligne du BR.
  /// Appelé lors de la validation d'un bon de retour.
  Future<void> appliquerEntreeBonRetour(
      DocumentEntity br, int userId) async {
    assert(br.type == DocumentType.bonRetour);

    for (final ligne in br.lignes) {
      await _db.articlesDao.adjustStock(
        articleId: ligne.articleId,
        storeId: br.storeId,
        delta: ligne.quantite,
      );
      await _db.stockDao.createMovement(
        StockMovementsCompanion.insert(
          articleId: ligne.articleId,
          storeId: br.storeId,
          typeMouvement: 'entree',
          quantite: ligne.quantite,
          reference: Value('BR:${br.numero}'),
          userId: userId,
        ),
      );
    }
  }
}
