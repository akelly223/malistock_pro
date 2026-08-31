import 'package:drift/drift.dart';
import '../local/database.dart';
import '../local/tables/clients_table.dart';
import '../../domain/entities/client.dart';
import '../../domain/entities/invoice.dart';
import '../../domain/entities/payment.dart';
import '../../domain/repositories/client_repository.dart';
import '../../domain/exceptions/client_doublon_exception.dart';

class ClientRepositoryImpl implements ClientRepository {
  final AppDatabase db;

  ClientRepositoryImpl(this.db);

  ClientEntity _toEntity(Client c, Map<int, double> dettes) => ClientEntity(
        id: c.id,
        nom: c.nom,
        telephone: c.telephone,
        adresse: c.adresse,
        nif: c.nif,
        detteTotale: dettes[c.id] ?? 0,
        dateCreation: c.dateCreation,
      );

  /// Reste à payer par client, unifié entre les ventes V2
  /// (`commercial_documents`, type facture) et les anciennes factures V1
  /// (`invoices`) non migrées — même technique de déduplication par
  /// `numero` que `DashboardRepositoryImpl._ventesUnifiees`. Remplace la
  /// colonne dénormalisée `clients.dette_totale`, qui n'est plus mise à
  /// jour par le flux de vente V2 ("Nouvelle vente").
  ///
  /// [clientId] restreint le calcul à un seul client (évite de scanner
  /// toute la table quand un seul client est demandé).
  Future<Map<int, double>> _dettesUnifiees({int? clientId}) async {
    final filtreV2 = clientId != null ? 'AND client_id = ?' : '';
    final filtreV1 = clientId != null ? 'AND i.client_id = ?' : '';
    final rows = await db.customSelect(
      '''
      SELECT client_id AS client_id, SUM(reste) AS reste_total FROM (
        SELECT client_id, (total_ttc - montant_paye) AS reste
        FROM commercial_documents
        WHERE type IN ('facture', 'facture_comptabilisee')
          AND statut != 'annule'
          AND client_id IS NOT NULL
          AND montant_paye < total_ttc
          $filtreV2
        UNION ALL
        SELECT i.client_id AS client_id, (i.total_final - i.montant_paye) AS reste
        FROM invoices i
        WHERE i.client_id IS NOT NULL
          AND i.montant_paye < i.total_final
          AND NOT EXISTS (
            SELECT 1 FROM commercial_documents cd WHERE cd.numero = i.numero
          )
          $filtreV1
      )
      GROUP BY client_id
      ''',
      variables: clientId != null
          ? [Variable.withInt(clientId), Variable.withInt(clientId)]
          : [],
    ).get();

    return {
      for (final row in rows)
        (row.data['client_id'] as int):
            (row.data['reste_total'] as num).toDouble(),
    };
  }

  @override
  Future<List<ClientEntity>> getAllClients() async {
    final clients = await db.clientsDao.getAllClients();
    final dettes = await _dettesUnifiees();
    return clients.map((c) => _toEntity(c, dettes)).toList();
  }

  @override
  Future<ClientEntity?> getClientById(int id) async {
    final c = await db.clientsDao.getClientById(id);
    if (c == null) return null;
    final dettes = await _dettesUnifiees(clientId: id);
    return _toEntity(c, dettes);
  }

  @override
  Future<List<ClientEntity>> searchClients(String query) async {
    final clients = await db.clientsDao.searchClients(query);
    final dettes = await _dettesUnifiees();
    return clients.map((c) => _toEntity(c, dettes)).toList();
  }

  @override
  Future<List<ClientEntity>> getClientsDebiteurs() async {
    final clients = await getAllClients();
    final debiteurs =
        clients.where((c) => c.detteTotale > 0.01).toList()
          ..sort((a, b) => b.detteTotale.compareTo(a.detteTotale));
    return debiteurs;
  }

  @override
  Future<ClientEntity?> verifierDoublon({
    required String nom,
    String? telephone,
    int? excluClientId,
  }) async {
    final doublon = await db.clientsDao.findDoublon(
      nom: nom,
      telephone: telephone,
      excluClientId: excluClientId,
    );
    return doublon == null ? null : _toEntity(doublon, const {});
  }

  @override
  Future<int> createClient({
    required String nom,
    String? telephone,
    String? adresse,
    String? nif,
  }) async {
    final doublon = await verifierDoublon(nom: nom, telephone: telephone);
    if (doublon != null) {
      throw ClientDoublonException(
        clientExistantId: doublon.id,
        nomExistant: doublon.nom,
      );
    }
    return db.clientsDao.createClient(ClientsCompanion.insert(
      nom: nom,
      telephone: Value(telephone),
      adresse: Value(adresse),
      nif: Value(nif),
    ));
  }

  @override
  Future<void> updateClient(ClientEntity client) async {
    final doublon = await verifierDoublon(
      nom: client.nom,
      telephone: client.telephone,
      excluClientId: client.id,
    );
    if (doublon != null) {
      throw ClientDoublonException(
        clientExistantId: doublon.id,
        nomExistant: doublon.nom,
      );
    }
    await db.clientsDao.updateClient(Client(
      id: client.id,
      nom: client.nom,
      telephone: client.telephone,
      adresse: client.adresse,
      nif: client.nif,
      detteTotale: client.detteTotale,
      dateCreation: client.dateCreation,
      tvaApplicable: 1,
    ));
  }

  @override
  Future<void> deleteClient(int id) => db.clientsDao.deleteClient(id);

  /// Historique d'achats unifié V1+V2 pour un client, le plus récent
  /// d'abord. Même déduplication par `numero` que `_dettesUnifiees` :
  /// une facture V1 migrée vers `commercial_documents` n'est comptée
  /// qu'une fois, côté V2.
  @override
  Future<List<InvoiceEntity>> getHistoriqueAchats(int clientId) async {
    final rows = await db.customSelect(
      '''
      SELECT id, numero, date_creation, total_ttc AS total, statut_paiement AS statut
      FROM commercial_documents
      WHERE client_id = ?
        AND type IN ('facture', 'facture_comptabilisee')
        AND statut != 'annule'
      UNION ALL
      SELECT i.id, i.numero, i.date_creation, i.total_final AS total,
             i.statut_paiement AS statut
      FROM invoices i
      WHERE i.client_id = ?
        AND NOT EXISTS (
          SELECT 1 FROM commercial_documents cd WHERE cd.numero = i.numero
        )
      ORDER BY date_creation DESC
      ''',
      variables: [Variable.withInt(clientId), Variable.withInt(clientId)],
    ).get();

    return rows
        .map((row) => InvoiceEntity(
              id: row.data['id'] as int,
              numero: row.data['numero'] as String,
              clientId: clientId,
              storeId: 0,
              userId: 0,
              dateCreation: DateTime.fromMillisecondsSinceEpoch(
                  (row.data['date_creation'] as int) * 1000),
              totalHt: 0,
              remiseGlobale: 0,
              totalFinal: (row.data['total'] as num).toDouble(),
              montantPaye: 0,
              statutPaiement: row.data['statut'] as String,
            ))
        .toList();
  }

  @override
  Future<List<PaymentEntity>> getHistoriquePaiements(int clientId) async {
    final payments = await db.paymentsDao.getPaymentsForClient(clientId);
    return payments
        .map((p) => PaymentEntity(
              id: p.id,
              invoiceId: p.invoiceId,
              clientId: p.clientId,
              montant: p.montant,
              modePaiement: p.modePaiement,
              datePaiement: p.datePaiement,
              userId: p.userId,
            ))
        .toList();
  }
}
