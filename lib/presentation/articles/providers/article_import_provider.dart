import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/providers/repository_providers.dart';
import '../../../core/services/article_import_service.dart';

class ArticleImportState {
  final List<ArticleImportRow> parsedRows;
  final bool hasStockColumn;
  final Set<String> codesDoublons;
  final DoublonStrategie doublonStrategie;
  final bool importerAvecStock;
  final int? selectedStoreId;
  final Map<String, DoublonStrategie> strategieParArticle;
  final bool isLoading;
  final bool isImporting;
  final double importProgress;
  final ArticleImportResult? resultat;
  final String? errorMessage;

  const ArticleImportState({
    this.parsedRows = const [],
    this.hasStockColumn = false,
    this.codesDoublons = const {},
    this.doublonStrategie = DoublonStrategie.ignorer,
    this.importerAvecStock = false,
    this.selectedStoreId,
    this.strategieParArticle = const {},
    this.isLoading = false,
    this.isImporting = false,
    this.importProgress = 0.0,
    this.resultat,
    this.errorMessage,
  });

  bool get hasParsedRows => parsedRows.isNotEmpty;
  bool get hasDoublons => codesDoublons.isNotEmpty;

  ArticleImportState copyWith({
    List<ArticleImportRow>? parsedRows,
    bool? hasStockColumn,
    Set<String>? codesDoublons,
    DoublonStrategie? doublonStrategie,
    bool? importerAvecStock,
    Object? selectedStoreId = _sentinel,
    Map<String, DoublonStrategie>? strategieParArticle,
    bool? isLoading,
    bool? isImporting,
    double? importProgress,
    Object? resultat = _sentinel,
    Object? errorMessage = _sentinel,
  }) {
    return ArticleImportState(
      parsedRows: parsedRows ?? this.parsedRows,
      hasStockColumn: hasStockColumn ?? this.hasStockColumn,
      codesDoublons: codesDoublons ?? this.codesDoublons,
      doublonStrategie: doublonStrategie ?? this.doublonStrategie,
      importerAvecStock: importerAvecStock ?? this.importerAvecStock,
      selectedStoreId: selectedStoreId == _sentinel
          ? this.selectedStoreId
          : selectedStoreId as int?,
      strategieParArticle: strategieParArticle ?? this.strategieParArticle,
      isLoading: isLoading ?? this.isLoading,
      isImporting: isImporting ?? this.isImporting,
      importProgress: importProgress ?? this.importProgress,
      resultat: resultat == _sentinel
          ? this.resultat
          : resultat as ArticleImportResult?,
      errorMessage: errorMessage == _sentinel
          ? this.errorMessage
          : errorMessage as String?,
    );
  }
}

const _sentinel = Object();

class ArticleImportNotifier extends Notifier<ArticleImportState> {
  @override
  ArticleImportState build() => const ArticleImportState();

  ArticleImportService get _service =>
      ArticleImportService(ref.read(articleRepositoryProvider));

  Future<void> chargerFichier(String filePath) async {
    state = state.copyWith(
      isLoading: true,
      errorMessage: null,
      resultat: null,
      parsedRows: [],
      codesDoublons: {},
      strategieParArticle: {},
    );

    try {
      final content = await ArticleImportService.lireFichier(filePath);
      final rows = ArticleImportService.parseContent(content);

      if (rows.isEmpty) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: 'Aucun article valide trouvé dans le fichier.\n'
              'Vérifiez que les colonnes sont séparées par des tabulations ou des points-virgules.',
        );
        return;
      }

      final hasStockColumn = rows.any((r) => r.stockInitial != null);
      final doublons = await _service.trouverDoublons(rows);

      state = state.copyWith(
        isLoading: false,
        parsedRows: rows,
        hasStockColumn: hasStockColumn,
        codesDoublons: doublons,
        strategieParArticle: {},
        importerAvecStock: false,
        selectedStoreId: null,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Erreur lors de la lecture du fichier : ${e.toString()}',
      );
    }
  }

  void setDoublonStrategie(DoublonStrategie s) =>
      state = state.copyWith(doublonStrategie: s);

  void setImporterAvecStock(bool v) =>
      state = state.copyWith(importerAvecStock: v);

  void setSelectedStore(int? id) =>
      state = state.copyWith(selectedStoreId: id);

  void setStrategieParArticle(String code, DoublonStrategie s) {
    final map =
        Map<String, DoublonStrategie>.from(state.strategieParArticle);
    map[code] = s;
    state = state.copyWith(strategieParArticle: map);
  }

  Future<void> lancerImport() async {
    if (state.parsedRows.isEmpty) return;

    state = state.copyWith(
      isImporting: true,
      importProgress: 0.0,
      resultat: null,
      errorMessage: null,
    );

    try {
      final result = await _service.importerArticles(
        rows: state.parsedRows,
        doublonStrategie: state.doublonStrategie,
        importerStock: state.importerAvecStock,
        storeId: state.selectedStoreId,
        strategieParArticle: state.doublonStrategie ==
                DoublonStrategie.demanderChaque
            ? state.strategieParArticle
            : null,
        onProgress: (done, total) {
          state = state.copyWith(
            importProgress: total > 0 ? done / total : 0.0,
          );
        },
      );

      state = state.copyWith(
        isImporting: false,
        importProgress: 1.0,
        resultat: result,
      );
    } catch (e) {
      state = state.copyWith(
        isImporting: false,
        errorMessage: "Erreur lors de l'import : ${e.toString()}",
      );
    }
  }

  void reinitialiser() => state = const ArticleImportState();
}

final articleImportProvider =
    NotifierProvider<ArticleImportNotifier, ArticleImportState>(
  ArticleImportNotifier.new,
);
