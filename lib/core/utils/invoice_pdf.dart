import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

Future<Uint8List> generateInvoicePdf(Map<String, dynamic> ticket, List<Map<String, dynamic>> parts) async {
  final pdf = pw.Document();

  final customerName = ticket['customers']?['full_name'] ?? ticket['client_name_temp'] ?? 'Client';
  final customerPhone = ticket['customers']?['phone_number'] ?? ticket['client_phone_temp'] ?? '';
  final device = ticket['device_name'] ?? '';
  final issue = ticket['issue_description'] ?? '';
  final estimated = (ticket['estimated_cost'] as num?)?.toDouble() ?? 0;
  final finalCost = (ticket['final_cost'] as num?)?.toDouble() ?? estimated;
  final paid = (ticket['paid_amount'] as num?)?.toDouble() ?? 0;
  final advance = (ticket['advance_payment'] as num?)?.toDouble() ?? 0;
  final balance = finalCost - advance - paid;
  final qrHash = ticket['qr_code_hash'] ?? '';
  final warrantyDays = ticket['warranty_days'] ?? 0;
  final createdAt = DateTime.tryParse(ticket['created_at'] ?? '')?.toString().substring(0, 10) ?? '';
  final status = ticket['status'] ?? '';

  final billingType = ticket['billing_type'] as String? ?? 'parts_and_labor';

  final partsTotal = parts.fold<double>(0, (sum, p) => sum + ((p['charged_price'] as num?)?.toDouble() ?? 0) * ((p['quantity'] as num?)?.toInt() ?? 1));

  final billingLabel = {
    'labor_only':      'Main d\'œuvre uniquement',
    'parts_only':      'Pièces uniquement',
    'parts_and_labor': 'Pièces + Main d\'œuvre',
  }[billingType] ?? 'Pièces + Main d\'œuvre';

  pdf.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      build: (ctx) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Header(level: 0, text: 'LaidaniRepair - Facture Réparation'),
          pw.SizedBox(height: 20),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Text('Client: $customerName'),
                pw.Text('Tél: $customerPhone'),
                pw.Text('Date: $createdAt'),
                pw.Text('Statut: $status'),
              ]),
              pw.BarcodeWidget(data: 'LAIDANI:TICKET:${ticket['id']}:$qrHash', barcode: pw.Barcode.qrCode(), width: 80, height: 80),
            ],
          ),
          pw.SizedBox(height: 20),
          pw.Divider(),
          pw.Header(level: 1, text: 'Appareil & Diagnostic'),
          pw.Text('Appareil: $device'),
          pw.Text('Problème: $issue'),
          pw.Text('Type de facturation: $billingLabel'),
          pw.SizedBox(height: 20),
          pw.Divider(),
          if (billingType != 'labor_only') ...[
            pw.Header(level: 1, text: 'Pièces utilisées'),
            if (parts.isEmpty)
              pw.Text('Aucune pièce')
            else
              pw.TableHelper.fromTextArray(
                headers: ['Pièce', 'Qté', 'Prix unitaire', 'Total'],
                data: parts.map((p) => [
                  p['products']?['product_name'] ?? 'Pièce',
                  '${p['quantity']}',
                  '${(p['charged_price'] as num?)?.toDouble() ?? 0} DA',
                  '${((p['charged_price'] as num?)?.toDouble() ?? 0) * ((p['quantity'] as num?)?.toInt() ?? 1)} DA',
                ]).toList(),
              ),
            pw.SizedBox(height: 20),
            pw.Divider(),
          ],
          pw.Header(level: 1, text: 'Résumé financier'),
          if (billingType != 'labor_only')
            pw.Text('Total pièces: ${partsTotal.toStringAsFixed(0)} DA'),
          if (billingType != 'parts_only')
            pw.Text('Main d\'œuvre: ${(ticket['labor_cost'] as num?)?.toDouble() ?? 0} DA'),
          pw.Text('Total facture: ${finalCost.toStringAsFixed(0)} DA'),
          pw.Text('Déjà payé: ${paid.toStringAsFixed(0)} DA'),
          pw.Text('Reste à payer: ${balance.toStringAsFixed(0)} DA',
              style: pw.TextStyle(color: balance > 0 ? PdfColors.red : PdfColors.green, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 20),
          pw.Divider(),
          if (warrantyDays > 0) ...[
            pw.Header(level: 2, text: 'Garantie'),
            pw.Text('$warrantyDays jours à compter de la date de livraison.'),
            pw.SizedBox(height: 10),
          ],
          pw.Center(child: pw.Text('Merci de votre confiance - LaidaniRepair', style: const pw.TextStyle(color: PdfColors.grey))),
        ],
      ),
    ),
  );

  return pdf.save();
}

Future<void> previewOrPrintPdf(Map<String, dynamic> ticket, List<Map<String, dynamic>> parts) async {
  final pdfData = await generateInvoicePdf(ticket, parts);
  await Printing.sharePdf(bytes: pdfData, filename: 'facture_reparation_${ticket['id']}.pdf');
}
