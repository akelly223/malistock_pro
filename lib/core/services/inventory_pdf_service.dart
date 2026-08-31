import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show compute;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import '../../domain/entities/inventory.dart';
import '../../domain/entities/app_settings.dart';
import '../constants/app_identity.dart';
import '../utils/date_formatter.dart';

/// Génère le rapport PDF d'un inventaire (écarts, quantités, total
/// des corrections, date, magasin) — fichier indépendant du
/// générateur de factures/achats, pour ne rien changer à son
/// comportement existant.
class InventoryPdfService {
  InventoryPdfService._();

  static const PdfColor _couleurPrimaire = PdfColor.fromInt(0xFF1E6F46);
  static const PdfColor _couleurTexteSecondaire = PdfColor.fromInt(0xFF6B7280);
  static const PdfColor _couleurBordure = PdfColor.fromInt(0xFFBFC5CC);
  static const PdfColor _couleurFondTotal = PdfColor.fromInt(0xFFE7F4ED);
  static const PdfColor _couleurEcartPositif = PdfColor.fromInt(0xFF1E6F46);
  static const PdfColor _couleurEcartNegatif = PdfColor.fromInt(0xFFC23B33);

  static Future<String> generateAndSave({
    required InventoryEntity inventaire,
    required List<InventoryLineEntity> lignes,
    required AppSettingsEntity settings,
  }) async {
    final bytes = await compute(_buildPdfBytesSync,
        (inventaire: inventaire, lignes: lignes, settings: settings));

    final dir = await getApplicationDocumentsDirectory();
    final outputDir =
        Directory(p.join(dir.path, 'MaliStockPro', 'pdf'));
    if (!await outputDir.exists()) {
      await outputDir.create(recursive: true);
    }
    final filePath = p.join(outputDir.path, '${inventaire.numero}.pdf');
    await File(filePath).writeAsBytes(bytes);
    return filePath;
  }

  static Future<void> print({
    required InventoryEntity inventaire,
    required List<InventoryLineEntity> lignes,
    required AppSettingsEntity settings,
  }) async {
    final bytes = await compute(_buildPdfBytesSync,
        (inventaire: inventaire, lignes: lignes, settings: settings));
    await Printing.layoutPdf(
      onLayout: (_) async => bytes,
      name: inventaire.numero,
    );
  }

  /// Construction des octets du PDF — déportée sur un isolate séparé
  /// via [compute] : sur un inventaire avec beaucoup d'écarts (gros
  /// catalogue), composer le tableau pdf et l'encoder prend un temps
  /// non négligeable et gèlerait l'UI sur l'isolate principal.
  static Future<Uint8List> _buildPdfBytesSync(
      ({
        InventoryEntity inventaire,
        List<InventoryLineEntity> lignes,
        AppSettingsEntity settings,
      }) args) {
    return _buildPdfBytes(
        inventaire: args.inventaire,
        lignes: args.lignes,
        settings: args.settings);
  }

