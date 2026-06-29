import 'dart:io';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PrintService {
  static Future<void> printCustomerReceipt({
    required Map<String, dynamic> ticket,
    List<Map<String, dynamic>>? parts,
    BuildContext? context,
  }) async {
    final pdf = _buildReceiptPdf(ticket);
    await _printAndLog(pdf, ticket, 'customer_ticket_printed_at', context: context);
  }

  static Future<void> printDeviceLabel({
    required Map<String, dynamic> ticket,
    BuildContext? context,
  }) async {
    final pdf = pw.Document();
    pdf.addPage(_buildStickerPage(ticket));
    await _printAndLog(pdf, ticket, 'device_label_printed_at', context: context);
  }

  static Future<void> printBoth({
    required Map<String, dynamic> ticket,
    List<Map<String, dynamic>>? parts,
    BuildContext? context,
  }) async {
    final pdf = _buildReceiptPdf(ticket);
    pdf.addPage(_buildStickerPage(ticket));
    await _printAndLog(pdf, ticket, 'customer_ticket_printed_at', context: context);
    await _logPrint(ticket, 'device_label_printed_at');
  }

  static Future<void> printFull({
    required Map<String, dynamic> ticket,
    required List<Map<String, dynamic>> parts,
    BuildContext? context,
  }) async {
    final pdf = _buildReceiptPdf(ticket);
    await _printAndLog(pdf, ticket, 'customer_ticket_printed_at', context: context);
  }

  static pw.Document _buildReceiptPdf(Map<String, dynamic> ticket) {
    final pdf = pw.Document();
    final clientName = _clientName(ticket);
    final phone = _clientPhone(ticket);
    final createdAt = (ticket['created_at']?.toString() ?? '').substring(0, 16);
    final ticketId = (ticket['qr_code_hash']?.toString() ?? '').substring(0, 8);
    final deviceName = ticket['device_name'] ?? '';
    final imei = ticket['imei'] ?? '';
    final issue = ticket['issue_description'] ?? '';
    final estimatedCost = (ticket['estimated_cost'] as num?)?.toDouble() ?? 0;
    final finalCost = (ticket['final_cost'] as num?)?.toDouble() ?? estimatedCost;
    final laborCost = (ticket['labor_cost'] as num?)?.toDouble() ?? 0;
    final advance = (ticket['advance_payment'] as num?)?.toDouble() ?? 0;
    final remaining = finalCost - advance;
    final billingType = ticket['billing_type'] as String? ?? 'parts_and_labor';
    final estimatedDate = ticket['estimated_completion_date']?.toString() ?? '';
    final qrData = 'https://igxpwxfruasfpvfagbaw.supabase.co/functions/v1/track?qr=${ticket['qr_code_hash'] ?? ''}';
    final billingLabel = {
      'labor_only':      'Type: Main d\'œuvre uniquement',
      'parts_only':      'Type: Pièces uniquement',
      'parts_and_labor': 'Type: Pièces + Main d\'œuvre',
    }[billingType] ?? 'Type: Pièces + Main d\'œuvre';

    pdf.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      build: (_) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Center(child: pw.Text('LaidaniRepair', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold))),
          pw.Center(child: pw.Text('Bon de dépôt', style: pw.TextStyle(fontSize: 14))),
          pw.SizedBox(height: 16),
          _pdfRow('# Ticket', '#$ticketId'),
          _pdfRow('Date', createdAt),
          _pdfRow('Client', clientName),
          if (phone.isNotEmpty) _pdfRow('Téléphone', phone),
          _pdfRow('Appareil', deviceName),
          if (imei.isNotEmpty) _pdfRow('IMEI', imei),
          if (issue.isNotEmpty) _pdfRow('Problème', issue),
          _pdfRow('Type', billingLabel),
          pw.Divider(),
          _pdfRow('Coût estimé', '${estimatedCost.toStringAsFixed(0)} DA'),
          if (billingType != 'parts_only' && laborCost > 0)
            _pdfRow('Main d\'œuvre', '${laborCost.toStringAsFixed(0)} DA'),
          _pdfRow('Total', '${finalCost.toStringAsFixed(0)} DA'),
          if (advance > 0) _pdfRow('Avance', '${advance.toStringAsFixed(0)} DA'),
          _pdfRow('Reste à payer', '${remaining.toStringAsFixed(0)} DA'),
          if (estimatedDate.isNotEmpty) _pdfRow('Délai estimé', estimatedDate),
          pw.SizedBox(height: 16),
          pw.Center(child: pw.BarcodeWidget(data: qrData, barcode: pw.Barcode.qrCode(), width: 150, height: 150)),
          pw.SizedBox(height: 12),
          pw.Center(child: pw.Text('⚠ Nous ne sommes pas responsables des données\npersonnelles présentes sur l\'appareil.', style: pw.TextStyle(fontSize: 8), textAlign: pw.TextAlign.center)),
          pw.SizedBox(height: 20),
          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text('Signature client :', style: pw.TextStyle(fontSize: 10)),
              pw.SizedBox(height: 24),
              pw.Container(width: 150, child: pw.Divider()),
            ]),
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text('Date : __/__/____', style: pw.TextStyle(fontSize: 10)),
            ]),
          ]),
        ],
      ),
    ));
    return pdf;
  }

  static pw.Page _buildStickerPage(Map<String, dynamic> ticket) {
    final clientName = _clientName(ticket);
    final deviceName = ticket['device_name'] ?? '';
    final phone = _clientPhone(ticket);
    final ticketId = (ticket['qr_code_hash']?.toString() ?? '').substring(0, 8);
    final createdAt = (ticket['created_at']?.toString() ?? '').substring(0, 10);
    final qrData = 'https://igxpwxfruasfpvfagbaw.supabase.co/functions/v1/track?qr=${ticket['qr_code_hash'] ?? ''}';

    return pw.Page(
      pageFormat: PdfPageFormat(141.7, 85.0),
      margin: pw.EdgeInsets.all(4),
      build: (_) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          pw.Text('🔧 LAIDANI REPAIR', style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 2),
          pw.Text(clientName, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
          pw.Text('$deviceName${phone.isNotEmpty ? ' — $phone' : ''}', style: pw.TextStyle(fontSize: 6)),
          pw.SizedBox(height: 2),
          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
            pw.BarcodeWidget(data: qrData, barcode: pw.Barcode.qrCode(errorCorrectLevel: pw.BarcodeQRCorrectionLevel.low), width: 70, height: 70),
            pw.SizedBox(width: 4),
            pw.Expanded(child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text('N° #$ticketId', style: pw.TextStyle(fontSize: 5, font: pw.Font.courier())),
              pw.Text('Date: $createdAt', style: pw.TextStyle(fontSize: 5)),
              pw.SizedBox(height: 4),
              pw.Text('⚠ Conserver ce ticket pour le suivi.', style: pw.TextStyle(fontSize: 5)),
            ])),
          ]),
        ],
      ),
    );
  }

  static Future<void> _printAndLog(pw.Document pdf, Map<String, dynamic> ticket, String column, {BuildContext? context}) async {
    try {
      if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        await Printing.layoutPdf(onLayout: (_) => pdf.save());
      } else {
        final ticketId = (ticket['qr_code_hash']?.toString() ?? '').substring(0, 8);
        await Printing.sharePdf(bytes: await pdf.save(), filename: 'depot_$ticketId.pdf');
      }
      await _logPrint(ticket, column);
    } catch (e) {
      if (context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur impression: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  static Future<void> _logPrint(Map<String, dynamic> ticket, String column) async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      await Supabase.instance.client.from('repair_tickets').update({
        column: DateTime.now().toIso8601String(),
        'last_printed_by': user?.id,
      }).eq('id', ticket['id']);
    } catch (_) {}
  }

  static String formatPrintHistory(Map<String, dynamic>? ticket) {
    if (ticket == null) return 'Aucune impression';
    final parts = <String>[];
    final customerPrinted = ticket['customer_ticket_printed_at'] as String?;
    final labelPrinted = ticket['device_label_printed_at'] as String?;
    if (customerPrinted != null) {
      final dt = DateTime.tryParse(customerPrinted);
      parts.add('Bon client: ${dt != null ? '${dt.day}/${dt.month}/${dt.year} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}' : customerPrinted.substring(0, 16)}');
    }
    if (labelPrinted != null) {
      final dt = DateTime.tryParse(labelPrinted);
      parts.add('Étiquette: ${dt != null ? '${dt.day}/${dt.month}/${dt.year} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}' : labelPrinted.substring(0, 16)}');
    }
    return parts.isEmpty ? 'Aucune impression' : parts.join('\n');
  }

  static String _clientName(Map<String, dynamic> ticket) {
    final isAnon = ticket['customer_id'] == null;
    return isAnon ? (ticket['client_name_temp'] as String? ?? 'Client Anonyme') : 'Client';
  }

  static String _clientPhone(Map<String, dynamic> ticket) {
    final isAnon = ticket['customer_id'] == null;
    return isAnon ? (ticket['client_phone_temp'] as String? ?? '') : '';
  }

  static pw.Widget _pdfRow(String label, String value) {
    return pw.Padding(
      padding: pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: pw.TextStyle(fontSize: 10)),
          pw.Text(value, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
        ],
      ),
    );
  }
}
