import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/providers/repository_providers.dart';
import '../../../domain/entities/depot_vente_stat.dart';
import '../../../domain/entities/depot_vente_reglement.dart';

export '../../../domain/entities/depot_vente_stat.dart'
    show DepotVentePeriode, DepotVenteStatEntity, DepotVentePeriodeLabel;
export '../../../domain/entities/depot_vente_reglement.dart'
    show
        DepotVenteLigneARegulerEntity,
        DepotVenteReglementEntity,
        DepotVenteReglementLigneEntity,
        DepotVenteReglementStatut,
        DepotVenteReglementStatutLabel;

/// Auteur sélectionné pour filtrer l'écran Dépôt-vente (null = tous les
/// auteurs). Réutilisé par l'onglet Règlements (§10) et l'onglet Stock.
final depotVenteFournisseurFiltreProvider =
    StateProvider.autoDispose<int?>((ref) => null);

/// Statut affiché dans l'onglet Règlements — défaut « à régler » pour
/// que l'utilisateur voie d'abord ce qu'il doit encore reverser.
enum DepotVenteFiltreStatut { tous, aRegler, regles }

final depotVenteFiltreStatutProvider =
    StateProvider.autoDispose<DepotVenteFiltreStatut>(
        (ref) => DepotVenteFiltreStatut.aRegler);

/// Stock/ventes par titre en dépôt, toutes périodes confondues (l'onglet
/// Stock n'a pas de filtre période — voir cahier des charges §7).
final depotVenteStatsProvider =
    FutureProvider.autoDispose<List<DepotVenteStatEntity>>((ref) async {
  final repo = ref.watch(depotVenteRepositoryProvider);
  return repo.getDepotArticlesStats(periode: DepotVentePeriode.tout);
});

/// Tout ce qui est vendu et pas encore réglé, tous auteurs confondus —
/// le filtrage par auteur se fait côté écran sur cette liste.
final depotVenteLignesARegulerProvider =
    FutureProvider.autoDispose<List<DepotVenteLigneARegulerEntity>>((ref) async {
  final repo = ref.watch(depotVenteRepositoryProvider);
  return repo.getLignesARegler();
});

/// Historique permanent des règlements confirmés, tous auteurs confondus.
final depotVenteHistoriqueProvider =
    FutureProvider.autoDispose<List<DepotVenteReglementEntity>>((ref) async {
  final repo = ref.watch(depotVenteRepositoryProvider);
  return repo.getHistoriqueReglements();
});