  static Future<Uint8List> _buildPdfBytes({
    required InventoryEntity inventaire,
    required List<InventoryLineEntity> lignes,
    required AppSettingsEntity settings,
  }) async {
    final pdf = pw.Document();

    pw.MemoryImage? logo;
    if (settings.logoPath != null) {
      final logoFile = File(settings.logoPath!);
      if (await logoFile.exists()) {
        logo = pw.MemoryImage(await logoFile.readAsBytes());
      }
    }

    final lignesEnEcart = lignes.where((l) => l.aUnEcart || l.introuvable).toList();
    final totalCorrections =
        lignesEnEcart.fold<double>(0, (s, l) => s + (l.ecart ?? 0));

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        header: (context) =>
            context.pageNumber == 1 ? pw.SizedBox() : pw.SizedBox(height: 8),
        build: (context) => [
          _buildEntete(settings, logo),
          pw.SizedBox(height: 14),
          pw.Divider(color: _couleurBordure, thickness: 1),
          pw.SizedBox(height: 14),
          _buildInfosInventaire(inventaire),
          pw.SizedBox(height: 18),
          _buildResume(inventaire),
          pw.SizedBox(height: 18),
          pw.Text('Détail des écarts (${lignesEnEcart.length})',
              style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          lignesEnEcart.isEmpty
              ? pw.Text('Aucun écart constaté.',
                  style: const pw.TextStyle(fontSize: 10))
              : _buildTableauEcarts(lignesEnEcart),
          pw.SizedBox(height: 16),
          _buildTotalCorrections(totalCorrections, lignesEnEcart.length),
          pw.SizedBox(height: 20),
          _mentionEditeur(),
        ],
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildEntete(AppSettingsEntity settings, pw.MemoryImage? logo) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        if (logo != null) ...[
          pw.Container(
              width: 56, height: 56, child: pw.Image(logo, fit: pw.BoxFit.contain)),
          pw.SizedBox(width: 14),
        ],
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(settings.nomEntreprise.toUpperCase(),
                  style: pw.TextStyle(
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                      color: _couleurPrimaire)),
              pw.SizedBox(height: 2),
              pw.Text('Rapport d\'inventaire',
                  style: pw.TextStyle(
                      fontSize: 10, color: _couleurTexteSecondaire)),
            ],
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildInfosInventaire(InventoryEntity inventaire) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('Magasin : ${inventaire.storeNom}',
                style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
            if (inventaire.categorieNom != null)
              pw.Text('Catégorie : ${inventaire.categorieNom}',
                  style: const pw.TextStyle(fontSize: 10)),
            pw.Text('Créé par : ${inventaire.createdByNom ?? '—'}',
                style: const pw.TextStyle(fontSize: 10)),
            if (inventaire.validatedByNom != null)
              pw.Text('Validé par : ${inventaire.validatedByNom}',
                  style: const pw.TextStyle(fontSize: 10)),
          ],
        ),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Text('N° ${inventaire.numero}',
                style: pw.TextStyle(
                    fontSize: 11,
                    fontWeight: pw.FontWeight.bold,
                    color: _couleurPrimaire)),
            pw.Text(
                'Créé le : ${DateFormatter.formatDateTime(inventaire.dateCreation)}',
                style: const pw.TextStyle(fontSize: 10)),
            if (inventaire.dateValidation != null)
              pw.Text(
                  'Validé le : ${DateFormatter.formatDateTime(inventaire.dateValidation!)}',
                  style: const pw.TextStyle(fontSize: 10)),
          ],
        ),
      ],
    );
  }

  static pw.Widget _carteStat(String label, int valeur, PdfColor couleurTexte,
      PdfColor couleurFond) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(
          color: couleurFond,
          borderRadius: pw.BorderRadius.circular(8),
        ),
        child: pw.Column(
          children: [
            pw.Text('$valeur',
                style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                    color: couleurTexte)),
            pw.SizedBox(height: 2),
            pw.Text(label,
                style:
                    pw.TextStyle(fontSize: 8.5, color: _couleurTexteSecondaire),
                textAlign: pw.TextAlign.center),
          ],
        ),
      ),
    );
  }

  static pw.Widget _buildResume(InventoryEntity inventaire) {
    return pw.Row(
      children: [
        _carteStat(
            'Articles contrôlés',
            inventaire.nbSansEcart + inventaire.nbAvecEcart,
            _couleurPrimaire,
            _couleurFondTotal),
        pw.SizedBox(width: 8),
        _carteStat('Sans écart', inventaire.nbSansEcart, _couleurPrimaire,
            _couleurFondTotal),
        pw.SizedBox(width: 8),
        _carteStat('Avec écart', inventaire.nbAvecEcart, _couleurEcartNegatif,
            const PdfColor.fromInt(0xFFFBE9E7)),
        pw.SizedBox(width: 8),
        _carteStat('Introuvables', inventaire.nbIntrouvables,
            _couleurTexteSecondaire, const PdfColor.fromInt(0xFFF3F4F6)),
      ],
    );
  }

  static pw.Widget _buildTableauEcarts(List<InventoryLineEntity> lignes) {
    return pw.Table(
      border: pw.TableBorder(
        top: pw.BorderSide(color: _couleurBordure, width: 1),
        bottom: pw.BorderSide(color: _couleurBordure, width: 1),
        horizontalInside: pw.BorderSide(color: _couleurBordure, width: 0.5),
      ),
      columnWidths: const {
        0: pw.FlexColumnWidth(1.2),
        1: pw.FlexColumnWidth(3.0),
        2: pw.FlexColumnWidth(1.2),
        3: pw.FlexColumnWidth(1.2),
        4: pw.FlexColumnWidth(1.0),
        5: pw.FlexColumnWidth(2.4),
      },
      children: [
        pw.TableRow(
          decoration: pw.BoxDecoration(color: _couleurFondTotal),
          children: [
            _cellHeader('Code'),
            _cellHeader('Désignation'),
            _cellHeader('Théorique', align: pw.TextAlign.right),
            _cellHeader('Physique', align: pw.TextAlign.right),
            _cellHeader('Écart', align: pw.TextAlign.right),
            _cellHeader('Observation'),
          ],
        ),
        ...lignes.map((l) {
          final ecart = l.ecart;
          final couleurEcart = l.introuvable
              ? _couleurTexteSecondaire
              : (ecart != null && ecart < 0 ? _couleurEcartNegatif : _couleurEcartPositif);
          return pw.TableRow(children: [
            _cell(l.articleCode),
            _cell(l.introuvable ? '${l.articleNom} (introuvable)' : l.articleNom),
            _cell(l.stockTheorique.toStringAsFixed(0), align: pw.TextAlign.right),
            _cell(l.stockPhysique?.toStringAsFixed(0) ?? '—', align: pw.TextAlign.right),
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 8),
              child: pw.Text(
                ecart == null ? '—' : '${ecart > 0 ? '+' : ''}${ecart.toStringAsFixed(0)}',
                textAlign: pw.TextAlign.right,
                style: pw.TextStyle(fontSize: 10, color: couleurEcart, fontWeight: pw.FontWeight.bold),
              ),
            ),
            _cell(l.observation ?? ''),
          ]);
        }),
      ],
    );
  }

  static pw.Widget _cellHeader(String text, {pw.TextAlign? align}) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        child: pw.Text(text,
            textAlign: align,
            style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold)),
      );

  static pw.Widget _cell(String text, {pw.TextAlign? align}) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        child: pw.Text(text, textAlign: align, style: const pw.TextStyle(fontSize: 9.5)),
      );

  static pw.Widget _buildTotalCorrections(double totalCorrections, int nbLignes) {
    return pw.Align(
      alignment: pw.Alignment.centerRight,
      child: pw.Container(
        padding: const pw.EdgeInsets.all(12),
        decoration: pw.BoxDecoration(
          color: _couleurFondTotal,
          borderRadius: pw.BorderRadius.circular(8),
        ),
        child: pw.Row(
          mainAxisSize: pw.MainAxisSize.min,
          children: [
            pw.Text('TOTAL DES CORRECTIONS : ',
                style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
            pw.Text(
                '$nbLignes ligne${nbLignes > 1 ? 's' : ''} '
                '(${totalCorrections > 0 ? '+' : ''}${totalCorrections.toStringAsFixed(0)} unités)',
                style: pw.TextStyle(
                    fontSize: 11, fontWeight: pw.FontWeight.bold, color: _couleurPrimaire)),
          ],
        ),
      ),
    );
  }

  static pw.Widget _mentionEditeur() {
    return pw.Center(
      child: pw.Text(
        AppIdentity.mentionPdf,
        textAlign: pw.TextAlign.center,
        style: pw.TextStyle(
            fontSize: 7,
            color: const PdfColor.fromInt(0xFFBFC5CC),
            fontStyle: pw.FontStyle.italic),
      ),
    );
  }
}
