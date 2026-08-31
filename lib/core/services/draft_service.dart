import 'dart:convert';

import '../../data/local/daos/draft_dao.dart';
import '../../domain/entities/cart_item_input.dart';
import '../../domain/entities/purchase_cart_item_input.dart';
import '../../domain/entities/remise_globale.dart';
import '../../domain/entities/document_input.dart';
import '../../domain/entities/document_type.dart';

// ── Constantes de type ──────────────────────────────────────────────────────

abstract final class DraftType {
  static const vente = 'vente';
  static const achat = 'achat';
  static const devis = 'devis';
  static const proforma = 'proforma';
  static const bonCommande = 'bon_commande';
  static const preparationLivraison = 'preparation_livraison';
  static const bonLivraison = 'bon_livraison';
  static const bonRetour = 'bon_retour';
  static const avoir = 'avoir';
  static const factureV2 = 'facture_v2';

  static String pourDocumentType(DocumentType t) => switch (t) {
        DocumentType.proforma => proforma,
        DocumentType.bonCommande => bonCommande,
        DocumentType.preparationLivraison => preparationLivraison,
        DocumentType.bonLivraison => bonLivraison,
        DocumentType.bonRetour => bonRetour,
        DocumentType.avoir => avoir,
        DocumentType.facture => factureV2,
        _ => t.name,
      };

  static String libelle(String type) => const {
        vente: 'Vente',
        achat: 'Achat fournisseur',
        devis: 'Devis',
        proforma: 'Proforma',
        bonCommande: 'Bon de commande',
        preparationLivraison: 'Préparation de livraison',
        bonLivraison: 'Bon de livraison',
        bonRetour: 'Bon de retour',
        avoir: 'Avoir',
        factureV2: 'Facture',
      }[type] ??
      type;

  static String route(String type) => const {
        vente: '/invoices/new',
        achat: '/purchases/new',
        devis: '/quotes/new',
        proforma: '/proformas/new',
        bonCommande: '/bons-commande/new',
        preparationLivraison: '/preparations-livraison/new',
        bonLivraison: '/bons-livraison/new',
        bonRetour: '/bons-retour/new',
        avoir: '/avoirs/new',
        factureV2: '/factures-v2/new',
      }[type] ??
      '/dashboard';
}

// ── Payloads ────────────────────────────────────────────────────────────────

class VenteDraft {
  final List<CartItemInput> panier;
  final int? clientId;
  final int? storeId;
  final RemiseGlobale remise;
  final DateTime dateSauvegarde;

  const VenteDraft({
    required this.panier,
    this.clientId,
    this.storeId,
    required this.remise,
    required this.dateSauvegarde,
  });
}

class AchatDraft {
  final List<PurchaseCartItemInput> panier;
  final int? supplierId;
  final int? storeId;
  final RemiseGlobale remise;
  final DateTime dateSauvegarde;

  const AchatDraft({
    required this.panier,
    this.supplierId,
    this.storeId,
    required this.remise,
    required this.dateSauvegarde,
  });
}

class DevisDraft {
  final List<CartItemInput> panier;
  final int? clientId;
  final int? storeId;
  final RemiseGlobale remise;
  final DateTime dateSauvegarde;

  const DevisDraft({
    required this.panier,
    this.clientId,
    this.storeId,
    required this.remise,
    required this.dateSauvegarde,
  });
}

class DocumentDraft {
  final int? clientId;
  final String? clientNom;
  final int? storeId;
  final DateTime? dateDocument;
  final double remiseGlobalePct;
  final bool appliquerTva;
  final double tvaGlobalePct;
  final String? notes;
  final String? referenceExterne;
  final String? conditionsReglement;
  final List<DocumentLigneInput> lignes;
  final DateTime dateSauvegarde;

  const DocumentDraft({
    this.clientId,
    this.clientNom,
    this.storeId,
    this.dateDocument,
    this.remiseGlobalePct = 0,
    this.appliquerTva = false,
    this.tvaGlobalePct = 18.0,
    this.notes,
    this.referenceExterne,
    this.conditionsReglement,
    required this.lignes,
    required this.dateSauvegarde,
  });
}

class DraftInfo {
  final String type;
  final DateTime dateSauvegarde;
  final String donnees;

  const DraftInfo({
    required this.type,
    required this.dateSauvegarde,
    required this.donnees,
  });

  int get nbArticles {
    try {
      final m = jsonDecode(donnees) as Map<String, dynamic>;
      final panier = m['panier'] as List?;
      if (panier != null) return panier.length;
      final lignes = m['lignes'] as List?;
      return (lignes?.length) ?? 0;
    } catch (_) {
      return 0;
    }
  }
}

// ── Service ─────────────────────────────────────────────────────────────────

class DraftService {
  final DraftDao _dao;

  DraftService(this._dao);

  // ── Helpers JSON ────────────────────────────────────────────────────────

