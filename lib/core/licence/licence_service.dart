import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'licence_config.dart';
import 'licence_key.dart';
import 'windows_registry.dart';

enum StatutLicence {
  /// Période d'essai gratuite en cours : tout est permis.
  essai,

  /// Clé de licence valide activée : tout est permis, sans limite.
  licencie,

  /// Essai terminé sans licence : lecture seule.
  expire,

  /// La date du PC a reculé (tentative de prolonger l'essai, ou pile
  /// BIOS déchargée) : lecture seule jusqu'à correction de l'heure.
  horlogeIncoherente,
}

class EtatLicence {
  final StatutLicence statut;
  final String codePc;
  final int joursRestants;
  final DateTime? finEssai;

  const EtatLicence({
    required this.statut,
    required this.codePc,
    this.joursRestants = 0,
    this.finEssai,
  });

  /// Plus de nouvelles saisies : consultation, impression, export et
  /// sauvegarde restent possibles (les données du client lui
  /// appartiennent, on ne les bloque jamais).
  bool get lectureSeule =>
      statut == StatutLicence.expire ||
      statut == StatutLicence.horlogeIncoherente;

  bool get afficherRappel =>
      statut == StatutLicence.essai &&
      joursRestants <= LicenceConfig.joursAvantRappel;
}

/// Début de l'essai et date la plus récente jamais vue par le logiciel
/// sur ce PC (sert à détecter un recul de l'horloge).
class EtatEssai {
  final DateTime debut;
  final DateTime dernierVu;
  const EtatEssai(this.debut, this.dernierVu);
}

/// Où sont conservées les informations de licence. Chaque valeur est
/// écrite en DEUX exemplaires (fichier AppData + registre) : supprimer
/// l'un ne suffit pas à relancer l'essai.
abstract class StockageLicence {
  /// Un élément par exemplaire (null si absent).
  Future<List<String?>> lire(String nom);
  Future<void> ecrire(String nom, String valeur);
}

class LicenceService {
  static const _nomEssai = 'E';
  static const _nomLicence = 'L';

  // Secret de signature de l'état d'essai : empêche de modifier la date
  // de début à la main. Ce n'est pas une protection absolue (le secret
  // est dans l'exécutable), mais elle suffit à décourager.
  static const _secretEssai = 'mlc-msp-essai-7f3a9c21e4b8';

  final StockageLicence stockage;
  final String identifiantMachine;
  final DateTime Function() horloge;

  LicenceService({
    required this.stockage,
    required this.identifiantMachine,
    DateTime Function()? horloge,
  }) : horloge = horloge ?? DateTime.now;

  /// Service réel : identifiant Windows du PC, stockage fichier + registre.
  factory LicenceService.windows() => LicenceService(
        stockage: StockageLicenceWindows(),
        identifiantMachine: WindowsRegistry.identifiantMachine() ??
            '${Platform.environment['COMPUTERNAME']}|'
                '${Platform.environment['PROCESSOR_IDENTIFIER']}',
      );

  Uint8List get empreinte =>
      LicenceKey.empreinteMachine(identifiantMachine, LicenceConfig.produit);

  String get codePc => LicenceKey.codePc(empreinte);

  /// Calcule l'état au démarrage et met à jour la date "dernier vu".
  Future<EtatLicence> charger() async {
    final maintenant = horloge().toUtc();

    for (final cle in await stockage.lire(_nomLicence)) {
      if (cle != null && await _cleValide(cle)) {
        await stockage.ecrire(_nomLicence, cle); // recopie un exemplaire supprimé
        return EtatLicence(statut: StatutLicence.licencie, codePc: codePc);
      }
    }

    final copies = (await stockage.lire(_nomEssai)).whereType<String>().toList();
    final valides = copies.map(_decoderEssai).whereType<EtatEssai>().toList();

    // Exemplaires présents mais tous modifiés à la main : essai terminé.
    if (copies.isNotEmpty && valides.isEmpty) {
      return EtatLicence(statut: StatutLicence.expire, codePc: codePc);
    }

    final essai = valides.isEmpty
        ? EtatEssai(maintenant, maintenant) // premier lancement
        : EtatEssai(
            valides.map((e) => e.debut).reduce((a, b) => a.isBefore(b) ? a : b),
            valides
                .map((e) => e.dernierVu)
                .reduce((a, b) => a.isAfter(b) ? a : b),
          );

    final etat = evaluerEssai(essai, maintenant, codePc);

    if (etat.statut != StatutLicence.horlogeIncoherente) {
      final dernierVu =
          maintenant.isAfter(essai.dernierVu) ? maintenant : essai.dernierVu;
      await stockage.ecrire(
          _nomEssai, _encoderEssai(EtatEssai(essai.debut, dernierVu)));
    }
    return etat;
  }

