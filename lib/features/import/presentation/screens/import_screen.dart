import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';
import 'package:laidani_repair/core/providers/supabase_provider.dart';

const Color _bgCarbon = Color(0xFF050914);
const Color _panelDark = Color(0xFF0A0F1A);
const Color _glassBorder = Color(0x1AFFFFFF);
const Color _textMuted = Color(0xFF8A9BB4);
const Color _neonCyan = Color(0xFF00E5FF);

class ImportScreen extends ConsumerStatefulWidget {
  const ImportScreen({super.key});

  @override
  ConsumerState<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends ConsumerState<ImportScreen> {
  List<String>? _headers;
  List<List<dynamic>>? _rows;
  List<int> _errorRows = [];
  String? _targetTable;
  bool _loading = false;
  final Map<int, String> _errorMessages = {};

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );

    if (result == null || result.files.isEmpty) return;

    final file = File(result.files.single.path!);
    final content = await file.readAsString(encoding: utf8);
    final csvData = const CsvToListConverter().convert(content);

    if (csvData.isEmpty) {
      _showSnack('Fichier CSV vide', Colors.redAccent);
      return;
    }

    setState(() {
      _headers = csvData.first.map((h) => h.toString()).toList();
      _rows = csvData.skip(1).where((r) => r.isNotEmpty).toList();
      _errorRows = [];
      _errorMessages.clear();
    });
  }

  void _validateColumns() {
    if (_headers == null || _rows == null) return;

    final requiredColumns = _getRequiredColumns();
    final errorIndices = <int>{};

    for (int i = 0; i < _rows!.length; i++) {
      final row = _rows![i];
      final errors = <String>[];

      for (final col in requiredColumns) {
        final idx = _headers!.indexWhere((h) => h.trim().toLowerCase() == col.toLowerCase());
        if (idx >= 0 && idx < row.length) {
          if (row[idx].toString().trim().isEmpty) {
            errors.add('$col est vide');
          }
        } else {
          errors.add('Colonne "$col" manquante');
        }
      }

      if (errors.isNotEmpty) {
        errorIndices.add(i);
        _errorMessages[i] = errors.join(', ');
      }
    }

    setState(() {
      _errorRows = errorIndices.toList()..sort();
    });
  }

  List<String> _getRequiredColumns() {
    if (_targetTable == 'products') return ['product_name', 'reference_price'];
    if (_targetTable == 'customers') return ['full_name'];
    return [];
  }

  Map<String, String> _getColumnMapping() {
    if (_targetTable == 'products') {
      return {
        'product_name': 'product_name',
        'reference_price': 'reference_price',
        'purchase_price': 'purchase_price',
        'barcode': 'barcode',
        'stock_quantity': 'stock_quantity',
        'min_stock': 'min_stock',
      };
    }
    if (_targetTable == 'customers') {
      return {
        'full_name': 'full_name',
        'phone_number': 'phone_number',
      };
    }
    return {};
  }

  Future<void> _import() async {
    if (_rows == null || _headers == null || _targetTable == null) return;
    if (_errorRows.isNotEmpty) {
      _showSnack('Corrigez les erreurs avant d\'importer', Colors.orangeAccent);
      return;
    }

    setState(() => _loading = true);
    final client = ref.read(supabaseClientProvider);
    final mapping = _getColumnMapping();
    int imported = 0;
    int errors = 0;

    for (int i = 0; i < _rows!.length; i++) {
      final row = _rows![i];
      final data = <String, dynamic>{};

      for (final entry in mapping.entries) {
        final colIdx = _headers!.indexWhere((h) => h.trim().toLowerCase() == entry.key.toLowerCase());
        if (colIdx >= 0 && colIdx < row.length) {
          final value = row[colIdx].toString().trim();
          if (value.isNotEmpty) {
            if (entry.key.contains('price') || entry.key.contains('stock') || entry.key.contains('min')) {
              data[entry.value] = double.tryParse(value) ?? int.tryParse(value) ?? 0;
            } else {
              data[entry.value] = value;
            }
          }
        }
      }

      if (data.isNotEmpty) {
        try {
          await client.from(_targetTable!).insert(data);
          imported++;
        } catch (e) {
          errors++;
          _errorMessages[i] = 'Erreur: $e';
        }
      }
    }

    setState(() {
      _loading = false;
      if (errors > 0) {
        _errorRows = List.generate(_rows!.length, (i) => i).where((i) => _errorMessages.containsKey(i)).toList();
      }
    });

    _showSnack('$imported enregistrements importés, $errors erreurs', errors > 0 ? Colors.orangeAccent : Colors.green);
  }

  void _showSnack(String msg, Color color) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgCarbon,
      body: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.file_upload, color: _neonCyan, size: 28),
                SizedBox(width: 12),
                Text('IMPORT CSV', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: _pickFile,
                  icon: const Icon(Icons.file_open),
                  label: const Text('Choisir un fichier CSV'),
                  style: ElevatedButton.styleFrom(backgroundColor: _neonCyan.withOpacity(0.1), foregroundColor: _neonCyan, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16)),
                ),
                const SizedBox(width: 16),
                DropdownButton<String>(
                  value: _targetTable,
                  dropdownColor: _panelDark,
                  style: const TextStyle(color: Colors.white),
                  hint: const Text('Table cible', style: TextStyle(color: _textMuted)),
                  items: const [
                    DropdownMenuItem(value: 'products', child: Text('Produits')),
                    DropdownMenuItem(value: 'customers', child: Text('Clients')),
                  ],
                  onChanged: (v) => setState(() => _targetTable = v),
                ),
                const SizedBox(width: 16),
                if (_rows != null && _targetTable != null)
                  ElevatedButton.icon(
                    onPressed: _validateColumns,
                    icon: const Icon(Icons.checklist),
                    label: const Text('Valider'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.orangeAccent.withOpacity(0.1), foregroundColor: Colors.orangeAccent),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (_headers != null && _rows != null) ...[
              Row(
                children: [
                  Text('${_rows!.length} ligne(s) détectée(s)', style: const TextStyle(color: _textMuted)),
                  if (_errorRows.isNotEmpty) ...[
                    const SizedBox(width: 16),
                    Text('${_errorRows.length} erreur(s)', style: const TextStyle(color: Colors.redAccent)),
                  ],
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(border: Border.all(color: _glassBorder), borderRadius: BorderRadius.circular(8)),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SingleChildScrollView(
                      child: DataTable(
                        headingRowColor: WidgetStateProperty.all(_panelDark),
                        dataRowColor: WidgetStateProperty.all(_bgCarbon),
                        columns: _headers!.map((h) => DataColumn(label: Text(h, style: const TextStyle(color: _neonCyan, fontWeight: FontWeight.bold, fontSize: 12)))).toList(),
                        rows: _rows!.asMap().entries.map((e) {
                          final isError = _errorRows.contains(e.key);
                          final errorMsg = _errorMessages[e.key];
                          return DataRow(
                            color: WidgetStateProperty.all(isError ? Colors.redAccent.withOpacity(0.1) : null),
                            cells: e.value.map<DataCell>((cell) {
                              return DataCell(Text(
                                cell.toString(),
                                style: TextStyle(color: isError ? Colors.redAccent : Colors.white, fontSize: 12),
                              ));
                            }).toList(),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ElevatedButton.icon(
                    onPressed: (_loading || _errorRows.isNotEmpty) ? null : _import,
                    icon: _loading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.cloud_upload),
                    label: const Text('Importer dans Supabase'),
                    style: ElevatedButton.styleFrom(backgroundColor: _neonCyan, foregroundColor: _bgCarbon, padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16)),
                  ),
                ],
              ),
            ] else
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.file_upload_outlined, size: 64, color: _textMuted.withOpacity(0.2)),
                      const SizedBox(height: 16),
                      const Text('Sélectionnez un fichier CSV pour commencer', style: TextStyle(color: _textMuted)),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