  Map<String, dynamic> _cartItemToJson(CartItemInput i) => {
        'articleId': i.articleId,
        'articleNom': i.articleNom,
        'quantite': i.quantite,
        'prixUnitaire': i.prixUnitaire,
        'remisePourcentage': i.remisePourcentage,
        'remiseMontant': i.remiseMontant,
      };

  CartItemInput _cartItemFromJson(Map<String, dynamic> m) => CartItemInput(
        articleId: m['articleId'] as int,
        articleNom: m['articleNom'] as String,
        quantite: (m['quantite'] as num).toDouble(),
        prixUnitaire: (m['prixUnitaire'] as num).toDouble(),
        remisePourcentage:
            (m['remisePourcentage'] as num?)?.toDouble() ?? 0,
        remiseMontant: (m['remiseMontant'] as num?)?.toDouble() ?? 0,
      );

  Map<String, dynamic> _purchaseItemToJson(PurchaseCartItemInput i) => {
        'articleId': i.articleId,
        'articleNom': i.articleNom,
        'quantite': i.quantite,
        'prixAchatUnitaire': i.prixAchatUnitaire,
      };

  PurchaseCartItemInput _purchaseItemFromJson(Map<String, dynamic> m) =>
      PurchaseCartItemInput(
        articleId: m['articleId'] as int,
        articleNom: m['articleNom'] as String,
        quantite: (m['quantite'] as num).toDouble(),
        prixAchatUnitaire: (m['prixAchatUnitaire'] as num).toDouble(),
      );

  Map<String, dynamic> _ligneToJson(DocumentLigneInput l) => {
        'articleId': l.articleId,
        'articleCode': l.articleCode,
        'articleNom': l.articleNom,
        'quantite': l.quantite,
        'prixUnitaireHt': l.prixUnitaireHt,
        'tauxTva': l.tauxTva,
        'remiseLignePct': l.remiseLignePct,
      };

  DocumentLigneInput _ligneFromJson(Map<String, dynamic> m) =>
      DocumentLigneInput(
        articleId: m['articleId'] as int,
        articleCode: m['articleCode'] as String? ?? '',
        articleNom: m['articleNom'] as String,
        quantite: (m['quantite'] as num).toDouble(),
        prixUnitaireHt: (m['prixUnitaireHt'] as num).toDouble(),
        tauxTva: (m['tauxTva'] as num?)?.toDouble() ?? 0,
        remiseLignePct: (m['remiseLignePct'] as num?)?.toDouble() ?? 0,
      );

  Map<String, dynamic> _remiseToJson(RemiseGlobale r) =>
      {'valeur': r.valeur, 'type': r.type.name};

  RemiseGlobale _remiseFromJson(Map<String, dynamic> m) => RemiseGlobale(
        valeur: (m['valeur'] as num).toDouble(),
        type: RemiseType.values.byName(m['type'] as String? ?? 'montant'),
      );

  // ── Vente ──────────────────────────────────────────────────────────────

  Future<void> sauvegarderVente({
    required List<CartItemInput> panier,
    required int? clientId,
    required int? storeId,
    required RemiseGlobale remise,
  }) async {
    if (panier.isEmpty) return;
    await _dao.saveDraft(
      DraftType.vente,
      jsonEncode({
        'panier': panier.map(_cartItemToJson).toList(),
        'clientId': clientId,
        'storeId': storeId,
        'remise': _remiseToJson(remise),
      }),
    );
  }

  Future<VenteDraft?> chargerVente() async {
    final draft = await _dao.getDraft(DraftType.vente);
    if (draft == null) return null;
    try {
      final m = jsonDecode(draft.donnees) as Map<String, dynamic>;
      return VenteDraft(
        panier: (m['panier'] as List)
            .map((i) => _cartItemFromJson(i as Map<String, dynamic>))
            .toList(),
        clientId: m['clientId'] as int?,
        storeId: m['storeId'] as int?,
        remise: _remiseFromJson(m['remise'] as Map<String, dynamic>),
        dateSauvegarde: draft.dateSauvegarde,
      );
    } catch (_) {
      await _dao.deleteDraft(DraftType.vente);
      return null;
    }
  }

  Future<void> supprimerVente() => _dao.deleteDraft(DraftType.vente);

  // ── Achat ──────────────────────────────────────────────────────────────

  Future<void> sauvegarderAchat({
    required List<PurchaseCartItemInput> panier,
    required int? supplierId,
    required int? storeId,
    required RemiseGlobale remise,
  }) async {
    if (panier.isEmpty) return;
    await _dao.saveDraft(
      DraftType.achat,
      jsonEncode({
        'panier': panier.map(_purchaseItemToJson).toList(),
        'supplierId': supplierId,
        'storeId': storeId,
        'remise': _remiseToJson(remise),
      }),
    );
  }

