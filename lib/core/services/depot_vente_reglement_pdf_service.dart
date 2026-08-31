import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show compute;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../domain/entities/app_settings.dart';
import '../../domain/entities/depot_vente_reglement.dart';
import '../constants/app_identity.dart';
import '../utils/currency_formatter.dart';
import '../utils/date_formatter.dart';

/// Génère le reçu PDF d'un règlement dépôt-vente (cahier des charges
/// §11) — calqué sur `StockEntryReceiptPdfService` : même usage de
/// `Printing.layoutPdf` (ouvre la boîte de dialogue d'impression Windows,
/// qui permet nativement « Enregistrer en PDF »), même bloc logo/cachet
/// via [AppSettingsEntity], aucune dépendance supplémentaire.
class DepotVenteReglementPdfService {
  DepotVenteReglementPdfService._();

  static const PdfColor _couleurPrimaire = PdfColor.fromInt(0xFF1E6F46);
  static const PdfColor _couleurTexteSecondaire = PdfColor.fromInt(0xFF6B7280);
  static const PdfColor _couleurBordure = PdfColor.fromInt(0xFFBFC5CC);
  static const PdfColor _couleurFond = PdfColor.fromInt(0xFFE7F4ED);

  static Future<void> print({
    required DepotVenteReglementEntity reglement,
    required AppSettingsEntity settings,
  }) async {
    final bytes = await compute(
        _buildPdfBytesSync, (reglement: reglement, settings: settings));
    await Printing.layoutPdf(
      onLayout: (_) async => bytes,
      name: 'Reçu règlement dépôt-vente',
    );
  }

  static Future<Uint8List> _buildPdfBytesSync(
      ({DepotVenteReglementEntity reglement, AppSettingsEntity settings})
          args) {
    return _buildPdfBytes(reglement: args.reglement, settings: args.settings);
  }

