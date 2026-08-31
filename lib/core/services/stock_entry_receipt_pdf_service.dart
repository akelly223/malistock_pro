import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show compute;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../domain/entities/app_settings.dart';
import '../constants/app_identity.dart';
import '../utils/date_formatter.dart';

/// Une ligne du reçu : article + quantité reçue.
typedef StockReceiptLigne = ({String code, String nom, double quantite});

/// Génère le reçu papier d'un mouvement de stock manuel (entrée ou
/// sortie) — volontairement indépendant de tout achat ou facture :
/// sert de preuve remise à un fournisseur/auteur lors d'une réception
/// ou d'une reprise de dépôt-vente, sans jamais créer de dette ni de
/// document comptable.
class StockEntryReceiptPdfService {
  StockEntryReceiptPdfService._();

  static const PdfColor _couleurPrimaire = PdfColor.fromInt(0xFF1E6F46);
  static const PdfColor _couleurTexteSecondaire = PdfColor.fromInt(0xFF6B7280);
  static const PdfColor _couleurBordure = PdfColor.fromInt(0xFFBFC5CC);
  static const PdfColor _couleurFond = PdfColor.fromInt(0xFFE7F4ED);

  static Future<void> print({
    required List<StockReceiptLigne> lignes,
    required String storeNom,
    required String? reference,
    required DateTime date,
    required AppSettingsEntity settings,
    bool estSortie = false,
  }) async {
    final bytes = await compute(
        _buildPdfBytesSync,
        (
          lignes: lignes,
          storeNom: storeNom,
          reference: reference,
          date: date,
          settings: settings,
          estSortie: estSortie,
        ));
    await Printing.layoutPdf(
      onLayout: (_) async => bytes,
      name: estSortie ? 'Bon de sortie' : 'Reçu de réception',
    );
  }

  static Future<Uint8List> _buildPdfBytesSync(
      ({
        List<StockReceiptLigne> lignes,
        String storeNom,
        String? reference,
        DateTime date,
        AppSettingsEntity settings,
        bool estSortie,
      }) args) {
    return _buildPdfBytes(
      lignes: args.lignes,
      storeNom: args.storeNom,
      reference: args.reference,
      date: args.date,
      settings: args.settings,
      estSortie: args.estSortie,
    );
  }

  static Future<Uint8List> _buildPdfBytes({
    required List<StockReceiptLigne> lignes,
    required String storeNom,
    required String? reference,
    required DateTime date,
    required AppSettingsEntity settings,
    required bool estSortie,
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

    final totalQuantite = lignes.fold<double>(0, (s, l) => s + l.quantite);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (context) => [
          _buildEntete(settings, logo, estSortie),
          pw.SizedBox(height: 14),
          pw.Divider(color: _couleurBordure, thickness: 1),
          pw.SizedBox(height: 14),
          _buildInfos(storeNom, reference, date),
          pw.SizedBox(height: 18),
          pw.Text(
              '${estSortie ? "Articles sortis" : "Articles réceptionnés"} (${lignes.length})',
              style:
                  pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          _buildTableau(lignes),
          pw.SizedBox(height: 16),
          _buildTotal(totalQuantite),
          pw.SizedBox(height: 40),
          _buildSignatures(reference, cachet),
          pw.SizedBox(height: 20),
          _mentionEditeur(),
        ],
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildEntete(
      AppSettingsEntity settings, pw.MemoryImage? logo, bool estSortie) {
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
            pw.Text(estSortie ? 'BON DE SORTIE' : 'REÇU DE RÉCEPTION',
                style: pw.TextStyle(
                    fontSize: 13,
                    fontWeight: pw.FontWeight.bold,
                    color: _couleurPrimaire)),
            pw.Text(
                estSortie
                    ? 'Retour fournisseur / sortie manuelle'
                    : 'Dépôt-vente / entrée manuelle',
                style: pw.TextStyle(fontSize: 9, color: _couleurTexteSecondaire)),
          ],
        ),
      ],
    );
  }

  static pw.Widget _buildInfos(
      String storeNom, String? reference, DateTime date) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('Magasin : $storeNom',
                style:
                    pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
            if (reference != null && reference.isNotEmpty)
              pw.Text('Auteur / Fournisseur : $reference',
                  style: const pw.TextStyle(fontSize: 10)),
          ],
        ),
        pw.Text('Date : ${DateFormatter.formatDateTime(date)}',
            style: const pw.TextStyle(fontSize: 10)),
      ],
    );
  }

  static pw.Widget _buildTableau(List<StockReceiptLigne> lignes) {
    return pw.Table(
      border: pw.TableBorder(
        top: pw.BorderSide(color: _couleurBordure, width: 1),
        bottom: pw.BorderSide(color: _couleurBordure, width: 1),
        horizontalInside: pw.BorderSide(color: _couleurBordure, width: 0.5),
      ),
      columnWidths: const {
        0: pw.FlexColumnWidth(1.5),
        1: pw.FlexColumnWidth(4.0),
        2: pw.FlexColumnWidth(1.5),
      },
      children: [
        pw.TableRow(
          decoration: pw.BoxDecoration(color: _couleurFond),
          children: [
            _cellHeader('Code'),
            _cellHeader('Désignation'),
            _cellHeader('Quantité', align: pw.TextAlign.right),
          ],
        ),
        ...lignes.map((l) => pw.TableRow(children: [
              _cell(l.code),
              _cell(l.nom),
              _cell(l.quantite.toStringAsFixed(0), align: pw.TextAlign.right),
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

  static pw.Widget _buildTotal(double totalQuantite) {
    return pw.Align(
      alignment: pw.Alignment.centerRight,
      child: pw.Container(
        padding: const pw.EdgeInsets.all(12),
        decoration: pw.BoxDecoration(
            color: _couleurFond, borderRadius: pw.BorderRadius.circular(8)),
        child: pw.Text(
            'TOTAL : ${totalQuantite.toStringAsFixed(0)} unité${totalQuantite > 1 ? 's' : ''}',
            style: pw.TextStyle(
                fontSize: 11,
                fontWeight: pw.FontWeight.bold,
                color: _couleurPrimaire)),
      ),
    );
  }

  static pw.Widget _buildSignatures(String? reference, pw.MemoryImage? cachet) {
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
            pw.Text(
                'Remis par${reference != null && reference.isNotEmpty ? ' ($reference)' : ''} :',
                style: const pw.TextStyle(fontSize: 10)),
            pw.SizedBox(height: 30),
            ligneVide,
          ],
        ),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Text('Reçu par :', style: const pw.TextStyle(fontSize: 10)),
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
