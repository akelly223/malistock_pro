import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:malistock_pro/core/services/pdf_document_service.dart';
import 'package:malistock_pro/domain/entities/app_settings.dart';
import 'package:malistock_pro/domain/entities/printable_document.dart';

class _FakePathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  final String tempPath;
  _FakePathProvider(this.tempPath);

  @override
  Future<String?> getApplicationDocumentsPath() async => tempPath;
}

/// Régression : un document avec beaucoup de lignes (ex: une proforma
/// de 17 articles) débordait de la page PDF unique et voyait son
/// tableau/total/pied de page silencieusement omis, sans erreur —
/// contrairement à Flutter, package:pdf n'affiche aucun avertissement
/// d'overflow, il tronque juste le contenu qui ne tient pas. Ce test
/// vérifie que la génération ne lève pas d'exception avec un nombre de
/// lignes qui dépasse une page A4 (voir pw.MultiPage dans
/// PdfDocumentService._buildPdfBytes).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('génère un PDF valide pour un document de 20 lignes (dépasse une page A4)',
      () async {
    final tempDir =
        await Directory.systemTemp.createTemp('pdf_pagination_test');
    addTearDown(() => tempDir.delete(recursive: true));
    PathProviderPlatform.instance = _FakePathProvider(tempDir.path);

    final lignes = List.generate(
      20,
      (i) => PrintableDocumentLine(
        designation: 'Article ${i + 1}',
        quantite: 1,
        prixUnitaire: 10000,
        totalLigne: 10000,
        totalHt: 10000,
        totalTtc: 10000,
      ),
    );

    final document = PrintableDocument(
      typeDocument: 'PROFORMA',
      numero: 'PRO-TEST-0001',
      dateCreation: DateTime(2026, 8, 16),
      tiersNom: 'Client comptoir',
      storeNom: 'Dépôt principal',
      lignes: lignes,
      sousTotal: 200000,
      remise: 0,
      totalFinal: 200000,
      montantPaye: 0,
      statutPaiement: 'non_paye',
    );

    final path = await PdfDocumentService.generateAndSave(
      document: document,
      settings: AppSettingsEntity.defaut,
    );
    final file = File(path);
    expect(file.existsSync(), isTrue);
    // Un PDF à une seule page tenant tout le contenu ferait quelques
    // ko ; avec pagination sur 2 pages et 20 lignes de tableau, on
    // s'attend à un fichier nettement plus consistant si tout le
    // contenu est bien rendu (regression guard grossier mais efficace :
    // avant le correctif, le fichier ne contenait que l'entête).
    expect(file.lengthSync(), greaterThan(2000));
  });
}
