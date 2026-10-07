import 'package:cryptography/cryptography.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:malistock_pro/core/licence/licence_config.dart';
import 'package:malistock_pro/core/licence/licence_key.dart';
import 'package:malistock_pro/core/licence/licence_service.dart';
import 'package:malistock_pro/core/licence/licence_write_guard.dart';
import 'package:malistock_pro/core/permissions/permissions.dart';
import 'package:malistock_pro/data/local/database.dart';

/// Stockage en mémoire à deux exemplaires (comme fichier + registre).
class _StockageMemoire implements StockageLicence {
  final fichier = <String, String>{};
  final registre = <String, String>{};

  @override
  Future<List<String?>> lire(String nom) async => [fichier[nom], registre[nom]];

  @override
  Future<void> ecrire(String nom, String valeur) async {
    fichier[nom] = valeur;
    registre[nom] = valeur;
  }
}

void main() {
  const machine = '4c4c4544-0042-3510-8051-b4c04f4e3332';
  const autreMachine = '11111111-2222-3333-4444-555555555555';

  group('Clés de licence', () {
    late SimpleKeyPair paire;
    late List<int> publique;

    setUpAll(() async {
      paire = await Ed25519().newKeyPair();
      publique = (await paire.extractPublicKey()).bytes;
    });

    Future<String> cleePour(String idMachine, {String produit = 'MSP1'}) =>
        LicenceKey.generer(
          produit: produit,
          empreinte: LicenceKey.empreinteMachine(idMachine, produit),
          clePrivee: paire,
        );

    Future<bool> verifier(String cle, String idMachine) => LicenceKey.verifier(
          cle: cle,
          produit: 'MSP1',
          empreinte: LicenceKey.empreinteMachine(idMachine, 'MSP1'),
          clePublique: publique,
        );

    test('une clé générée pour ce PC est acceptée', () async {
      expect(await verifier(await cleePour(machine), machine), isTrue);
    });

    test('tolère minuscules, espaces et retours à la ligne', () async {
      final cle = await cleePour(machine);
      final abimee = '  ${cle.toLowerCase().replaceAll('-', ' \n')}  ';
      expect(await verifier(abimee, machine), isTrue);
    });

    test('refuse la clé d\'un autre PC', () async {
      expect(await verifier(await cleePour(autreMachine), machine), isFalse);
    });

    test('refuse la clé d\'une application sœur', () async {
      expect(await verifier(await cleePour(machine, produit: 'GCO1'), machine),
          isFalse);
    });

    test('refuse une clé modifiée ou tronquée', () async {
      final cle = await cleePour(machine);
      final dernier = cle[cle.length - 1];
      final modifiee =
          cle.substring(0, cle.length - 1) + (dernier == 'A' ? 'B' : 'A');
      expect(await verifier(modifiee, machine), isFalse);
      expect(await verifier(cle.substring(0, 40), machine), isFalse);
      expect(await verifier('n\'importe quoi', machine), isFalse);
    });

    test('refuse une clé signée par quelqu\'un d\'autre', () async {
      final pirate = await Ed25519().newKeyPair();
      final cle = await LicenceKey.generer(
        produit: 'MSP1',
        empreinte: LicenceKey.empreinteMachine(machine, 'MSP1'),
        clePrivee: pirate,
      );
      expect(await verifier(cle, machine), isFalse);
    });

    test('le code PC se relit à l\'identique', () {
      final empreinte = LicenceKey.empreinteMachine(machine, 'MSP1');
      final code = LicenceKey.codePc(empreinte);
      expect(code, matches(RegExp(r'^[A-Z2-7]{4}(-[A-Z2-7]{4}){3}$')));
      expect(LicenceKey.lireCodePc(code.toLowerCase()), empreinte);
    });
  });

  group('Période d\'essai', () {
    final debut = DateTime.utc(2026, 10, 1, 9);

    test('jour 1 : ${LicenceConfig.joursEssai} jours restants', () {
      final etat = LicenceService.evaluerEssai(
          EtatEssai(debut, debut), debut, 'X');
      expect(etat.statut, StatutLicence.essai);
      expect(etat.joursRestants, LicenceConfig.joursEssai);
      expect(etat.lectureSeule, isFalse);
      expect(etat.afficherRappel, isFalse);
    });

    test('rappel dans les derniers jours', () {
      final maintenant = debut.add(const Duration(days: LicenceConfig.joursEssai - 10));
      final etat = LicenceService.evaluerEssai(
          EtatEssai(debut, maintenant), maintenant, 'X');
      expect(etat.joursRestants, 10);
      expect(etat.afficherRappel, isTrue);
    });

    test('après ${LicenceConfig.joursEssai} jours : lecture seule', () {
      final maintenant = debut.add(const Duration(days: LicenceConfig.joursEssai, minutes: 1));
      final etat = LicenceService.evaluerEssai(
          EtatEssai(debut, maintenant), maintenant, 'X');
      expect(etat.statut, StatutLicence.expire);
      expect(etat.lectureSeule, isTrue);
    });

    test('horloge reculée au-delà de la tolérance : lecture seule', () {
      final dernierVu = debut.add(const Duration(days: 30));
      final etat = LicenceService.evaluerEssai(
          EtatEssai(debut, dernierVu), debut.add(const Duration(days: 5)), 'X');
      expect(etat.statut, StatutLicence.horlogeIncoherente);
      expect(etat.lectureSeule, isTrue);
    });

    test('petit recul (fuseau horaire) toléré', () {
      final dernierVu = debut.add(const Duration(days: 30));
      final etat = LicenceService.evaluerEssai(EtatEssai(debut, dernierVu),
          dernierVu.subtract(const Duration(hours: 3)), 'X');
      expect(etat.statut, StatutLicence.essai);
    });
  });

  group('LicenceService (stockage)', () {
    late _StockageMemoire stockage;
    late DateTime maintenant;

    LicenceService service() => LicenceService(
          stockage: stockage,
          identifiantMachine: machine,
          horloge: () => maintenant,
        );

    setUp(() {
      stockage = _StockageMemoire();
      maintenant = DateTime.utc(2026, 10, 7, 10);
    });

    test('premier lancement : essai complet, état enregistré en double', () async {
      final etat = await service().charger();
      expect(etat.statut, StatutLicence.essai);
      expect(etat.joursRestants, LicenceConfig.joursEssai);
      expect(stockage.fichier['E'], isNotNull);
      expect(stockage.registre['E'], stockage.fichier['E']);
    });

    test('supprimer le fichier ne relance pas l\'essai (copie registre)', () async {
      await service().charger();
      maintenant = maintenant.add(const Duration(days: 100));
      stockage.fichier.remove('E');
      final etat = await service().charger();
      expect(etat.statut, StatutLicence.expire);
    });

    test('état modifié à la main partout : essai terminé', () async {
      await service().charger();
      stockage.fichier['E'] = '{"d":9999999999999,"v":9999999999999,"s":"faux"}';
      stockage.registre['E'] = stockage.fichier['E']!;
      final etat = await service().charger();
      expect(etat.statut, StatutLicence.expire);
    });

    test('une copie modifiée, l\'autre intacte : on garde l\'intacte', () async {
      await service().charger();
      stockage.fichier['E'] = 'abîmé';
      maintenant = maintenant.add(const Duration(days: 1));
      final etat = await service().charger();
      expect(etat.statut, StatutLicence.essai);
      expect(etat.joursRestants, LicenceConfig.joursEssai - 1);
    });

    test('reculer l\'horloge après usage : détecté, puis rétabli', () async {
      await service().charger();
      maintenant = maintenant.add(const Duration(days: 60));
      await service().charger(); // dernier vu = J+60
      maintenant = maintenant.subtract(const Duration(days: 50));
      expect((await service().charger()).statut, StatutLicence.horlogeIncoherente);
      maintenant = maintenant.add(const Duration(days: 50)); // heure corrigée
      expect((await service().charger()).statut, StatutLicence.essai);
    });

    test('clé invalide refusée, état inchangé', () async {
      await service().charger();
      expect(await service().activer('AAAA-BBBB'), isNull);
      expect(stockage.fichier['L'], isNull);
    });
  });

  group('Verrou lecture seule (base de données)', () {
    test('analyse des requêtes', () {
      bool interdit(String sql, {bool certaine = true}) =>
          LicenceWriteGuard.estEcritureInterdite(sql, ecritureCertaine: certaine);

      expect(interdit('INSERT INTO "invoices" ("a") VALUES (?)'), isTrue);
      expect(interdit('UPDATE "articles" SET "prix" = ?'), isTrue);
      expect(interdit('DELETE FROM "clients" WHERE id = ?'), isTrue);
      expect(interdit('insert or replace into stock_movements values (?)'), isTrue);
      expect(interdit('INSERT INTO "users" ("nom") VALUES (?)'), isFalse);
      expect(interdit('UPDATE "app_settings" SET x = ?'), isFalse);
      expect(interdit('DELETE FROM "drafts"'), isFalse);
      expect(interdit('PRAGMA foreign_keys = ON', certaine: false), isFalse);
      expect(interdit('SELECT 1', certaine: false), isFalse);
      // Requête d'écriture impossible à analyser : refusée par prudence.
      expect(interdit('WITH x AS (SELECT 1) INSERT INTO invoices SELECT * FROM x'),
          isTrue);
    });

    test('bloque les écritures métier, laisse lire et créer un compte', () async {
      final db = AppDatabase.withExecutor(
          NativeDatabase.memory().interceptWith(LicenceWriteGuard()));
      addTearDown(() async {
        LicenceWriteGuard.lectureSeule = false;
        await db.close();
      });

      final idMagasin = await db.storesDao
          .createStore(StoresCompanion.insert(nom: 'Boutique'));

      LicenceWriteGuard.lectureSeule = true;
      final avant = LicenceWriteGuard.tentativesBloquees.value;

      await expectLater(
        db.storesDao.createStore(StoresCompanion.insert(nom: 'Dépôt')),
        throwsA(isA<LicenceLectureSeuleException>()),
      );
      await expectLater(
        db.transaction(() async {
          await db.into(db.stores).insert(StoresCompanion.insert(nom: 'T'));
        }),
        throwsA(isA<LicenceLectureSeuleException>()),
      );
      expect(LicenceWriteGuard.tentativesBloquees.value, greaterThan(avant));

      // Lecture toujours possible, rien n'a été ajouté.
      final magasins = await db.select(db.stores).get();
      expect(magasins.map((m) => m.id), [idMagasin]);

      // Tables techniques : toujours modifiables.
      await db.into(db.users).insert(UsersCompanion.insert(
          nom: 'Admin', login: 'admin', motDePasseHash: 'h', role: 'admin'));

      LicenceWriteGuard.lectureSeule = false;
      await db.storesDao.createStore(StoresCompanion.insert(nom: 'Dépôt'));
      expect(await db.select(db.stores).get(), hasLength(2));
    });
  });

  group('Pages de saisie fermées en lecture seule', () {
    test('création, modification et import bloqués', () {
      for (final chemin in [
        '/invoices/new',
        '/purchases/12/edit',
        '/factures-v2/new',
        '/clients/3/edit',
        '/articles/new',
        '/articles/import',
        '/migration/articles',
      ]) {
        expect(Permissions.estPageDeSaisie(chemin), isTrue, reason: chemin);
      }
    });

    test('consultation toujours ouverte', () {
      for (final chemin in [
        '/dashboard',
        '/invoices',
        '/invoices/12',
        '/articles/5/edit', // fiche article = écran de consultation
        '/licence',
        '/settings',
        '/migration',
      ]) {
        expect(Permissions.estPageDeSaisie(chemin), isFalse, reason: chemin);
      }
    });
  });
}
