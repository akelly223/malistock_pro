import 'package:flutter/material.dart';
import 'article.dart';

// ── Entités secondaires ──────────────────────────────────────────────────────

class ProduitVenduEntity {
  final int articleId;
  final String articleNom;
  final double quantiteVendue;
  final double totalVentes;

  const ProduitVenduEntity({
    required this.articleId,
    required this.articleNom,
    required this.quantiteVendue,
    required this.totalVentes,
  });
}

/// Point pour les graphiques (jour / semaine / mois).
class PointVenteEntity {
  final DateTime date;
  final double total;

  const PointVenteEntity({required this.date, required this.total});
}

class TopClientEntity {
  final int clientId;
  final String clientNom;
  final double totalAchats;
  final int nombreFactures;
  final double detteTotale;

  const TopClientEntity({
    required this.clientId,
    required this.clientNom,
    required this.totalAchats,
    required this.nombreFactures,
    required this.detteTotale,
  });
}

enum ConseilType { success, info, warning, danger }

class ConseilDashboard {
  final String message;
  final ConseilType type;

  const ConseilDashboard({required this.message, required this.type});

  IconData get icone => switch (type) {
        ConseilType.success => Icons.check_circle_outline_rounded,
        ConseilType.info => Icons.lightbulb_outline_rounded,
        ConseilType.warning => Icons.info_outline_rounded,
        ConseilType.danger => Icons.warning_amber_rounded,
      };

  Color get couleur => switch (type) {
        ConseilType.success => const Color(0xFF2E8B57),
        ConseilType.info => const Color(0xFF1E6F46),
        ConseilType.warning => const Color(0xFFD9A226),
        ConseilType.danger => const Color(0xFFC23B33),
      };

  Color get couleurFond => switch (type) {
        ConseilType.success => const Color(0xFFE5F4EC),
        ConseilType.info => const Color(0xFFE7F4ED),
        ConseilType.warning => const Color(0xFFFCF3DD),
        ConseilType.danger => const Color(0xFFFBE7E5),
      };
}

// ── Entité principale ────────────────────────────────────────────────────────

class DashboardStatsEntity {
  // ── Ventes : CA fixe, toujours affiché quelle que soit la période
  // sélectionnée dans le sélecteur (Aujourd'hui / Semaine / Mois / Année).
  final double ventesJour;
  final double ventesSemaine;
  final double ventesMois;
  final double ventesAnnee;

  // ── CA et bénéfice recalculés pour la période sélectionnée dans le
  // sélecteur (jour/semaine/mois/trimestre/semestre/année). C'est ce
  // couple qui doit changer à chaque clic sur le sélecteur de période.
  final double caPeriodeSelectionnee;
  final double? beneficePeriodeSelectionnee;

  // ── Achats : montant recalculé pour la période sélectionnée.
  final double achatsPeriodeSelectionnee;

  // ── Documents : comptages recalculés pour la période sélectionnée.
  // "ventes" et "factures" désignent la même notion dans ce logiciel
  // (chaque vente validée est une facture) : même valeur, deux libellés.
  final int nombreVentesPeriode;
  final int nombreFacturesPeriode;
  final int nombreAchatsPeriode;
  final int nombreDevisPeriode;
  final int nombreProformasPeriode;

  // ── Comparaison mois précédent (toujours sur le mois, indépendant
  // de la période sélectionnée — sert au badge de tendance).
  final double ventesMoisPrecedent;
  final double beneficeMoisPrecedent;

  // ── Dettes clients (cumulatif, pas de notion de période).
  final double totalDettesClients;
  final int nombreClientsAvecDette;

  // ── Articles (cumulatif).
  final int nombreArticles;
  final double valeurStock;
  final int nombreRuptures;
  final int nombreAlertes;

  // ── Clients / Fournisseurs.
  final int nombreClients;
  final int nouveauxClientsPeriode;
  final int nombreFournisseurs;

  // ── Listes.
  final List<ArticleEntity> produitsEnRupture;
  final List<ProduitVenduEntity> produitsLesPlusVendus;
  final List<TopClientEntity> topClients;
  final List<ArticleEntity> articlesDormants;

  // ── Graphiques.
  final List<PointVenteEntity> ventesParJour; // 7 derniers jours
  final List<PointVenteEntity> ventesParJour30; // 30 derniers jours
  final List<PointVenteEntity> ventesParMois12; // 12 derniers mois

  // ── Pipeline documents commerciaux V2 (statuts en attente, hors
  // notion de période : ce sont des alertes opérationnelles).
  final int nombreProformasBrouillon;
  final int nombreBCEnAttente;

  // ── Conseils intelligents.
  final List<ConseilDashboard> conseils;

  const DashboardStatsEntity({
    required this.ventesJour,
    required this.ventesSemaine,
    required this.ventesMois,
    required this.ventesAnnee,
    required this.caPeriodeSelectionnee,
    this.beneficePeriodeSelectionnee,
    this.achatsPeriodeSelectionnee = 0,
    this.nombreVentesPeriode = 0,
    this.nombreFacturesPeriode = 0,
    this.nombreAchatsPeriode = 0,
    this.nombreDevisPeriode = 0,
    this.nombreProformasPeriode = 0,
    this.ventesMoisPrecedent = 0,
    this.beneficeMoisPrecedent = 0,
    this.totalDettesClients = 0,
    this.nombreClientsAvecDette = 0,
    this.nombreArticles = 0,
    this.valeurStock = 0,
    this.nombreRuptures = 0,
    this.nombreAlertes = 0,
    this.nombreClients = 0,
    this.nouveauxClientsPeriode = 0,
    this.nombreFournisseurs = 0,
    required this.produitsEnRupture,
    required this.produitsLesPlusVendus,
    this.topClients = const [],
    this.articlesDormants = const [],
    required this.ventesParJour,
    this.ventesParJour30 = const [],
    this.ventesParMois12 = const [],
    this.nombreProformasBrouillon = 0,
    this.nombreBCEnAttente = 0,
    this.conseils = const [],
  });

  /// Variation CA mois actuel vs mois précédent (en %).
  /// Retourne null si le mois précédent était à 0.
  double? get variationMois {
    if (ventesMoisPrecedent == 0) return null;
    return (ventesMois - ventesMoisPrecedent) / ventesMoisPrecedent * 100;
  }
}
