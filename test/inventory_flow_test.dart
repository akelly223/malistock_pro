import 'dart:io';
import 'package:drift/drift.dart' hide isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'package:malistock_pro/data/local/database.dart';
import 'package:malistock_pro/data/repositories/inventory_repository_impl.dart';
import 'package:malistock_pro/core/services/inventory_export_service.dart';
import 'package:malistock_pro/core/services/inventory_pdf_service.dart';
import 'package:malistock_pro/domain/entities/app_settings.dart';
import 'package:malistock_pro/domain/entities/inventory.dart';

class _FakePathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  final String tempPath;
  _FakePathProvider(this.tempPath);

  @override
  Future<String?> getApplicationDocumentsPath() async => tempPath;
}

/// Vérifie le flux complet du module Inventaire sur une vraie base
/// SQLite en mémoire : création (bug corrigé du dialogue bloqué sur
/// le chargement des magasins/catégories), export xlsx/csv et PDF
/// (déportés sur isolate via compute), correction manuelle, import de
/// comptage, puis validation avec répercussion sur le stock réel.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
      'création d\'un inventaire + export xlsx/csv/pdf + validation, de bout en bout',
      () async {
    final tempDir =
        await Directory.systemTemp.createTemp('inventory_flow_test');
    addTearDown(() => tempDir.delete(recursive: true));
    PathProviderPlatform.instance = _FakePathProvider(tempDir.path);

    final db = AppDatabase.withExecutor(NativeDatabase.memory());
    addTearDown(db.close);

    final storeId = await db.into(db.stores).insert(
          StoresCompanion.insert(nom: 'Boutique Test'),
        );
    final userId = await db.into(db.users).insert(
          UsersCompanion.insert(
            nom: 'Admin Test',
            login: 'admintest',
            motDePasseHash: 'x',
            role: 'admin',
          ),
        );
    final categorieId = await db.into(db.categories).insert(
          CategoriesCompanion.insert(nom: 'Alimentaire'),
        );

    final articleRiz = await db.into(db.articles).insert(
          ArticlesCompanion.insert(
            code: 'ART1',
            nom: 'Sac de riz 50kg',
            prixVente: 25000,
            categorieId: Value(categorieId),
          ),
        );
    final articleHuile = await db.into(db.articles).insert(
          ArticlesCompanion.insert(code: 'ART2', nom: 'Huile 5L', prixVente: 6000),
        );

    await db.articlesDao
        .adjustStock(articleId: articleRiz, storeId: storeId, delta: 40);
    await db.articlesDao
        .adjustStock(articleId: articleHuile, storeId: storeId, delta: 15);

    final repo = InventoryRepositoryImpl(db);

    // ── Création (le bug corrigé bloquait le dialogue avant même
    // d'arriver ici : storeId ne se remplissait jamais) ──────────────
    final inventoryId =
        await repo.creerInventaire(storeId: storeId, userId: userId);
    expect(inventoryId, greaterThan(0));

    var inv = await repo.getInventoryById(inventoryId);
    expect(inv, isNotNull);
    expect(inv!.nbArticles, 2);
    expect(inv.statut, 'brouillon');

    var lignes = await repo.getLines(inventoryId);
    expect(lignes.length, 2);
    final ligneRiz = lignes.firstWhere((l) => l.articleCode == 'ART1');
    expect(ligneRiz.stockTheorique, 40);
    expect(ligneRiz.categorieNom, 'Alimentaire');

    // ── Export xlsx/csv (déportés sur isolate via compute) ──────────
    final xlsxBytes = await InventoryExportService.xlsxBytes(inv, lignes);
    expect(xlsxBytes.length, greaterThan(100));
    // Signature ZIP/XLSX "PK".
    expect(xlsxBytes[0], 0x50);
    expect(xlsxBytes[1], 0x4B);

    final csv = await InventoryExportService.csvContent(inv, lignes);
    expect(csv, contains('Code article'));
    expect(csv, contains('ART1'));
    expect(csv, contains('ART2'));

    // ── Correction manuelle d'une ligne ──────────────────────────────
    await repo.corrigerLigne(
        lineId: ligneRiz.id, stockPhysique: 38, observation: 'Casse');
    lignes = await repo.getLines(inventoryId);
    final ligneRizMaj = lignes.firstWhere((l) => l.articleCode == 'ART1');
    expect(ligneRizMaj.ecart, -2);

    // ── Import du comptage pour l'autre article ─────────────────────
    final resume = await repo.importerComptage(inventoryId: inventoryId, rows: [
      const InventoryCountRow(code: 'ART2', stockPhysique: 15),
    ]);
    expect(resume.lignesMisesAJour, 1);
    expect(resume.codesIntrouvables, isEmpty);

    inv = (await repo.getInventoryById(inventoryId))!;
    lignes = await repo.getLines(inventoryId);
    expect(inv.nbSansEcart, 1); // ART2 sans écart
    expect(inv.nbAvecEcart, 1); // ART1 en écart

    // ── PDF (déporté sur isolate via compute) ────────────────────────
    const settings = AppSettingsEntity(nomEntreprise: 'MaliStock Pro Test');
    final pdfPath = await InventoryPdfService.generateAndSave(
        inventaire: inv, lignes: lignes, settings: settings);
    final pdfFile = File(pdfPath);
    expect(await pdfFile.exists(), isTrue);
    final pdfBytes = await pdfFile.readAsBytes();
    expect(String.fromCharCodes(pdfBytes.take(5)), '%PDF-');

    // ── Validation : répercussion sur le stock réel + mouvement ─────
    await repo.validerInventaire(inventoryId: inventoryId, userId: userId);
    final invValide = await repo.getInventoryById(inventoryId);
    expect(invValide!.statut, 'valide');

    final stockRizApres =
        await db.articlesDao.getStockForArticleInStore(articleRiz, storeId);
    expect(stockRizApres, 38); // 40 - 2 (écart)
    final stockHuileApres = await db.articlesDao
        .getStockForArticleInStore(articleHuile, storeId);
    expect(stockHuileApres, 15); // inchangé, pas d'écart
  });
}
