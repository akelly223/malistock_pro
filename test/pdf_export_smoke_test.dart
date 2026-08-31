import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:malistock_pro/core/services/document_printable_mapper.dart';
import 'package:malistock_pro/core/services/pdf_document_service.dart';
import 'package:malistock_pro/domain/entities/app_settings.dart';
import 'package:malistock_pro/domain/entities/commercial_document.dart';
import 'package:malistock_pro/domain/entities/document_type.dart';

class _FakePathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  final String tempPath;
  _FakePathProvider(this.tempPath);

  @override
  Future<String?> getApplicationDocumentsPath() async => tempPath;
}

/// Vérifie que le PDF d'une vente V2 (avec TVA et remise ligne, comme
/// après validation d'une facture) se génère bien de bout en bout —
/// même flux "Export PDF" que celui câblé dans document_detail_screen.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('export PDF d\'une vente V2 avec TVA/remise génère un fichier valide',
      () async {
    final tempDir = await Directory.systemTemp.createTemp('pdf_smoke_test');
    addTearDown(() => tempDir.delete(recursive: true));
    PathProviderPlatform.instance = _FakePathProvider(tempDir.path);

    final doc = DocumentEntity(
      id: 1,
      numero: 'FAC-2026-0042',
      type: DocumentType.facture,
      statut: DocumentStatut.valide,
      clientId: 1,
      clientNom: 'Client Test',
      clientNif: '1234567X',
      storeId: 1,
      storeNom: 'Boutique principale',
      dateDocument: DateTime(2026, 7, 2),
      dateCreation: DateTime(2026, 7, 2),
      totalHt: 1900,
      totalTva: 342,
      totalTtc: 2242,
      remiseGlobalePct: 5,
      montantPaye: 2242,
      statutPaiement: 'paye',
      lignes: [
        DocumentLigneEntity(
          id: 1,
          documentId: 1,
          articleId: 1,
          articleCode: 'ART1',
          articleNom: 'Sac de riz 50kg',
          quantite: 2,
          prixUnitaireHt: 1000,
          tauxTva: 18,
          remiseLignePct: 5,
          totalHt: 1900,
          montantTva: 342,
          totalTtc: 2242,
          position: 0,
        ),
      ],
    );

    const settings = AppSettingsEntity(
      nomEntreprise: 'MaliStock Pro Test',
      nif: 'NIF-999',
      rccm: 'RCCM-999',
      adresse: 'Bamako',
      telephone: '76000000',
    );

    final path = await PdfDocumentService.generateAndSave(
      document: doc.toPrintableDocument(),
      settings: settings,
    );

    final file = File(path);
    expect(await file.exists(), isTrue);
    final bytes = await file.readAsBytes();
    expect(bytes.length, greaterThan(500));
    // En-tête standard d'un fichier PDF valide.
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
  });
}
