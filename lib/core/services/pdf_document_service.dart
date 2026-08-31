import 'dart:io';
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import '../../domain/entities/printable_document.dart';
import '../../domain/entities/app_settings.dart';
import '../../domain/entities/payment_receipt.dart';
import '../../core/constants/app_identity.dart';
import '../utils/currency_formatter.dart';
import '../utils/date_formatter.dart';

/// Génère un PDF de facture/achat professionnel et volontairement
/// simple, conçu pour tenir sur une seule page et rester lisible par
/// un commerçant malien peu familier avec l'informatique.
///
/// Travaille sur la structure générique [PrintableDocument], ce qui
/// permet de réutiliser le même générateur pour tous les types de
/// documents (facture, achat, devis...) sans dupliquer la mise en page.
class PdfDocumentService {
  PdfDocumentService._();

  static const PdfColor _couleurPrimaire = PdfColor.fromInt(0xFF1E6F46);
  static const PdfColor _couleurTexteSecondaire = PdfColor.fromInt(0xFF6B7280);
  static const PdfColor _couleurBordure = PdfColor.fromInt(0xFFBFC5CC);
  static const PdfColor _couleurFondTotal = PdfColor.fromInt(0xFFE7F4ED);

  /// Génère le PDF et retourne le chemin du fichier écrit sur le
  /// disque, dans le dossier de données de l'application.
  static Future<String> generateAndSave({
    required PrintableDocument document,
    required AppSettingsEntity settings,
  }) async {
    final bytes = await _buildPdfBytes(document: document, settings: settings);

    final dir = await getApplicationDocumentsDirectory();
    final outputDir = Directory(p.join(dir.path, 'MaliStockPro', 'pdf'));
    if (!await outputDir.exists()) {
      await outputDir.create(recursive: true);
    }
    final filePath = p.join(outputDir.path, '${document.numero}.pdf');
    final file = File(filePath);
    await file.writeAsBytes(bytes);
    return filePath;
  }

  /// Lance la boîte de dialogue d'impression système avec le PDF du
  /// document, sans nécessairement l'enregistrer sur le disque.
  static Future<void> printDocument({
    required PrintableDocument document,
    required AppSettingsEntity settings,
  }) async {
    final bytes = await _buildPdfBytes(document: document, settings: settings);
    await Printing.layoutPdf(
      onLayout: (_) async => bytes,
      name: document.numero,
    );
  }

