import 'package:drift/drift.dart';
import '../database.dart';
import '../tables/clients_table.dart';

part 'clients_dao.g.dart';

@DriftAccessor(tables: [Clients])
class ClientsDao extends DatabaseAccessor<AppDatabase> with _$ClientsDaoMixin {
  ClientsDao(super.db);

  Future<List<Client>> getAllClients() => select(clients).get();

  Future<Client?> getClientById(int id) =>
      (select(clients)..where((c) => c.id.equals(id))).getSingleOrNull();

  Future<List<Client>> searchClients(String query) {
    final likeQuery = '%$query%';
    return (select(clients)
          ..where((c) => c.nom.like(likeQuery) | c.telephone.like(likeQuery))
          ..limit(10))
        .get();
  }

  /// Clients ayant une dette strictement positive (module Dettes clients).
  Future<List<Client>> getClientsDebiteurs() => (select(clients)
        ..where((c) => c.detteTotale.isBiggerThanValue(0))
        ..orderBy([(c) => OrderingTerm.desc(c.detteTotale)]))
      .get();

  Future<int> createClient(ClientsCompanion client) =>
      into(clients).insert(client);

  Future<bool> updateClient(Client client) => update(clients).replace(client);

  /// Recherche un client existant ayant le même nom ET le même
  /// téléphone, une fois les deux normalisés (espaces multiples
  /// réduits, casse ignorée pour le nom). Le téléphone est lui aussi
  /// normalisé (espaces retirés) pour que "76 12 34 56" et "76123456"
  /// soient reconnus comme identiques.
  ///
  /// Ne considère PAS comme doublon deux clients homonymes sans
  /// téléphone renseigné : au Grand Marché, plusieurs clients peuvent
  /// légitimement partager un nom courant sans qu'on puisse les
  /// distinguer autrement qu'en les laissant coexister.
  ///
  /// [excluClientId] permet d'exclure le client en cours d'édition
  /// lors d'une modification (sinon il se détecterait lui-même).
  Future<Client?> findDoublon({
    required String nom,
    required String? telephone,
    int? excluClientId,
  }) async {
    final telephoneNormalise = _normaliserTelephone(telephone);
    if (telephoneNormalise == null || telephoneNormalise.isEmpty) {
      return null;
    }

    final nomNormalise = _normaliserNom(nom);
    final tous = await select(clients).get();
    for (final client in tous) {
      if (excluClientId != null && client.id == excluClientId) continue;
      if (_normaliserNom(client.nom) != nomNormalise) continue;
      if (_normaliserTelephone(client.telephone) == telephoneNormalise) {
        return client;
      }
    }
    return null;
  }

  static String _normaliserNom(String nom) =>
      nom.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  static String? _normaliserTelephone(String? telephone) {
    if (telephone == null) return null;
    return telephone.replaceAll(RegExp(r'\s+'), '');
  }

  Future<int> deleteClient(int id) =>
      (delete(clients)..where((c) => c.id.equals(id))).go();

  /// Met à jour la dette dénormalisée d'un client (appelé après chaque
  /// facture ou paiement).
  Future<void> updateDette(int clientId, double nouvelleDette) =>
      (update(clients)..where((c) => c.id.equals(clientId)))
          .write(ClientsCompanion(detteTotale: Value(nouvelleDette)));
}
