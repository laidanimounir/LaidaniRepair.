import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

Future<Uint8List> generateQuotePdf(Map<String, dynamic> ticket, List<Map<String, dynamic>> parts) async {
  final pdf = pw.Document();

  final customerName = ticket['customers']?['full_name'] ?? ticket['client_name_temp'] ?? 'Client';
  final customerPhone = ticket['customers']?['phone_number'] ?? ticket['client_phone_temp'] ?? '';
  final device = ticket['device_name'] ?? '';
  final issue = ticket['issue_description'] ?? ticket['pre_diagnostic'] ?? '';
  final estimatedCost = (ticket['estimated_cost'] as num?)?.toDouble() ?? 0;
  final laborCost = (ticket['labor_cost'] as num?)?.toDouble() ?? 0;
  final createdAt = DateTime.tryParse(ticket['created_at'] ?? '')?.toString().substring(0, 10) ?? '';
  final validityDate = DateTime.now().add(const Duration(days: 15)).toString().substring(0, 10);

  final partsTotal = parts.fold<double>(0, (sum, p) => sum + ((p['charged_price'] as num?)?.toDouble() ?? 0) * ((p['quantity'] as num?)?.toInt() ?? 1));
  final totalEstimate = partsTotal + laborCost;

  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(40),
      header: (ctx) => pw.Container(
        padding: const pw.EdgeInsets.only(bottom: 10),
        decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.blue800, width: 2))),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('LaidaniRepair', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                pw.Text('Expert en réparation mobile', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey)),
              ],
            ),
            pw.Text('DEVIS N° ${ticket['id'] ?? ''}', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.blue700)),
          ],
        ),
      ),
      footer: (ctx) => pw.Container(
        alignment: pw.Alignment.center,
        padding: const pw.EdgeInsets.only(top: 10),
        decoration: const pw.BoxDecoration(border: pw.Border(top: pw.BorderSide(color: PdfColors.grey300))),
        child: pw.Column(
          children: [
            pw.Text('LaidaniRepair - Devis valable 15 jours - Page ${ctx.pageNumber}/${ctx.pagesCount}',
                style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey)),
            pw.Text('Tél: +213 555 000 000 - Email: contact@laidani.dz',
                style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey)),
          ],
        ),
      ),
      build: (ctx) => [
        pw.Container(
          padding: const pw.EdgeInsets.all(16),
          decoration: pw.BoxDecoration(
            color: PdfColors.blue50,
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Text('CLIENT', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
                pw.SizedBox(height: 4),
                pw.Text(customerName, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                pw.Text('Tél: $customerPhone', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey)),
              ]),
              pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Text('INFORMATIONS', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
                pw.SizedBox(height: 4),
                pw.Text('Date: $createdAt', style: const pw.TextStyle(fontSize: 10)),
                pw.Text('Valable jusqu\'au: $validityDate', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.red)),
              ]),
            ],
          ),
        ),
        pw.SizedBox(height: 16),
        pw.Container(
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey300)),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('APPAREIL CONCERNÉ', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
              pw.SizedBox(height: 4),
              pw.Text('Modèle: $device', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
              if (ticket['imei'] != null) pw.Text('IMEI/SN: ${ticket['imei']}', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey)),
            ],
          ),
        ),
        pw.SizedBox(height: 12),
        pw.Text('DIAGNOSTIC', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
        pw.SizedBox(height: 4),
        pw.Container(
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(color: PdfColors.grey100, borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4))),
          child: pw.Text(issue.isNotEmpty ? issue : 'À diagnostiquer', style: const pw.TextStyle(fontSize: 11)),
        ),
        pw.SizedBox(height: 16),
        pw.Text('DÉTAIL DE L\'ESTIMATION', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
        pw.SizedBox(height: 8),
        if (parts.isNotEmpty) ...[
          pw.TableHelper.fromTextArray(
            headerStyle: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.blue700),
            cellStyle: const pw.TextStyle(fontSize: 10),
            cellAlignments: {0: pw.Alignment.centerLeft, 1: pw.Alignment.center, 2: pw.Alignment.centerRight, 3: pw.Alignment.centerRight},
            headers: ['Pièce', 'Qté', 'Prix Unitaire', 'Total'],
            data: parts.map((p) => [
              p['products']?['product_name'] ?? 'Pièce',
              '${p['quantity'] ?? 1}',
              '${(p['charged_price'] as num?)?.toDouble() ?? 0} DA',
              '${((p['charged_price'] as num?)?.toDouble() ?? 0) * ((p['quantity'] as num?)?.toInt() ?? 1)} DA',
            ]).toList(),
          ),
          pw.SizedBox(height: 4),
        ],
        pw.Container(
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey300)),
          child: pw.Column(
            children: [
              if (parts.isNotEmpty) pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                pw.Text('Sous-total pièces:', style: const pw.TextStyle(fontSize: 11)),
                pw.Text('${partsTotal.toStringAsFixed(0)} DA', style: const pw.TextStyle(fontSize: 11)),
              ]),
              if (laborCost > 0) pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                pw.Text('Main d\'œuvre:', style: const pw.TextStyle(fontSize: 11)),
                pw.Text('${laborCost.toStringAsFixed(0)} DA', style: const pw.TextStyle(fontSize: 11)),
              ]),
              pw.SizedBox(height: 4),
              pw.Divider(),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('TOTAL ESTIMÉ', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                  pw.Text('${(estimatedCost > 0 ? estimatedCost : totalEstimate).toStringAsFixed(0)} DA',
                      style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.blue700)),
                ],
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 24),
        pw.Text('CONDITIONS', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
        pw.SizedBox(height: 4),
        pw.Container(
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(color: PdfColors.grey100, borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4))),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('1. Ce devis est valable 15 jours à compter de sa date d\'émission.', style: const pw.TextStyle(fontSize: 9)),
              pw.Text('2. Les prix sont indiqués en Dinars Algériens (DA), TVA non applicable.', style: const pw.TextStyle(fontSize: 9)),
              pw.Text('3. Un acompte de 30% peut être demandé avant le début des travaux.', style: const pw.TextStyle(fontSize: 9)),
              pw.Text('4. Toute pièce remplacée devient propriété du client après paiement intégral.', style: const pw.TextStyle(fontSize: 9)),
              pw.Text('5. La garantie est de 3 mois sur les pièces et la main d\'œuvre (sauf dommage physique).', style: const pw.TextStyle(fontSize: 9)),
              pw.Text('6. Le client accepte les diagnostics et estimations ci-dessus.', style: const pw.TextStyle(fontSize: 9)),
            ],
          ),
        ),
        pw.SizedBox(height: 24),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text('Signature du Client', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 30),
            ]),
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
              pw.Text('LaidaniRepair', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 30),
            ]),
          ],
        ),
      ],
    ),
  );

  return pdf.save();
}

Future<void> previewOrPrintQuotePdf(Map<String, dynamic> ticket, List<Map<String, dynamic>> parts) async {
  final pdfData = await generateQuotePdf(ticket, parts);
  await Printing.sharePdf(bytes: pdfData, filename: 'devis_${ticket['id']}.pdf');
}
