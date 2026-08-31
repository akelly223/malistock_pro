import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_text_styles.dart';
import '../../app/providers/repository_providers.dart';
import '../../app/providers/session_provider.dart';
import '../../core/constants/app_identity.dart';
import '../../core/utils/date_formatter.dart';
import '../../core/permissions/permissions.dart';

// ── Provider ─────────────────────────────────────────────────────────────────

final _diagnosticProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final db = ref.read(databaseProvider);
  return db.getDiagnosticInfo();
});

// ── Écran principal ───────────────────────────────────────────────────────────

/// Écran de diagnostic technique, accessible uniquement aux administrateurs
/// depuis "À propos". Fournit toutes les informations utiles pour le support.
class DiagnosticScreen extends ConsumerWidget {
  const DiagnosticScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(sessionProvider);
    if (!Permissions.peutGererParametresEntreprise(user)) {
      return Scaffold(
        appBar: AppBar(title: const Text('Diagnostic technique')),
        body: const Center(
          child: Text('Accès réservé aux administrateurs.'),
        ),
      );
    }

    final diagAsync = ref.watch(_diagnosticProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Diagnostic technique'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Actualiser',
            onPressed: () => ref.invalidate(_diagnosticProvider),
          ),
        ],
      ),
      body: diagAsync.when(
        data: (info) => _DiagnosticBody(info: info),
        loading: () => const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Analyse en cours…'),
            ],
          ),
        ),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline,
                  size: 48, color: AppColors.danger),
              const SizedBox(height: 12),
              Text(
                'Erreur lors du diagnostic :\n$e',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.danger),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Corps du diagnostic ───────────────────────────────────────────────────────

class _DiagnosticBody extends StatelessWidget {
  final Map<String, dynamic> info;

  const _DiagnosticBody({required this.info});

  // ── Helpers d'accès sécurisé ─────────────────────────────────────────────

  String _str(String cle, {String defaut = 'Non disponible'}) {
    final v = info[cle];
    if (v == null) return defaut;
    return v.toString();
  }

  int _int(String cle, {int defaut = 0}) {
    final v = info[cle];
    if (v == null) return defaut;
    return v is int ? v : int.tryParse(v.toString()) ?? defaut;
  }

  bool _bool(String cle) => info[cle] == true;

  DateTime? _date(String cle) {
    final v = info[cle];
    return v is DateTime ? v : null;
  }

  Map<String, bool> _colonnes() {
    final v = info['colonnesImportantes'];
    if (v is Map<String, bool>) return v;
    if (v is Map) {
      return {
        for (final e in v.entries)
          e.key.toString(): e.value == true,
      };
    }
    return {};
  }

  List<String> _tables() {
    final v = info['tablesPresentes'];
    if (v is List<String>) return v;
    if (v is List) return v.map((e) => e.toString()).toList();
    return [];
  }

  // ── Génération du rapport texte pour la copie ─────────────────────────────

