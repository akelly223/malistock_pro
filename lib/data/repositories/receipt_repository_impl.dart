import '../local/database.dart';
import '../../domain/entities/payment_receipt.dart';
import '../../domain/repositories/receipt_repository.dart';

/// Ligne brute lue en SQL, avant calcul du "payé avant" / "reste".
class _LignePaiement {
  final String source;
  final int paymentId;
  final String numeroRecu;
  final int dateEpoch;
  final double montant;
  final String modePaiement;
  final String? utilisateur;
  final int docId;
  final String numeroDocument;
  final double montantTotalDocument;
  final String tiersNom;
  final String typePaiement;

  const _LignePaiement({
    required this.source,
    required this.paymentId,
    required this.numeroRecu,
    required this.dateEpoch,
    required this.montant,
    required this.modePaiement,
    required this.utilisateur,
    required this.docId,
    required this.numeroDocument,
    required this.montantTotalDocument,
    required this.tiersNom,
    required this.typePaiement,
  });
}

class ReceiptRepositoryImpl implements ReceiptRepository {
  final AppDatabase db;

  ReceiptRepositoryImpl(this.db);

  static const String _requeteUnifiee = '''
    SELECT
      'v2' AS source, dp.id AS payment_id, dp.numero_recu AS numero_recu,
      dp.date_creation AS date_epoch, dp.montant AS montant,
      dp.mode_paiement AS mode_paiement, dp.created_by_nom AS utilisateur,
      cd.id AS doc_id, cd.numero AS numero_document,
      cd.total_ttc AS montant_total_document,
      COALESCE(c.nom, 'Client comptoir') AS tiers_nom, 'vente' AS type_paiement
    FROM document_payments dp
    JOIN commercial_documents cd ON dp.document_id = cd.id
    LEFT JOIN clients c ON cd.client_id = c.id
    WHERE dp.numero_recu IS NOT NULL
      AND cd.type IN ('facture', 'facture_comptabilisee')

    UNION ALL

    SELECT
      'v1_facture' AS source, p.id AS payment_id, p.numero_recu AS numero_recu,
      p.date_paiement AS date_epoch, p.montant AS montant,
      p.mode_paiement AS mode_paiement, u.nom AS utilisateur,
      i.id AS doc_id, i.numero AS numero_document,
      i.total_final AS montant_total_document,
      COALESCE(c.nom, 'Client comptoir') AS tiers_nom, 'vente' AS type_paiement
    FROM payments p
    JOIN invoices i ON p.invoice_id = i.id
    LEFT JOIN clients c ON i.client_id = c.id
    LEFT JOIN users u ON p.user_id = u.id
    WHERE p.numero_recu IS NOT NULL AND p.invoice_id IS NOT NULL

    UNION ALL

    SELECT
      'achat' AS source, p.id AS payment_id, p.numero_recu AS numero_recu,
      p.date_paiement AS date_epoch, p.montant AS montant,
      p.mode_paiement AS mode_paiement, u.nom AS utilisateur,
      pu.id AS doc_id, pu.numero AS numero_document,
      pu.total_final AS montant_total_document,
      COALESCE(s.nom, 'Fournisseur') AS tiers_nom, 'achat' AS type_paiement
    FROM payments p
    JOIN purchases pu ON p.purchase_id = pu.id
    LEFT JOIN suppliers s ON pu.supplier_id = s.id
    LEFT JOIN users u ON p.user_id = u.id
    WHERE p.numero_recu IS NOT NULL AND p.purchase_id IS NOT NULL
  ''';

  _LignePaiement _toLigne(Map<String, dynamic> data) => _LignePaiement(
        source: data['source'] as String,
        paymentId: data['payment_id'] as int,
        numeroRecu: data['numero_recu'] as String,
        dateEpoch: data['date_epoch'] as int,
        montant: (data['montant'] as num).toDouble(),
        modePaiement: data['mode_paiement'] as String,
        utilisateur: data['utilisateur'] as String?,
        docId: data['doc_id'] as int,
        numeroDocument: data['numero_document'] as String,
        montantTotalDocument:
            (data['montant_total_document'] as num).toDouble(),
        tiersNom: data['tiers_nom'] as String,
        typePaiement: data['type_paiement'] as String,
      );

  /// Regroupe les lignes par document (source + docId), calcule pour
  /// chacune le montant déjà payé avant elle en resommant les paiements
  /// antérieurs du même document dans l'ordre chronologique.
  List<PaymentReceiptEntity> _calculerRecus(List<_LignePaiement> lignes) {
    final parDocument = <String, List<_LignePaiement>>{};
    for (final l in lignes) {
      parDocument.putIfAbsent('${l.source}:${l.docId}', () => []).add(l);
    }

    final resultat = <PaymentReceiptEntity>[];
    for (final groupe in parDocument.values) {
      groupe.sort((a, b) {
        final parDate = a.dateEpoch.compareTo(b.dateEpoch);
        return parDate != 0 ? parDate : a.paymentId.compareTo(b.paymentId);
      });
      double cumul = 0;
      for (final l in groupe) {
        resultat.add(PaymentReceiptEntity(
          source: l.source,
          paymentId: l.paymentId,
          numeroRecu: l.numeroRecu,
          datePaiement:
              DateTime.fromMillisecondsSinceEpoch(l.dateEpoch * 1000),
          typePaiement: l.typePaiement,
          tiersNom: l.tiersNom,
          numeroDocument: l.numeroDocument,
          montantTotalDocument: l.montantTotalDocument,
          montantPayeAvant: cumul,
          montantRecu: l.montant,
          modePaiement: l.modePaiement,
          utilisateur: l.utilisateur,
        ));
        cumul += l.montant;
      }
    }

    resultat.sort((a, b) => b.datePaiement.compareTo(a.datePaiement));
    return resultat;
  }

  @override
  Future<List<PaymentReceiptEntity>> getAllReceipts() async {
    final rows = await db.customSelect(_requeteUnifiee).get();
    final lignes = rows.map((r) => _toLigne(r.data)).toList();
    return _calculerRecus(lignes);
  }

  @override
  Future<PaymentReceiptEntity?> getReceiptById(
      String source, int paymentId) async {
    final tous = await getAllReceipts();
    for (final recu in tous) {
      if (recu.source == source && recu.paymentId == paymentId) return recu;
    }
    return null;
  }
}