  /// Enregistre la clé si elle est valide pour ce PC. Retourne le
  /// nouvel état, ou null si la clé est refusée.
  Future<EtatLicence?> activer(String cle) async {
    final propre = cle.trim();
    if (!await _cleValide(propre)) return null;
    await stockage.ecrire(_nomLicence, propre);
    return EtatLicence(statut: StatutLicence.licencie, codePc: codePc);
  }

  static EtatLicence evaluerEssai(
      EtatEssai essai, DateTime maintenant, String codePc) {
    if (maintenant.isBefore(essai.dernierVu.subtract(LicenceConfig.toleranceRecul))) {
      return EtatLicence(
          statut: StatutLicence.horlogeIncoherente, codePc: codePc);
    }
    final fin = essai.debut.add(const Duration(days: LicenceConfig.joursEssai));
    final restant = fin.difference(maintenant);
    if (restant <= Duration.zero) {
      return EtatLicence(
          statut: StatutLicence.expire, codePc: codePc, finEssai: fin);
    }
    return EtatLicence(
      statut: StatutLicence.essai,
      codePc: codePc,
      joursRestants: (restant.inMinutes / Duration.minutesPerDay).ceil(),
      finEssai: fin,
    );
  }

  Future<bool> _cleValide(String cle) => LicenceKey.verifier(
        cle: cle,
        produit: LicenceConfig.produit,
        empreinte: empreinte,
        clePublique: LicenceConfig.clePublique,
      );

  // Volontairement indépendant de l'identifiant machine : si sa lecture
  // échouait un jour (repli sur COMPUTERNAME), l'essai d'un client
  // honnête ne doit pas être considéré comme falsifié.
  String _signature(int debut, int dernierVu) => crypto.Hmac(
        crypto.sha256,
        utf8.encode(_secretEssai),
      ).convert(utf8.encode('$debut|$dernierVu')).toString();

  String _encoderEssai(EtatEssai essai) {
    final d = essai.debut.millisecondsSinceEpoch;
    final v = essai.dernierVu.millisecondsSinceEpoch;
    return jsonEncode({'d': d, 'v': v, 's': _signature(d, v)});
  }

  EtatEssai? _decoderEssai(String texte) {
    try {
      final json = jsonDecode(texte) as Map<String, dynamic>;
      final d = json['d'] as int;
      final v = json['v'] as int;
      if (json['s'] != _signature(d, v)) return null;
      return EtatEssai(
        DateTime.fromMillisecondsSinceEpoch(d, isUtc: true),
        DateTime.fromMillisecondsSinceEpoch(v, isUtc: true),
      );
    } catch (_) {
      return null;
    }
  }
}

/// Exemplaire 1 : fichiers dans le dossier AppData de l'application.
/// Exemplaire 2 : registre Windows (HKCU), conservé à la désinstallation.
class StockageLicenceWindows implements StockageLicence {
  Future<File> _fichier(String nom) async {
    final dir = await getApplicationSupportDirectory();
    return File(p.join(dir.path, 'cfg_$nom.dat'));
  }

  @override
  Future<List<String?>> lire(String nom) async {
    String? depuisFichier;
    try {
      final f = await _fichier(nom);
      if (await f.exists()) depuisFichier = (await f.readAsString()).trim();
    } catch (_) {}
    final depuisRegistre = WindowsRegistry.lireTexte(
        WindowsRegistry.hkeyCurrentUser, LicenceConfig.cleRegistre, nom);
    return [depuisFichier, depuisRegistre];
  }

  @override
  Future<void> ecrire(String nom, String valeur) async {
    try {
      final f = await _fichier(nom);
      await f.create(recursive: true);
      await f.writeAsString(valeur);
    } catch (_) {}
    WindowsRegistry.ecrireTexte(
        WindowsRegistry.hkeyCurrentUser, LicenceConfig.cleRegistre, nom, valeur);
  }
}