  static Future<Uint8List> _buildPdfBytes({
    required DepotVenteReglementEntity reglement,
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
    pw.MemoryImage? cachet;
    if (settings.cachetPath != null) {
      final cachetFile = File(settings.cachetPath!);
      if (await cachetFile.exists()) {
        cachet = pw.MemoryImage(await cachetFile.readAsBytes());
      }
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (context) => [
          _buildEntete(settings, logo),
          pw.SizedBox(height: 14),
          pw.Divider(color: _couleurBordure, thickness: 1),
          pw.SizedBox(height: 14),
          _buildInfos(reglement),
          pw.SizedBox(height: 18),
          pw.Text('Livres concernés (${reglement.lignes.length})',
              style:
                  pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          _buildTableau(reglement.lignes),
          pw.SizedBox(height: 16),
          _buildTotaux(reglement, settings),
          if (reglement.note != null && reglement.note!.trim().isNotEmpty) ...[
            pw.SizedBox(height: 14),
            pw.Text('Commentaire : ${reglement.note}',
                style: pw.TextStyle(
                    fontSize: 9.5, color: _couleurTexteSecondaire)),
          ],
          pw.SizedBox(height: 40),
          _buildSignatures(reglement.supplierNom, cachet),
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
              width: 56,
              height: 56,
              child: pw.Image(logo, fit: pw.BoxFit.contain)),
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
              if (settings.adresse != null)
                pw.Text(settings.adresse!,
                    style:
                        pw.TextStyle(fontSize: 9, color: _couleurTexteSecondaire)),
              if (settings.telephone != null)
                pw.Text('Tél : ${settings.telephone}',
                    style:
                        pw.TextStyle(fontSize: 9, color: _couleurTexteSecondaire)),
            ],
          ),
        ),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Text('REÇU DE RÈGLEMENT',
                style: pw.TextStyle(
                    fontSize: 13,
                    fontWeight: pw.FontWeight.bold,
                    color: _couleurPrimaire)),
            pw.Text('Dépôt-vente',
                style: pw.TextStyle(fontSize: 9, color: _couleurTexteSecondaire)),
          ],
        ),
      ],
    );
  }

  static pw.Widget _buildInfos(DepotVenteReglementEntity reglement) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('Auteur / Fournisseur : ${reglement.supplierNom}',
                style:
                    pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
            pw.Text('Statut : ${reglement.statut.libelle}',
                style: const pw.TextStyle(fontSize: 10)),
          ],
        ),
        pw.Text(
            'Date : ${DateFormatter.formatDateTime(reglement.dateHeure)}',
            style: const pw.TextStyle(fontSize: 10)),
      ],
    );
  }

  static pw.Widget _buildTableau(List<DepotVenteReglementLigneEntity> lignes) {
    return pw.Table(
      border: pw.TableBorder(
        top: pw.BorderSide(color: _couleurBordure, width: 1),
        bottom: pw.BorderSide(color: _couleurBordure, width: 1),
        horizontalInside: pw.BorderSide(color: _couleurBordure, width: 0.5),
      ),
      columnWidths: const {
        0: pw.FlexColumnWidth(4.0),
        1: pw.FlexColumnWidth(1.2),
        2: pw.FlexColumnWidth(1.8),
        3: pw.FlexColumnWidth(1.8),
      },
      children: [
        pw.TableRow(
          decoration: pw.BoxDecoration(color: _couleurFond),
          children: [
            _cellHeader('Livre'),
            _cellHeader('Qté', align: pw.TextAlign.right),
            _cellHeader('Vente totale', align: pw.TextAlign.right),
            _cellHeader('Part auteur', align: pw.TextAlign.right),
          ],
        ),
        ...lignes.map((l) => pw.TableRow(children: [
              _cell(l.articleNom),
              _cell(l.quantite.toStringAsFixed(0), align: pw.TextAlign.right),
              _cell(CurrencyFormatter.format(l.montantVente),
                  align: pw.TextAlign.right),
              _cell(CurrencyFormatter.format(l.montantAuteur),
                  align: pw.TextAlign.right),
            ])),
      ],
    );
  }

  static pw.Widget _cellHeader(String text, {pw.TextAlign? align}) =>
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        child: pw.Text(text,
            textAlign: align,
            style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold)),
      );

  static pw.Widget _cell(String text, {pw.TextAlign? align}) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        child:
            pw.Text(text, textAlign: align, style: const pw.TextStyle(fontSize: 9.5)),
      );

  static pw.Widget _buildTotaux(
      DepotVenteReglementEntity reglement, AppSettingsEntity settings) {
    pw.Widget ligne(String libelle, String valeur, {bool accent = false}) =>
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 3),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(libelle,
                  style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight:
                          accent ? pw.FontWeight.bold : pw.FontWeight.normal)),
              pw.Text(valeur,
                  style: pw.TextStyle(
                      fontSize: accent ? 12 : 10,
                      fontWeight: pw.FontWeight.bold,
                      color: accent ? _couleurPrimaire : PdfColors.black)),
            ],
          ),
        );

    return pw.Align(
      alignment: pw.Alignment.centerRight,
      child: pw.Container(
        width: 260,
        padding: const pw.EdgeInsets.all(12),
        decoration: pw.BoxDecoration(
            color: _couleurFond, borderRadius: pw.BorderRadius.circular(8)),
        child: pw.Column(
          children: [
            ligne('Total ventes', CurrencyFormatter.format(reglement.venteTotale)),
            ligne('Commission ${settings.nomEntreprise}',
                CurrencyFormatter.format(reglement.commission)),
            pw.Divider(color: _couleurBordure, height: 12),
            ligne('Montant dû', CurrencyFormatter.format(reglement.montantDu)),
            ligne('Montant payé', CurrencyFormatter.format(reglement.montantPaye),
                accent: true),
            if (reglement.resteAPayer > 0.01)
              ligne('Reste à payer', CurrencyFormatter.format(reglement.resteAPayer)),
          ],
        ),
      ),
    );
  }

  static pw.Widget _buildSignatures(String supplierNom, pw.MemoryImage? cachet) {
    final ligneVide = pw.Container(
      width: 160,
      decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: _couleurBordure)),
      ),
    );
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('Reçu par ($supplierNom) :',
                style: const pw.TextStyle(fontSize: 10)),
            pw.SizedBox(height: 30),
            ligneVide,
          ],
        ),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Text('Versé par :', style: const pw.TextStyle(fontSize: 10)),
            pw.SizedBox(height: cachet != null ? 4 : 30),
            if (cachet != null)
              pw.Container(
                  width: 80,
                  height: 60,
                  child: pw.Image(cachet, fit: pw.BoxFit.contain))
            else
              ligneVide,
          ],
        ),
      ],
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
