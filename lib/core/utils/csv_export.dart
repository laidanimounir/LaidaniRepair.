import 'dart:io';
import 'package:flutter/material.dart';

Future<String> exportToCsv({
  required List<String> headers,
  required List<List<dynamic>> rows,
}) async {
  final buffer = StringBuffer();
  buffer.writeln(headers.map((h) => _csvEscape(h)).join(','));
  for (final row in rows) {
    buffer.writeln(row.map((cell) => _csvEscape(cell.toString())).join(','));
  }
  return buffer.toString();
}

String _csvEscape(String value) {
  if (value.contains(',') || value.contains('"') || value.contains('\n')) {
    return '"${value.replaceAll('"', '""')}"';
  }
  return value;
}

Future<void> shareCsv(BuildContext context, String csv, String fileName) async {
  final dir = Directory.systemTemp;
  final file = File('${dir.path}/$fileName');
  await file.writeAsString(csv);
  await _showSaveDialog(context, file.path);
}

Future<void> _showSaveDialog(BuildContext context, String filePath) async {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text('Fichier CSV: $filePath'),
      duration: const Duration(seconds: 5),
      action: SnackBarAction(
        label: 'Ouvrir',
        onPressed: () => Process.run('explorer', ['/select,', filePath]),
      ),
    ),
  );
}
