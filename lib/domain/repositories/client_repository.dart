import '../entities/client.dart';
import '../entities/invoice.dart';
import '../entities/payment.dart';

abstract class ClientRepository {
  Future<List<ClientEntity>> getAllClients();
  Future<ClientEntity?> getClientById(int id);
  Future<List<ClientEntity>> searchClients(String query);
  Future<List<ClientEntity>> getClientsDebiteurs();
  Future<int> createClient({
    required String nom,
    String? telephone,
    String? adresse,
    String? nif,
  });
  Future<void> updateClient(ClientEntity client);
  Future<void> deleteClient(int id);

  /// Vérifie s'il existe déjà un client avec le même nom et le même
  /// téléphone, sans lever d'exception : retourne le client trouvé
  /// ou null. Utilisé pour l'alerte en temps réel dans le formulaire,
  /// avant même la tentative de sauvegarde (qui reste le vrai
  /// garde-fou via [createClient]/[updateClient]).
  Future<ClientEntity?> verifierDoublon({
    required String nom,
    String? telephone,
    int? excluClientId,
  });

  Future<List<InvoiceEntity>> getHistoriqueAchats(int clientId);
  Future<List<PaymentEntity>> getHistoriquePaiements(int clientId);
}
