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
