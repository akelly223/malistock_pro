import 'dart:convert';
import 'dart:io';
import 'package:excel/excel.dart';
import 'package:path/path.dart' as p;
import 'parsed_file.dart';

/// Point d'entrée unique : parse n'importe quel fichier supporté
/// (CSV, TXT, XLSX) et retourne un [ParsedFile].
abstract final class FileParser {
  static Future<ParsedFile> parse(String filePath) async {
    final ext = p.extension(filePath).toLowerCase();
    final name = p.basename(filePath);
    if (ext == '.xlsx') {
      return _parseExcel(filePath, name);
    }
    return _parseCsvTxt(filePath, name);
  }

  // ── CSV / TXT ─────────────────────────────────────────────────────────────

  static Future<ParsedFile> _parseCsvTxt(String filePath, String name) async {
    final content = await _readText(filePath);
    final lines = content.split(RegExp(r'\r?\n'));

    List<String>? headers;
    final rows = <List<String>>[];

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      final cols = _splitLine(trimmed);

      if (headers == null) {
        headers = cols.map((c) => c.trim()).toList();
      } else {
        // Pad or trim to match header count
        final padded = List<String>.generate(
          headers.length,
          (i) => i < cols.length ? cols[i].trim() : '',
        );
        rows.add(padded);
      }
    }

    return ParsedFile(
      fileName: name,
      headers: headers ?? [],
      rows: rows,
    );
  }

  static List<String> _splitLine(String line) {
    // Priorise tabulation (Sage), puis point-virgule, puis virgule.
    if (line.contains('\t')) return line.split('\t');
    if (line.contains(';')) return _parseCsvLine(line, ';');
    return _parseCsvLine(line, ',');
  }

  /// Parse CSV simple avec gestion des guillemets.
  static List<String> _parseCsvLine(String line, String sep) {
    final result = <String>[];
    final buf = StringBuffer();
    bool inQuote = false;

    for (int i = 0; i < line.length; i++) {
      final ch = line[i];
      if (ch == '"') {
        if (inQuote && i + 1 < line.length && line[i + 1] == '"') {
          buf.write('"');
          i++;
        } else {
          inQuote = !inQuote;
        }
      } else if (ch == sep && !inQuote) {
        result.add(buf.toString());
        buf.clear();
      } else {
        buf.write(ch);
      }
    }
    result.add(buf.toString());
    return result;
  }

  static Future<String> _readText(String filePath) async {
    final file = File(filePath);
    try {
      return await file.readAsString(encoding: utf8);
    } catch (_) {
      return await file.readAsString(encoding: latin1);
    }
  }

  // ── Excel ─────────────────────────────────────────────────────────────────

  static Future<ParsedFile> _parseExcel(String filePath, String name) async {
    final bytes = await File(filePath).readAsBytes();
    final excel = Excel.decodeBytes(bytes);

    // Première feuille non vide
    Sheet? sheet;
    for (final key in excel.tables.keys) {
      final s = excel.tables[key];
      if (s != null && s.rows.isNotEmpty) {
        sheet = s;
        break;
      }
    }

    if (sheet == null || sheet.rows.isEmpty) {
      return ParsedFile(fileName: name, headers: [], rows: []);
    }

    String cellStr(Data? cell) => cell?.value?.toString().trim() ?? '';

    final rawRows = sheet.rows;
    final headers = rawRows.first.map(cellStr).toList();

    final rows = <List<String>>[];
    for (int i = 1; i < rawRows.length; i++) {
      final row = rawRows[i];
      // Ignorer les lignes entièrement vides
      final vals = List<String>.generate(
        headers.length,
        (j) => j < row.length ? cellStr(row[j]) : '',
      );
      if (vals.every((v) => v.isEmpty)) continue;
      rows.add(vals);
    }

    return ParsedFile(fileName: name, headers: headers, rows: rows);
  }
}
