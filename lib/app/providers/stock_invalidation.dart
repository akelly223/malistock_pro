import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../presentation/dashboard/providers/dashboard_provider.dart';
import '../../presentation/articles/providers/article_provider.dart';
import '../../presentation/alerts/providers/stock_alerts_provider.dart';

/// Invalide tous les providers dont les données dépendent du niveau
/// de stock des articles.
///
/// À appeler systématiquement après toute opération qui modifie le
/// stock : vente (sortie), achat fournisseur (entrée), transfert
/// entre magasins, ajustement manuel (perte/casse/correction).
///
/// Centraliser cette liste évite d'oublier un provider lors de
/// l'ajout d'un nouveau point d'écriture du stock, et évite de la
/// dupliquer dans chaque écran concerné.
void invalidateStockDependentProviders(WidgetRef ref) {
  ref.invalidate(articlesListProvider);
  ref.invalidate(filteredArticlesProvider);
  ref.invalidate(stockAlertsProvider);
  ref.invalidate(stockAlertsCountProvider);
  ref.invalidate(dashboardStatsProvider);
}

/// Variante pour les contextes sans WidgetRef (ex: dans un Notifier
/// ou un service appelé depuis plusieurs écrans), utilisable avec un
/// Ref générique.
void invalidateStockDependentProvidersRef(Ref ref) {
  ref.invalidate(articlesListProvider);
  ref.invalidate(filteredArticlesProvider);
  ref.invalidate(stockAlertsProvider);
  ref.invalidate(stockAlertsCountProvider);
  ref.invalidate(dashboardStatsProvider);
}
