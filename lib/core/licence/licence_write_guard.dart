import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';

/// Levée quand une écriture est refusée parce que l'essai est terminé.
/// Son `toString()` est le message affiché tel quel par les écrans qui
/// montrent l'erreur reçue (« Erreur : ... »).
class LicenceLectureSeuleException implements Exception {
  const LicenceLectureSeuleException();

  @override
  String toString() =>
      'Période d\'essai terminée : activez votre licence pour enregistrer '
      'de nouvelles opérations (Paramètres › Licence).';
}

/// Verrou "lecture seule" posé sur la base de données elle-même, plutôt
/// que bouton par bouton : beaucoup d'enregistrements partent de
/// dialogues (vente comptoir, suppression, paiement...) et non d'une
/// page dédiée. Bloquer ici garantit qu'AUCUN chemin n'y échappe, y
/// compris un écran ajouté plus tard.
///
/// Toutes les lectures restent libres (consultation, impression PDF,
/// export, sauvegarde). Seules les écritures dans les tables métier sont
/// refusées ; quelques tables techniques restent modifiables pour ne
/// pas casser le fonctionnement de base (connexion, création du compte
/// admin d'un nouveau fichier, brouillons, réglages).
class LicenceWriteGuard extends QueryInterceptor {
  /// Mis à jour par `licenceProvider` (lib/app/providers/licence_provider.dart).
  static bool lectureSeule = false;

  /// Incrémenté à chaque écriture refusée, pour afficher une
  /// explication à l'utilisateur (LicenceBlockedTrigger dans le shell).
  static final ValueNotifier<int> tentativesBloquees = ValueNotifier(0);

  static const Set<String> tablesToujoursModifiables = {
    'users',
    'app_settings',
    'drafts',
  };

  static final RegExp _ecriture = RegExp(
    r'^\s*(?:INSERT(?:\s+OR\s+\w+)?\s+INTO|REPLACE\s+INTO|UPDATE(?:\s+OR\s+\w+)?|DELETE\s+FROM)\s+["`\[]?(\w+)',
    caseSensitive: false,
  );

  /// Pendant l'ouverture de la base (migrations de schéma), tout est
  /// permis : sans ça un ancien fichier .mstk ne pourrait plus être
  /// mis à niveau, donc plus être consulté.
  int _ouverturesEnCours = 0;

  /// Retourne true si [sql] est une écriture interdite en lecture seule.
  /// [ecritureCertaine] : appel issu de runInsert/runUpdate/runDelete —
  /// une requête qu'on ne sait pas analyser est alors refusée par
  /// prudence.
  static bool estEcritureInterdite(String sql, {required bool ecritureCertaine}) {
    final m = _ecriture.firstMatch(sql);
    if (m == null) return ecritureCertaine;
    return !tablesToujoursModifiables.contains(m.group(1)!.toLowerCase());
  }

  void _verifier(String sql, {required bool ecritureCertaine}) {
    if (!lectureSeule || _ouverturesEnCours > 0) return;
    if (estEcritureInterdite(sql, ecritureCertaine: ecritureCertaine)) {
      tentativesBloquees.value++;
      throw const LicenceLectureSeuleException();
    }
  }

  @override
  Future<bool> ensureOpen(QueryExecutor executor, QueryExecutorUser user) async {
    _ouverturesEnCours++;
    try {
      return await executor.ensureOpen(user);
    } finally {
      _ouverturesEnCours--;
    }
  }

  @override
  Future<int> runInsert(QueryExecutor executor, String statement, List<Object?> args) async {
    _verifier(statement, ecritureCertaine: true);
    return executor.runInsert(statement, args);
  }

  @override
  Future<int> runUpdate(QueryExecutor executor, String statement, List<Object?> args) async {
    _verifier(statement, ecritureCertaine: true);
    return executor.runUpdate(statement, args);
  }

  @override
  Future<int> runDelete(QueryExecutor executor, String statement, List<Object?> args) async {
    _verifier(statement, ecritureCertaine: true);
    return executor.runDelete(statement, args);
  }

  @override
  Future<void> runCustom(QueryExecutor executor, String statement, List<Object?> args) async {
    _verifier(statement, ecritureCertaine: false);
    return executor.runCustom(statement, args);
  }

  @override
  Future<void> runBatched(QueryExecutor executor, BatchedStatements statements) async {
    for (final sql in statements.statements) {
      _verifier(sql, ecritureCertaine: false);
    }
    return executor.runBatched(statements);
  }
}