  String _genererRapport() {
    final buf = StringBuffer();
    final maintenant = DateFormatter.formatDateTime(DateTime.now());

    buf.writeln('====================================');
    buf.writeln('  DIAGNOSTIC MALISTOCK');
    buf.writeln('  Généré le $maintenant');
    buf.writeln('====================================');
    buf.writeln();

    buf.writeln('--- APPLICATION ---');
    buf.writeln('Nom         : ${AppIdentity.nomApp}');
    buf.writeln('Version     : ${_str("versionApp")}');
    buf.writeln('Plateforme  : ${Platform.operatingSystem}');
    buf.writeln();

    buf.writeln('--- BASE DE DONNÉES ---');
    buf.writeln('Moteur SQLite  : ${_str("sqliteVersion")}');
    buf.writeln('Schéma (code)  : ${_str("schemaVersionCode")}');
    buf.writeln('Schéma (base)  : ${_str("userVersionBase")}');
    final migration = _bool('migrationNecessaire');
    buf.writeln('Statut migration : ${migration ? "⚠️ DÉSYNCHRONISÉ" : "✅ À jour"}');
    buf.writeln('Fichier présent  : ${_bool("fichierExiste") ? "Oui" : "Non"}');
    buf.writeln('Chemin  : ${_str("cheminFichier")}');
    final taille = info['tailleFichier'] as int?;
    buf.writeln(
        'Taille  : ${taille != null ? "${(taille / 1024).toStringAsFixed(1)} Ko" : "Non disponible"}');
    final dateMod = _date('dateModification');
    buf.writeln(
        'Modifié : ${dateMod != null ? DateFormatter.formatDateTime(dateMod) : "Non disponible"}');
    buf.writeln();

    buf.writeln('--- DONNÉES ---');
    buf.writeln('Articles             : ${_int("nbArticles")}');
    buf.writeln('Clients              : ${_int("nbClients")}');
    buf.writeln('Fournisseurs         : ${_int("nbFournisseurs")}');
    buf.writeln('Factures (classiques): ${_int("nbFacturesV1")}');
    buf.writeln('Documents V2         : ${_int("nbDocumentsV2")}');
    buf.writeln('Achats               : ${_int("nbAchats")}');
    buf.writeln('Mouvements de stock  : ${_int("nbMouvementsStock")}');
    buf.writeln();

    buf.writeln('--- INTÉGRITÉ ---');
    buf.writeln('Résultat : ${_str("integrite")}');
    buf.writeln();

    buf.writeln('--- SAUVEGARDES ---');
    final derniere = _date('derniereSauvegarde');
    buf.writeln(
        'Dernière : ${derniere != null ? DateFormatter.formatDateTime(derniere) : "Aucune"}');
    buf.writeln('Nombre   : ${_int("nombreSauvegardes")}');
    buf.writeln();

    buf.writeln('--- COLONNES MIGRÉES ---');
    _colonnes().forEach((col, ok) {
      buf.writeln('${ok ? "✓" : "✗"} $col');
    });
    buf.writeln();

    buf.writeln('--- TABLES PRÉSENTES (${_tables().length}) ---');
    for (final t in _tables()) {
      buf.writeln('  $t');
    }

    return buf.toString();
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final colonnes = _colonnes();
    final tables = _tables();
    final taille = info['tailleFichier'] as int?;
    final dateMod = _date('dateModification');
    final derniere = _date('derniereSauvegarde');
    final migrationNecessaire = _bool('migrationNecessaire');
    final integrite = _str('integrite');
    final integriteOk = integrite == 'ok';

    return Column(
      children: [
        // ── Bannière globale ───────────────────────────────────────────
        _BanniereStatut(
          migrationNecessaire: migrationNecessaire,
          fichierExiste: _bool('fichierExiste'),
          integriteOk: integriteOk,
          colonnesManquantes:
              colonnes.values.where((v) => !v).length,
        ),

        // ── Sections scrollables ───────────────────────────────────────
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 860),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Application
                    _Section(
                      titre: 'Application',
                      couleur: AppColors.primary,
                      icon: Icons.apps_rounded,
                      lignes: [
                        _Ligne('Nom', AppIdentity.nomApp),
                        _Ligne('Version', _str('versionApp')),
                        _Ligne('Plateforme', Platform.operatingSystem),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Base de données
                    _Section(
                      titre: 'Base de données SQLite',
                      couleur: migrationNecessaire
                          ? AppColors.danger
                          : AppColors.success,
                      icon: Icons.storage_rounded,
                      lignes: [
                        _Ligne('Moteur SQLite', _str('sqliteVersion')),
                        _Ligne('Schéma attendu (code)',
                            _str('schemaVersionCode')),
                        _Ligne(
                          'Schéma enregistré (base)',
                          _str('userVersionBase'),
                          alerte: migrationNecessaire,
                        ),
                        _Ligne(
                          'Statut migration',
                          migrationNecessaire
                              ? '⚠️ DÉSYNCHRONISÉ — migration manquée !'
                              : '✅ À jour',
                          alerte: migrationNecessaire,
                        ),
                        _Ligne(
                          'Fichier présent',
                          _bool('fichierExiste')
                              ? '✅ Oui'
                              : '❌ Non — chemin incorrect ou base vide',
                          alerte: !_bool('fichierExiste'),
                        ),
                        _Ligne(
                          'Chemin',
                          _str('cheminFichier'),
                          copiable: true,
                          context: context,
                        ),
                        _Ligne(
                          'Taille',
                          taille != null
                              ? '${(taille / 1024).toStringAsFixed(1)} Ko'
                              : 'Non disponible',
                        ),
                        _Ligne(
                          'Dernière modification',
                          dateMod != null
                              ? DateFormatter.formatDateTime(dateMod)
                              : 'Non disponible',
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Compteurs
                    _Section(
                      titre: 'Données enregistrées',
                      couleur: AppColors.secondary,
                      icon: Icons.bar_chart_rounded,
                      lignes: [
                        _Ligne('Articles', '${_int("nbArticles")}'),
                        _Ligne('Clients', '${_int("nbClients")}'),
                        _Ligne('Fournisseurs', '${_int("nbFournisseurs")}'),
                        _Ligne('Factures (classiques)',
                            '${_int("nbFacturesV1")}'),
                        _Ligne('Documents V2 (toutes pièces)',
                            '${_int("nbDocumentsV2")}'),
                        _Ligne('Achats', '${_int("nbAchats")}'),
                        _Ligne('Mouvements de stock',
                            '${_int("nbMouvementsStock")}'),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Intégrité
                    _Section(
                      titre: 'Intégrité SQLite',
                      couleur:
                          integriteOk ? AppColors.success : AppColors.danger,
                      icon: Icons.verified_rounded,
                      lignes: [
                        _Ligne(
                          'PRAGMA integrity_check',
                          integriteOk ? '✅ OK' : '❌ $integrite',
                          alerte: !integriteOk,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Sauvegardes
                    _Section(
                      titre: 'Sauvegardes',
                      couleur: AppColors.warning,
                      icon: Icons.backup_rounded,
                      lignes: [
                        _Ligne(
                          'Dernière sauvegarde',
                          derniere != null
                              ? DateFormatter.formatDateTime(derniere)
                              : 'Aucune sauvegarde trouvée',
                          alerte: derniere == null,
                        ),
                        _Ligne(
                          'Nombre de sauvegardes',
                          '${_int("nombreSauvegardes")}',
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Colonnes migrées
                    () {
                      final absentes =
                          colonnes.values.where((v) => !v).length;
                      return _Section(
                        titre: 'Colonnes des migrations'
                            '${absentes > 0 ? " — $absentes ABSENTE(S)" : " — toutes présentes"}',
                        couleur: absentes > 0
                            ? AppColors.danger
                            : AppColors.success,
                        icon: Icons.schema_rounded,
                        lignes: colonnes.entries
                            .map((e) => _Ligne(
                                  e.key,
                                  e.value
                                      ? '✅ Présente'
                                      : '❌ ABSENTE — migration non exécutée',
                                  alerte: !e.value,
                                ))
                            .toList(),
                      );
                    }(),
                    const SizedBox(height: 16),

                    // Tables présentes
                    _Section(
                      titre: 'Tables présentes (${tables.length})',
                      couleur: AppColors.textSecondary,
                      icon: Icons.table_chart_rounded,
                      lignes: tables
                          .map((t) => _Ligne('', t))
                          .toList(),
                    ),

                    const SizedBox(height: 32),

                    // Bouton Copier
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.copy_all_rounded),
                        label: const Text('COPIER LE DIAGNOSTIC'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          textStyle: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                        onPressed: () {
                          Clipboard.setData(
                              ClipboardData(text: _genererRapport()));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Row(
                                children: [
                                  Icon(Icons.check_rounded,
                                      color: Colors.white, size: 18),
                                  SizedBox(width: 10),
                                  Text('Diagnostic copié dans le presse-papiers'),
                                ],
                              ),
                              backgroundColor: AppColors.success,
                              duration: Duration(seconds: 3),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Envoyez ce diagnostic au support technique pour accélérer la résolution de tout problème.',
                      style: AppTextStyles.caption,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Bannière de statut global ─────────────────────────────────────────────────

class _BanniereStatut extends StatelessWidget {
  final bool migrationNecessaire;
  final bool fichierExiste;
  final bool integriteOk;
  final int colonnesManquantes;

  const _BanniereStatut({
    required this.migrationNecessaire,
    required this.fichierExiste,
    required this.integriteOk,
    required this.colonnesManquantes,
  });

  @override
  Widget build(BuildContext context) {
    final problemes = <String>[];
    if (migrationNecessaire) problemes.add('Schéma désynchronisé');
    if (!fichierExiste) problemes.add('Fichier DB introuvable');
    if (!integriteOk) problemes.add('Intégrité corrompue');
    if (colonnesManquantes > 0) {
      problemes.add('$colonnesManquantes colonne(s) manquante(s)');
    }

    final sain = problemes.isEmpty;
    return Container(
      width: double.infinity,
      color: sain
          ? AppColors.success.withValues(alpha: 0.10)
          : AppColors.danger.withValues(alpha: 0.10),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Row(
        children: [
          Icon(
            sain ? Icons.check_circle_rounded : Icons.warning_amber_rounded,
            color: sain ? AppColors.success : AppColors.danger,
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              sain
                  ? 'Base de données saine — aucun problème détecté.'
                  : 'Problème(s) détecté(s) : ${problemes.join(", ")}.',
              style: TextStyle(
                color: sain ? AppColors.success : AppColors.danger,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Section ───────────────────────────────────────────────────────────────────

class _Section extends StatelessWidget {
  final String titre;
  final Color couleur;
  final IconData icon;
  final List<_Ligne> lignes;

  const _Section({
    required this.titre,
    required this.couleur,
    required this.icon,
    required this.lignes,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // En-tête section
          Container(
            width: double.infinity,
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: couleur.withValues(alpha: 0.10),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                Icon(icon, size: 16, color: couleur),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    titre,
                    style: AppTextStyles.bodyBold.copyWith(color: couleur),
                  ),
                ),
              ],
            ),
          ),
          // Lignes
          if (lignes.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Text('Aucune information disponible.'),
            )
          else
            ...lignes.map((l) => _LigneTile(ligne: l)),
        ],
      ),
    );
  }
}

// ── Modèle de ligne ───────────────────────────────────────────────────────────

class _Ligne {
  final String cle;
  final String valeur;
  final bool alerte;
  final bool copiable;
  final BuildContext? context;

  const _Ligne(
    this.cle,
    this.valeur, {
    this.alerte = false,
    this.copiable = false,
    this.context,
  });
}

// ── Tuile d'une ligne ─────────────────────────────────────────────────────────

class _LigneTile extends StatelessWidget {
  final _Ligne ligne;

  const _LigneTile({required this.ligne});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: ligne.alerte
            ? AppColors.danger.withValues(alpha: 0.05)
            : null,
        border: const Border(
            top: BorderSide(color: AppColors.border, width: 0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (ligne.cle.isNotEmpty) ...[
            SizedBox(
              width: 260,
              child: Text(ligne.cle, style: AppTextStyles.caption),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Text(
              ligne.valeur,
              style: AppTextStyles.body.copyWith(
                color: ligne.alerte ? AppColors.danger : null,
                fontWeight: ligne.alerte ? FontWeight.w600 : null,
                fontFamily:
                    ligne.copiable ? 'monospace' : null,
                fontSize: ligne.copiable ? 12 : null,
              ),
            ),
          ),
          if (ligne.copiable)
            IconButton(
              icon: const Icon(Icons.copy_rounded, size: 15),
              tooltip: 'Copier le chemin',
              padding: EdgeInsets.zero,
              constraints:
                  const BoxConstraints(minWidth: 32, minHeight: 32),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: ligne.valeur));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Chemin copié'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
