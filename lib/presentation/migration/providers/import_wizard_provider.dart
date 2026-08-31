import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers/repository_providers.dart';
import '../../../core/import/column_detector.dart';
import '../../../core/import/executors/article_executor.dart';
import '../../../core/import/executors/client_executor.dart';
import '../../../core/import/executors/stock_executor.dart';
import '../../../core/import/executors/supplier_executor.dart';
import '../../../core/import/file_parser.dart';
import '../../../core/import/import_config.dart';
import '../../../core/import/import_executor.dart';
import '../../../core/import/import_field.dart';
import '../../../core/import/import_result.dart';
import '../../../core/import/parsed_file.dart';

enum WizardStep { fileSelection, columnMapping, preview, summary, importing, result }

// ── State ──────────────────────────────────────────────────────────────────────

class ImportWizardState {
  final WizardStep step;
  final String? filePath;
  final ParsedFile? parsedFile;
  final Map<int, ImportField?> columnMappings;
  final List<Map<ImportField, String>> mappedRows;
  final Set<String> duplicateKeys;
  final DuplicateStrategy globalStrategy;
  final Map<String, DuplicateStrategy> strategyPerItem;
  final bool importerAvecStock;
  final int? selectedStoreId;
  final StockImportMode stockImportMode;
  final double progress;
  final ImportResult? result;
  final bool isLoading;
  final String? errorMessage;

  const ImportWizardState({
    this.step = WizardStep.fileSelection,
    this.filePath,
    this.parsedFile,
    this.columnMappings = const {},
    this.mappedRows = const [],
    this.duplicateKeys = const {},
    this.globalStrategy = DuplicateStrategy.ignorer,
    this.strategyPerItem = const {},
    this.importerAvecStock = false,
    this.selectedStoreId,
    this.stockImportMode = StockImportMode.ajouter,
    this.progress = 0.0,
    this.result,
    this.isLoading = false,
    this.errorMessage,
  });

  bool get hasFile => parsedFile != null;
  bool get hasDoublons => duplicateKeys.isNotEmpty;

  /// Retourne le mapping inversé field→index (premier mapping trouvé).
  Map<ImportField, int> get fieldToColumn {
    final m = <ImportField, int>{};
    for (final entry in columnMappings.entries) {
      if (entry.value != null && !m.containsKey(entry.value)) {
        m[entry.value!] = entry.key;
      }
    }
    return m;
  }

  ImportWizardState copyWith({
    WizardStep? step,
    String? filePath,
    ParsedFile? parsedFile,
    Map<int, ImportField?>? columnMappings,
    List<Map<ImportField, String>>? mappedRows,
    Set<String>? duplicateKeys,
    DuplicateStrategy? globalStrategy,
    Map<String, DuplicateStrategy>? strategyPerItem,
    bool? importerAvecStock,
    Object? selectedStoreId = _sentinel,
    StockImportMode? stockImportMode,
    double? progress,
    Object? result = _sentinel,
    bool? isLoading,
    Object? errorMessage = _sentinel,
  }) {
    return ImportWizardState(
      step: step ?? this.step,
      filePath: filePath ?? this.filePath,
      parsedFile: parsedFile ?? this.parsedFile,
      columnMappings: columnMappings ?? this.columnMappings,
      mappedRows: mappedRows ?? this.mappedRows,
      duplicateKeys: duplicateKeys ?? this.duplicateKeys,
      globalStrategy: globalStrategy ?? this.globalStrategy,
      strategyPerItem: strategyPerItem ?? this.strategyPerItem,
      importerAvecStock: importerAvecStock ?? this.importerAvecStock,
      selectedStoreId: selectedStoreId == _sentinel
          ? this.selectedStoreId
          : selectedStoreId as int?,
      stockImportMode: stockImportMode ?? this.stockImportMode,
      progress: progress ?? this.progress,
      result: result == _sentinel ? this.result : result as ImportResult?,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage == _sentinel
          ? this.errorMessage
          : errorMessage as String?,
    );
  }
}

const _sentinel = Object();

// ── Notifier ───────────────────────────────────────────────────────────────────