  static Future<Uint8List> _buildPdfBytes({
    required PrintableDocument document,
    required AppSettingsEntity settings,
  }) async {
    final pdf = pw.Document();

    pw.MemoryImage? logoImage;
    if (settings.logoPath != null) {
      final logoFile = File(settings.logoPath!);
      if (await logoFile.exists()) {
        logoImage = pw.MemoryImage(await logoFile.readAsBytes());
      }
    }

    // MultiPage (et non Page) : un document avec beaucoup de lignes
    // (proforma, facture...) doit basculer sur une 2e page plutôt que
    // de voir son tableau/total/pied de page silencieusement coupés —
    // contrairement à Flutter, package:pdf ne signale pas un
    // dépassement de page, il l'ignore purement et simplement.
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        header: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            _buildEntete(settings, logoImage),
            pw.SizedBox(height: 14),
            pw.Divider(color: _couleurBordure, thickness: 1),
            pw.SizedBox(height: 14),
          ],
        ),
        footer: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Divider(color: _couleurBordure, thickness: 1),
            pw.SizedBox(height: 10),
            if (context.pageNumber == context.pagesCount)
              document.typeDocument == 'ACHAT'
                  ? _buildPiedDePageAchat()
                  : _buildPiedDePage(settings),
          ],
        ),
        build: (context) => [
          _buildInfosClientEtDocument(document),
          pw.SizedBox(height: 18),
          _buildTableauArticles(document),
          pw.SizedBox(height: 16),
          _buildTotal(document),
        ],
      ),
    );

    return pdf.save();
  }

  /// En-tête : logo, nom du commerce, slogan, adresse, téléphone, email.
  static pw.Widget _buildEntete(
      AppSettingsEntity settings, pw.MemoryImage? logo) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        if (logo != null) ...[
          pw.Container(
            width: 56,
            height: 56,
            child: pw.Image(logo, fit: pw.BoxFit.contain),
          ),
          pw.SizedBox(width: 14),
        ],
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                settings.nomEntreprise.toUpperCase(),
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                  color: _couleurPrimaire,
                ),
              ),
              if (settings.slogan != null) ...[
                pw.SizedBox(height: 2),
                pw.Text(
                  settings.slogan!,
                  style: pw.TextStyle(
                    fontSize: 9,
                    color: _couleurTexteSecondaire,
                    fontStyle: pw.FontStyle.italic,
                  ),
                ),
              ],
            ],
          ),
        ),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            if (settings.adresse != null)
              pw.Text(settings.adresse!, style: const pw.TextStyle(fontSize: 9)),
            if (settings.telephone != null)
              pw.Text('Tél : ${settings.telephone}',
                  style: const pw.TextStyle(fontSize: 9)),
            if (settings.email != null)
              pw.Text(settings.email!, style: const pw.TextStyle(fontSize: 9)),
            if (settings.nif != null)
              pw.Text('NIF : ${settings.nif}',
                  style: const pw.TextStyle(fontSize: 9)),
            if (settings.rccm != null)
              pw.Text('RCCM : ${settings.rccm}',
                  style: const pw.TextStyle(fontSize: 9)),
          ],
        ),
      ],
    );
  }

  /// Bloc tiers (client ou fournisseur, selon le type de document) à
  /// gauche, repères du document (date/heure/numéro/magasin) à
  /// droite, conformément à la disposition demandée.
  static pw.Widget _buildInfosClientEtDocument(PrintableDocument document) {
    final libelleTiers =
        document.typeDocument == 'ACHAT' ? 'Fournisseur' : 'Client';
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('$libelleTiers : ${document.tiersNom}',
                  style: pw.TextStyle(
                      fontSize: 11, fontWeight: pw.FontWeight.bold)),
              if (document.tiersTelephone != null)
                pw.Text('Téléphone : ${document.tiersTelephone}',
                    style: const pw.TextStyle(fontSize: 10)),
              if (document.tiersAdresse != null)
                pw.Text('Adresse : ${document.tiersAdresse}',
                    style: const pw.TextStyle(fontSize: 10)),
              if (document.tiersNif != null)
                pw.Text('NIF : ${document.tiersNif}',
                    style: const pw.TextStyle(fontSize: 10)),
            ],
          ),
        ),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Text('Date : ${DateFormatter.formatDate(document.dateCreation)}',
                style: const pw.TextStyle(fontSize: 10)),
            pw.Text('Heure : ${_formatHeure(document.dateCreation)}',
                style: const pw.TextStyle(fontSize: 10)),
            if (document.storeNom != null)
              pw.Text('Magasin : ${document.storeNom}',
                  style: const pw.TextStyle(fontSize: 10)),
            pw.SizedBox(height: 4),
            pw.Text('N° ${document.numero}',
                style: pw.TextStyle(
                    fontSize: 11,
                    fontWeight: pw.FontWeight.bold,
                    color: _couleurPrimaire)),
          ],
        ),
      ],
    );
  }

  /// Tableau des lignes. Deux variantes :
  /// - Documents avec TVA (ventes V2) : N° / Désignation / Qté / PU /
  ///   Remise / TVA / Montant HT / Montant TTC.
  /// - Documents sans TVA (achats, factures V1) : N° / Désignation /
  ///   Qté / Prix unitaire / Montant, inchangé.
  static pw.Widget _buildTableauArticles(PrintableDocument document) {
    final avecTva =
        document.lignes.any((l) => l.tauxTva != null || l.remisePct != null);

    if (!avecTva) {
      return pw.Table(
        border: pw.TableBorder(
          top: pw.BorderSide(color: _couleurBordure, width: 1),
          bottom: pw.BorderSide(color: _couleurBordure, width: 1),
          horizontalInside: pw.BorderSide(color: _couleurBordure, width: 0.5),
        ),
        columnWidths: const {
          0: pw.FlexColumnWidth(0.6),
          1: pw.FlexColumnWidth(3.4),
          2: pw.FlexColumnWidth(0.8),
          3: pw.FlexColumnWidth(1.4),
          4: pw.FlexColumnWidth(1.4),
        },
        children: [
          pw.TableRow(
            decoration: pw.BoxDecoration(color: _couleurFondTotal),
            children: [
              _cellHeader('N°'),
              _cellHeader('Désignation'),
              _cellHeader('Qté', align: pw.TextAlign.center),
              _cellHeader('Prix unitaire', align: pw.TextAlign.right),
              _cellHeader('Montant', align: pw.TextAlign.right),
            ],
          ),
          ...document.lignes.asMap().entries.map((entry) {
            final index = entry.key + 1;
            final ligne = entry.value;
            return pw.TableRow(
              children: [
                _cell('$index'),
                _cell(ligne.designation),
                _cell(ligne.quantite.toStringAsFixed(0),
                    align: pw.TextAlign.center),
                _cell(CurrencyFormatter.formatSansDevise(ligne.prixUnitaire),
                    align: pw.TextAlign.right),
                _cell(CurrencyFormatter.formatSansDevise(ligne.totalLigne),
                    align: pw.TextAlign.right),
              ],
            );
          }),
        ],
      );
    }

    return pw.Table(
      border: pw.TableBorder(
        top: pw.BorderSide(color: _couleurBordure, width: 1),
        bottom: pw.BorderSide(color: _couleurBordure, width: 1),
        horizontalInside: pw.BorderSide(color: _couleurBordure, width: 0.5),
      ),
      columnWidths: const {
        0: pw.FlexColumnWidth(0.3),
        1: pw.FlexColumnWidth(2.5),
        2: pw.FlexColumnWidth(0.6),
        3: pw.FlexColumnWidth(1.0),
        4: pw.FlexColumnWidth(1.0),
        5: pw.FlexColumnWidth(0.6),
        6: pw.FlexColumnWidth(1.0),
        7: pw.FlexColumnWidth(1.0),
      },
      children: [
        pw.TableRow(
          decoration: pw.BoxDecoration(color: _couleurFondTotal),
          children: [
            _cellHeader('N°'),
            _cellHeader('Désignation'),
            _cellHeader('Qté', align: pw.TextAlign.center),
            _cellHeader('P.U.', align: pw.TextAlign.right),
            _cellHeader('Remise', align: pw.TextAlign.right),
            _cellHeader('TVA', align: pw.TextAlign.right),
            _cellHeader('Mont. HT', align: pw.TextAlign.right),
            _cellHeader('Mont. TTC', align: pw.TextAlign.right),
          ],
        ),
        ...document.lignes.asMap().entries.map((entry) {
          final index = entry.key + 1;
          final ligne = entry.value;
          return pw.TableRow(
            children: [
              _cell('$index'),
              _cell(ligne.designation),
              _cell(ligne.quantite.toStringAsFixed(
                  ligne.quantite == ligne.quantite.truncate() ? 0 : 2),
                  align: pw.TextAlign.center),
              _cell(CurrencyFormatter.formatSansDevise(ligne.prixUnitaire),
                  align: pw.TextAlign.right),
              _cell(
                  ligne.remisePct != null && ligne.remisePct! > 0
                      ? '${ligne.remisePct!.toStringAsFixed(0)}%'
                      : '-',
                  align: pw.TextAlign.right),
              _cell(
                  ligne.tauxTva != null
                      ? '${ligne.tauxTva!.toStringAsFixed(0)}%'
                      : '-',
                  align: pw.TextAlign.right),
              _cell(
                  CurrencyFormatter.formatSansDevise(
                      ligne.totalHt ?? ligne.totalLigne),
                  align: pw.TextAlign.right),
              _cell(
                  CurrencyFormatter.formatSansDevise(
                      ligne.totalTtc ?? ligne.totalLigne),
                  align: pw.TextAlign.right),
            ],
          );
        }),
      ],
    );
  }

  static pw.Widget _cellHeader(String text, {pw.TextAlign? align}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
      ),
    );
  }

  static pw.Widget _cell(String text, {pw.TextAlign? align}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      child: pw.Text(text,
          textAlign: align, style: const pw.TextStyle(fontSize: 10)),
    );
  }

  /// Montant total, affiché très visible comme demandé, avec le détail
  /// remise/payé/reste seulement s'ils sont pertinents (remise non
  /// nulle, paiement partiel).
  static pw.Widget _buildTotal(PrintableDocument document) {
    return pw.Align(
      alignment: pw.Alignment.centerRight,
      child: pw.Container(
        width: 260,
        padding: const pw.EdgeInsets.all(14),
        decoration: pw.BoxDecoration(
          color: _couleurFondTotal,
          borderRadius: pw.BorderRadius.circular(8),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            if (document.remise > 0) ...[
              _ligneDiscrete('Sous-total HT brut', document.sousTotal),
              _ligneDiscrete('Remise', -document.remise),
              pw.SizedBox(height: 2),
            ],
            // Détail TVA : affiché uniquement si TVA > 0.
            if (document.totalTva != null && document.totalTva! > 0) ...[
              _ligneDiscrete(
                  'Total HT', document.totalHtNet ?? document.totalFinal),
              _ligneDiscrete(
                _libelleTva(document.tvaGlobalePct),
                document.totalTva!,
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(vertical: 3),
                child: pw.Container(height: 0.5, color: _couleurBordure),
              ),
            ],
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  document.totalTva != null && document.totalTva! > 0
                      ? 'TOTAL TTC'
                      : 'MONTANT TOTAL',
                  style: pw.TextStyle(
                      fontSize: 13, fontWeight: pw.FontWeight.bold),
                ),
                pw.Text(
                  CurrencyFormatter.format(document.totalFinal),
                  style: pw.TextStyle(
                      fontSize: 15,
                      fontWeight: pw.FontWeight.bold,
                      color: _couleurPrimaire),
                ),
              ],
            ),
            if (document.resteAPayer > 0) ...[
              pw.SizedBox(height: 6),
              _ligneDiscrete('Montant payé', document.montantPaye),
              _ligneDiscrete('Reste à payer', document.resteAPayer,
                  gras: true),
            ],
          ],
        ),
      ),
    );
  }

  static String _libelleTva(double? taux) {
    if (taux == null) return 'TVA';
    final s = taux % 1 == 0 ? taux.toStringAsFixed(0) : taux.toString();
    return 'TVA ($s %)';
  }

  static pw.Widget _ligneDiscrete(String label, double valeur,
      {bool gras = false}) {
    final style = pw.TextStyle(
      fontSize: gras ? 11 : 9.5,
      fontWeight: gras ? pw.FontWeight.bold : pw.FontWeight.normal,
    );
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: style),
          pw.Text(CurrencyFormatter.format(valeur), style: style),
        ],
      ),
    );
  }

  /// Pied de page : commentaire configurable par le commerçant dans
  /// les paramètres de l'entreprise. Utilisé pour les factures.
  static pw.Widget _buildPiedDePage(AppSettingsEntity settings) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Text(
          settings.commentairePiedDePage,
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(fontSize: 9, color: _couleurTexteSecondaire),
        ),
        pw.SizedBox(height: 6),
        _mentionEditeur(),
      ],
    );
  }

  /// Pied de page spécifique aux achats fournisseurs : zone
  /// d'observations libres et emplacement de signature, conformément
  /// aux documents d'achat habituels (réception de marchandise).
  static pw.Widget _buildPiedDePageAchat() {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('Observations :',
            style: pw.TextStyle(
                fontSize: 9, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 16),
        pw.Container(height: 1, color: _couleurBordure),
        pw.SizedBox(height: 24),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Signature fournisseur',
                    style: pw.TextStyle(
                        fontSize: 9, color: _couleurTexteSecondaire)),
                pw.SizedBox(height: 28),
                pw.Container(width: 140, height: 1, color: _couleurBordure),
              ],
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Signature réceptionnaire',
                    style: pw.TextStyle(
                        fontSize: 9, color: _couleurTexteSecondaire)),
                pw.SizedBox(height: 28),
                pw.Container(width: 140, height: 1, color: _couleurBordure),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 12),
        _mentionEditeur(),
      ],
    );
  }

  /// Mention discrète de l'éditeur, affichée en bas de tous les
  /// documents PDF. Petite taille, centrée, non intrusive — chaque
  /// impression devient un vecteur de visibilité pour MALICODE_CENTER.
  static pw.Widget _mentionEditeur() {
    return pw.Center(
      child: pw.Text(
        AppIdentity.mentionPdf,
        textAlign: pw.TextAlign.center,
        style: pw.TextStyle(
          fontSize: 7,
          color: const PdfColor.fromInt(0xFFBFC5CC),
          fontStyle: pw.FontStyle.italic,
        ),
      ),
    );
  }

  static String _formatHeure(DateTime date) {
    final h = date.hour.toString().padLeft(2, '0');
    final m = date.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  // ── Reçu de paiement ─────────────────────────────────────────────────────

  /// Génère le PDF du reçu et retourne le chemin du fichier écrit sur le
  /// disque, dans le dossier de données de l'application.
  static Future<String> generateAndSaveReceipt({
    required PaymentReceiptEntity receipt,
    required AppSettingsEntity settings,
  }) async {
    final bytes = await _buildRecuPdfBytes(receipt: receipt, settings: settings);

    final dir = await getApplicationDocumentsDirectory();
    final outputDir = Directory(p.join(dir.path, 'MaliStockPro', 'pdf'));
    if (!await outputDir.exists()) {
      await outputDir.create(recursive: true);
    }
    final filePath = p.join(outputDir.path, '${receipt.numeroRecu}.pdf');
    final file = File(filePath);
    await file.writeAsBytes(bytes);
    return filePath;
  }

  /// Lance la boîte de dialogue d'impression système avec le PDF du reçu.
  static Future<void> printReceipt({
    required PaymentReceiptEntity receipt,
    required AppSettingsEntity settings,
  }) async {
    final bytes = await _buildRecuPdfBytes(receipt: receipt, settings: settings);
    await Printing.layoutPdf(
      onLayout: (_) async => bytes,
      name: receipt.numeroRecu,
    );
  }

  static Future<Uint8List> _buildRecuPdfBytes({
    required PaymentReceiptEntity receipt,
    required AppSettingsEntity settings,
  }) async {
    final pdf = pw.Document();

    pw.MemoryImage? logoImage;
    if (settings.logoPath != null) {
      final logoFile = File(settings.logoPath!);
      if (await logoFile.exists()) {
        logoImage = pw.MemoryImage(await logoFile.readAsBytes());
      }
    }

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _buildEntete(settings, logoImage),
              pw.SizedBox(height: 14),
              pw.Divider(color: _couleurBordure, thickness: 1),
              pw.SizedBox(height: 14),
              _buildRecuTitre(receipt),
              pw.SizedBox(height: 18),
              _buildRecuDetails(receipt),
              pw.SizedBox(height: 18),
              if (receipt.factureSoldee) _buildBandeauSoldee(),
              pw.Spacer(),
              _buildRecuSignature(),
              pw.SizedBox(height: 10),
              pw.Divider(color: _couleurBordure, thickness: 1),
              pw.SizedBox(height: 10),
              _buildPiedDePage(settings),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildRecuTitre(PaymentReceiptEntity receipt) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          receipt.typePaiement == 'achat'
              ? 'REÇU DE PAIEMENT - ACHAT'
              : 'REÇU DE PAIEMENT - VENTE',
          style: pw.TextStyle(
              fontSize: 15, fontWeight: pw.FontWeight.bold, color: _couleurPrimaire),
        ),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Text('N° ${receipt.numeroRecu}',
                style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
            pw.Text('Date : ${DateFormatter.formatDate(receipt.datePaiement)}',
                style: const pw.TextStyle(fontSize: 10)),
            pw.Text('Heure : ${_formatHeure(receipt.datePaiement)}',
                style: const pw.TextStyle(fontSize: 10)),
          ],
        ),
      ],
    );
  }

  static pw.Widget _buildRecuDetails(PaymentReceiptEntity receipt) {
    final libelleTiers = receipt.typePaiement == 'achat' ? 'Fournisseur' : 'Client';
    return pw.Container(
      padding: const pw.EdgeInsets.all(14),
      decoration: pw.BoxDecoration(
        color: _couleurFondTotal,
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          _ligneRecu(libelleTiers, receipt.tiersNom, gras: true),
          _ligneRecu('N° de la facture concernée', receipt.numeroDocument),
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 6),
            child: pw.Container(height: 0.5, color: _couleurBordure),
          ),
          _ligneRecu('Montant total de la facture',
              CurrencyFormatter.format(receipt.montantTotalDocument)),
          _ligneRecu('Montant payé avant ce règlement',
              CurrencyFormatter.format(receipt.montantPayeAvant)),
          _ligneRecu('Montant reçu aujourd\'hui',
              CurrencyFormatter.format(receipt.montantRecu), gras: true),
          _ligneRecu('Nouveau reste à payer',
              CurrencyFormatter.format(
                  receipt.nouveauReste < 0 ? 0 : receipt.nouveauReste),
              gras: true),
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 6),
            child: pw.Container(height: 0.5, color: _couleurBordure),
          ),
          _ligneRecu('Mode de paiement', _libelleMode(receipt.modePaiement)),
          _ligneRecu('Enregistré par', receipt.utilisateur ?? '-'),
        ],
      ),
    );
  }

  static pw.Widget _ligneRecu(String label, String valeur, {bool gras = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label,
              style: pw.TextStyle(
                  fontSize: 10, color: _couleurTexteSecondaire)),
          pw.Text(valeur,
              style: pw.TextStyle(
                  fontSize: gras ? 12 : 10.5,
                  fontWeight: gras ? pw.FontWeight.bold : pw.FontWeight.normal)),
        ],
      ),
    );
  }

  static String _libelleMode(String mode) => switch (mode) {
        'especes' => 'Espèces',
        'cheque' => 'Chèque',
        'virement' => 'Virement',
        'mobile_money' => 'Mobile Money',
        'carte' => 'Carte bancaire',
        'avoir' => 'Avoir',
        'orange_money' => 'Orange Money',
        'moov_money' => 'Moov Money',
        _ => mode,
      };

  static pw.Widget _buildBandeauSoldee() {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.symmetric(vertical: 10),
      decoration: pw.BoxDecoration(
        color: _couleurPrimaire,
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Center(
        child: pw.Text(
          'STATUT : FACTURE SOLDÉE',
          style: pw.TextStyle(
              fontSize: 13,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white),
        ),
      ),
    );
  }

  /// Emplacement de signature, réutilisé du pied de page achat.
  static pw.Widget _buildRecuSignature() {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.end,
      children: [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('Signature',
                style: pw.TextStyle(fontSize: 9, color: _couleurTexteSecondaire)),
            pw.SizedBox(height: 28),
            pw.Container(width: 160, height: 1, color: _couleurBordure),
          ],
        ),
      ],
    );
  }
}
