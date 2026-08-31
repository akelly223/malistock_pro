import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/providers/repository_providers.dart';
import '../../../domain/entities/article.dart';

/// Liste des articles en alerte (faible ou rupture), triée pour
/// afficher d'abord les ruptures totales puis les stocks faibles.
final stockAlertsProvider =
    FutureProvider.autoDispose<List<ArticleEntity>>((ref) async {
  final repo = ref.watch(articleRepositoryProvider);
  final articles = await repo.getLowStockArticles();
  final tries = [...articles]
    ..sort((a, b) {
      if (a.estEnRuptureTotale && !b.estEnRuptureTotale) return -1;
      if (!a.estEnRuptureTotale && b.estEnRuptureTotale) return 1;
      return a.stockTotal.compareTo(b.stockTotal);
    });
  return tries;
});

/// Nombre total d'articles en alerte, pour le badge de la cloche.
final stockAlertsCountProvider = FutureProvider.autoDispose<int>((ref) async {
  final alerts = await ref.watch(stockAlertsProvider.future);
  return alerts.length;
});

/// Indique si la popup d'alerte au démarrage a déjà été affichée
/// pendant cette session (réinitialisé à chaque relance de l'app,
/// volontairement non persisté en base pour rester simple).
final startupAlertShownProvider = StateProvider<bool>((ref) => false);

/// Indique si le vérificateur de brouillons au démarrage a déjà tourné
/// pendant cette session.
final startupDraftCheckerShownProvider =
    StateProvider<bool>((ref) => false);