class ImportWizardNotifier
    extends FamilyNotifier<ImportWizardState, ImportEntityType> {
  @override
  ImportWizardState build(ImportEntityType arg) => const ImportWizardState();

  ImportConfig get _config {
    switch (arg) {
      case ImportEntityType.articles:
        return ImportConfig.articles;
      case ImportEntityType.clients:
        return ImportConfig.clients;
      case ImportEntityType.fournisseurs:
        return ImportConfig.fournisseurs;
      case ImportEntityType.stock:
        return ImportConfig.stock;
    }
  }

  ImportExecutor _buildExecutor({bool importerAvecStock = false}) {
    switch (arg) {
      case ImportEntityType.articles:
        return ArticleImportExecutor(
          ref.read(articleRepositoryProvider),
          importerAvecStock: importerAvecStock,
        );
      case ImportEntityType.clients:
        return ClientImportExecutor(ref.read(clientRepositoryProvider));
      case ImportEntityType.fournisseurs:
        return SupplierImportExecutor(ref.read(supplierRepositoryProvider));
      case ImportEntityType.stock:
        return StockImportExecutor(
          ref.read(articleRepositoryProvider),
          mode: state.stockImportMode,
        );
    }
  }

  // ── Étape 1 : charger le fichier ────────────────────────────────────────────

  Future<void> chargerFichier(String filePath) async {
    state = state.copyWith(
      isLoading: true,
      errorMessage: null,
      step: WizardStep.fileSelection,
    );

    try {
      final parsed = await FileParser.parse(filePath);

      if (parsed.headers.isEmpty) {
        state = state.copyWith(
          isLoading: false,
          errorMessage:
              'Le fichier semble vide ou son format n\'est pas reconnu.',
        );
        return;
      }
      if (parsed.rows.isEmpty) {
        state = state.copyWith(
          isLoading: false,
          errorMessage:
              'Aucune donnée trouvée dans le fichier (uniquement un en-tête ?)',
        );
        return;
      }

      final autoMappings = ColumnDetector.detect(
        parsed.headers,
        _config.availableFields,
      );

      state = state.copyWith(
        isLoading: false,
        filePath: filePath,
        parsedFile: parsed,
        columnMappings: autoMappings,
        mappedRows: [],
        duplicateKeys: {},
        step: WizardStep.columnMapping,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Erreur de lecture : $e',
      );
    }
  }

  // ── Étape 2 : mapping des colonnes ──────────────────────────────────────────

  void setColumnMapping(int colIndex, ImportField? field) {
    final updated = Map<int, ImportField?>.from(state.columnMappings);
    // Si ce champ était déjà assigné à une autre colonne, on l'enlève
    if (field != null) {
      for (final entry in updated.entries.toList()) {
        if (entry.value == field && entry.key != colIndex) {
          updated[entry.key] = null;
        }
      }
    }
    updated[colIndex] = field;
    state = state.copyWith(columnMappings: updated);
  }

  bool get mappingValid {
    final mapped =
        state.columnMappings.values.whereType<ImportField>().toSet();
    return _config.requiredFields.every(mapped.contains);
  }

  /// Applique le mapping et passe à l'aperçu.
  Future<void> validerMapping() async {
    state = state.copyWith(isLoading: true);

    final rows = _applyMapping(state.parsedFile!.rows, state.columnMappings);
    final executor = _buildExecutor();
    final doublons = await executor.findDuplicates(rows);

    state = state.copyWith(
      isLoading: false,
      mappedRows: rows,
      duplicateKeys: doublons,
      step: WizardStep.preview,
    );
  }

  List<Map<ImportField, String>> _applyMapping(
    List<List<String>> rawRows,
    Map<int, ImportField?> mappings,
  ) {
    return rawRows.map((row) {
      final mapped = <ImportField, String>{};
      for (final entry in mappings.entries) {
        if (entry.value == null) continue;
        final val = entry.key < row.length ? row[entry.key] : '';
        mapped[entry.value!] = val;
      }
      return mapped;
    }).toList();
  }

  // ── Étape 3 : prévisualisation → étape 4 ────────────────────────────────────

  void allerAuResume() => state = state.copyWith(step: WizardStep.summary);

  // ── Étape 4 : résumé ────────────────────────────────────────────────────────

  void setStockImportMode(StockImportMode m) =>
      state = state.copyWith(stockImportMode: m);

  void setGlobalStrategy(DuplicateStrategy s) =>
      state = state.copyWith(globalStrategy: s);

  void setStrategyPerItem(String key, DuplicateStrategy s) {
    final m = Map<String, DuplicateStrategy>.from(state.strategyPerItem);
    m[key] = s;
    state = state.copyWith(strategyPerItem: m);
  }

  void setImporterAvecStock(bool v) =>
      state = state.copyWith(importerAvecStock: v);

  void setSelectedStore(int? id) =>
      state = state.copyWith(selectedStoreId: id);

  // ── Étape 5 : import ────────────────────────────────────────────────────────

  Future<void> lancerImport() async {
    if (state.mappedRows.isEmpty) return;

    state = state.copyWith(
      step: WizardStep.importing,
      progress: 0.0,
      result: null,
      errorMessage: null,
    );

    try {
      final executor =
          _buildExecutor(importerAvecStock: state.importerAvecStock);

      final result = await executor.execute(
        rows: state.mappedRows,
        globalStrategy: state.globalStrategy,
        strategyPerItem: state.globalStrategy == DuplicateStrategy.demanderChaque
            ? state.strategyPerItem
            : null,
        targetStoreId: state.selectedStoreId,
        onProgress: (done, total) {
          state = state.copyWith(
            progress: total > 0 ? done / total : 0.0,
          );
        },
      );

      state = state.copyWith(
        step: WizardStep.result,
        progress: 1.0,
        result: result,
      );
    } catch (e) {
      state = state.copyWith(
        step: WizardStep.summary,
        errorMessage: "Erreur lors de l'import : $e",
      );
    }
  }

  // ── Navigation ───────────────────────────────────────────────────────────────

  void retourEtape(WizardStep target) => state = state.copyWith(step: target);

  void reinitialiser() => state = const ImportWizardState();
}

final importWizardProvider = NotifierProviderFamily<ImportWizardNotifier,
    ImportWizardState, ImportEntityType>(ImportWizardNotifier.new);