  Future<AchatDraft?> chargerAchat() async {
    final draft = await _dao.getDraft(DraftType.achat);
    if (draft == null) return null;
    try {
      final m = jsonDecode(draft.donnees) as Map<String, dynamic>;
      return AchatDraft(
        panier: (m['panier'] as List)
            .map((i) => _purchaseItemFromJson(i as Map<String, dynamic>))
            .toList(),
        supplierId: m['supplierId'] as int?,
        storeId: m['storeId'] as int?,
        remise: _remiseFromJson(m['remise'] as Map<String, dynamic>),
        dateSauvegarde: draft.dateSauvegarde,
      );
    } catch (_) {
      await _dao.deleteDraft(DraftType.achat);
      return null;
    }
  }

  Future<void> supprimerAchat() => _dao.deleteDraft(DraftType.achat);

  // ── Devis ──────────────────────────────────────────────────────────────

  Future<void> sauvegarderDevis({
    required List<CartItemInput> panier,
    required int? clientId,
    required int? storeId,
    required RemiseGlobale remise,
  }) async {
    if (panier.isEmpty) return;
    await _dao.saveDraft(
      DraftType.devis,
      jsonEncode({
        'panier': panier.map(_cartItemToJson).toList(),
        'clientId': clientId,
        'storeId': storeId,
        'remise': _remiseToJson(remise),
      }),
    );
  }

  Future<DevisDraft?> chargerDevis() async {
    final draft = await _dao.getDraft(DraftType.devis);
    if (draft == null) return null;
    try {
      final m = jsonDecode(draft.donnees) as Map<String, dynamic>;
      return DevisDraft(
        panier: (m['panier'] as List)
            .map((i) => _cartItemFromJson(i as Map<String, dynamic>))
            .toList(),
        clientId: m['clientId'] as int?,
        storeId: m['storeId'] as int?,
        remise: _remiseFromJson(m['remise'] as Map<String, dynamic>),
        dateSauvegarde: draft.dateSauvegarde,
      );
    } catch (_) {
      await _dao.deleteDraft(DraftType.devis);
      return null;
    }
  }

  Future<void> supprimerDevis() => _dao.deleteDraft(DraftType.devis);

  // ── Documents V2 ────────────────────────────────────────────────────────

  Future<void> sauvegarderDocument({
    required String draftType,
    required int? clientId,
    required String? clientNom,
    required int? storeId,
    required DateTime? dateDocument,
    required double remiseGlobalePct,
    required bool appliquerTva,
    required double tvaGlobalePct,
    required String? notes,
    required String? referenceExterne,
    required String? conditionsReglement,
    required List<DocumentLigneInput> lignes,
  }) async {
    if (lignes.isEmpty) return;
    await _dao.saveDraft(
      draftType,
      jsonEncode({
        'clientId': clientId,
        'clientNom': clientNom,
        'storeId': storeId,
        'dateDocument': dateDocument?.toIso8601String(),
        'remiseGlobalePct': remiseGlobalePct,
        'appliquerTva': appliquerTva,
        'tvaGlobalePct': tvaGlobalePct,
        'notes': notes,
        'referenceExterne': referenceExterne,
        'conditionsReglement': conditionsReglement,
        'lignes': lignes.map(_ligneToJson).toList(),
      }),
    );
  }

  Future<DocumentDraft?> chargerDocument(String draftType) async {
    final draft = await _dao.getDraft(draftType);
    if (draft == null) return null;
    try {
      final m = jsonDecode(draft.donnees) as Map<String, dynamic>;
      return DocumentDraft(
        clientId: m['clientId'] as int?,
        clientNom: m['clientNom'] as String?,
        storeId: m['storeId'] as int?,
        dateDocument: m['dateDocument'] != null
            ? DateTime.tryParse(m['dateDocument'] as String)
            : null,
        remiseGlobalePct:
            (m['remiseGlobalePct'] as num?)?.toDouble() ?? 0,
        appliquerTva: m['appliquerTva'] as bool? ?? false,
        tvaGlobalePct: (m['tvaGlobalePct'] as num?)?.toDouble() ?? 18.0,
        notes: m['notes'] as String?,
        referenceExterne: m['referenceExterne'] as String?,
        conditionsReglement: m['conditionsReglement'] as String?,
        lignes: (m['lignes'] as List)
            .map((l) => _ligneFromJson(l as Map<String, dynamic>))
            .toList(),
        dateSauvegarde: draft.dateSauvegarde,
      );
    } catch (_) {
      await _dao.deleteDraft(draftType);
      return null;
    }
  }

  Future<void> supprimerDocument(String draftType) =>
      _dao.deleteDraft(draftType);

  // ── Global ──────────────────────────────────────────────────────────────

  Future<List<DraftInfo>> listerBrouillons() async {
    final all = await _dao.getAllDrafts();
    return all
        .map((d) => DraftInfo(
              type: d.type,
              dateSauvegarde: d.dateSauvegarde,
              donnees: d.donnees,
            ))
        .toList();
  }

  Future<void> supprimerBrouillon(String type) => _dao.deleteDraft(type);

  Future<void> supprimerTous() => _dao.deleteAllDrafts();
}
