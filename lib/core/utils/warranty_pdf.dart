import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

Future<Uint8List> generateWarrantyPdf(Map<String, dynamic> ticket, List<Map<String, dynamic>> parts) async {
  final pdf = pw.Document();

  final customerName = ticket['customers']?['full_name'] ?? ticket['client_name_temp'] ?? 'Client';
  final customerPhone = ticket['customers']?['phone_number'] ?? ticket['client_phone_temp'] ?? '';
  final device = ticket['device_name'] ?? '';
  final issue = ticket['issue_description'] ?? ticket['pre_diagnostic'] ?? '';
  final warrantyDays = (ticket['warranty_days'] as num?)?.toInt() ?? 0;
  final createdAt = DateTime.tryParse(ticket['created_at'] ?? '')?.toString().substring(0, 10) ?? '';
  final handoverDate = DateTime.now().toString().substring(0, 10);
  final expiryDate = DateTime.now().add(Duration(days: warrantyDays > 0 ? warrantyDays : 180)).toString().substring(0, 10);
  final qrHash = ticket['qr_code_hash'] ?? ticket['id'] ?? '';

  final partsDesc = parts.isEmpty
      ? 'Réparation générale'
      : parts.map((p) => '${p['products']?['product_name'] ?? 'Pièce'} (x${p['quantity'] ?? 1})').join(', ');

  pdf.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(50),
      build: (ctx) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Header(level: 0, text: 'CERTIFICAT DE GARANTIE', textStyle: pw.TextStyle(color: PdfColors.blue900, fontSize: 28, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 4),
            pw.Text('LaidaniRepair - Expert en réparation mobile', style: pw.TextStyle(color: PdfColors.blue700, fontSize: 12)),
            pw.SizedBox(height: 24),
            pw.Divider(color: PdfColors.blue300, thickness: 2),
            pw.SizedBox(height: 24),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                  pw.Text('CLIENT', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.grey)),
                  pw.SizedBox(height: 4),
                  pw.Text(customerName, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                  pw.Text('Tél: $customerPhone', style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey)),
                ]),
                pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
                  pw.Text('N° TICKET', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.grey)),
                  pw.SizedBox(height: 4),
                  pw.Text('${ticket['id'] ?? ''}', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.blue700)),
                ]),
              ],
            ),
            pw.SizedBox(height: 20),
            pw.Container(
              padding: const pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey300),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('DÉTAILS DE L\'APPAREIL', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
                  pw.SizedBox(height: 12),
                  _warrantyRow('Appareil', device),
                  if (ticket['imei'] != null) _warrantyRow('IMEI / SN', ticket['imei'].toString()),
                  _warrantyRow('Date de dépôt', createdAt),
                  _warrantyRow('Date de livraison', handoverDate),
                  pw.SizedBox(height: 8),
                  pw.Text('RÉPARATION EFFECTUÉE', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.blue700)),
                  pw.SizedBox(height: 4),
                  pw.Container(
                    padding: const pw.EdgeInsets.all(10),
                    decoration: pw.BoxDecoration(color: PdfColors.grey100, borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4))),
                    child: pw.Text('$issue\n\nPièces remplacées: $partsDesc', style: const pw.TextStyle(fontSize: 10)),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 20),
            pw.Container(
              padding: const pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                color: PdfColors.blue50,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                border: pw.Border.all(color: PdfColors.blue200),
              ),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.BarcodeWidget(
                    data: qrHash,
                    barcode: pw.Barcode.qrCode(),
                    width: 90,
                    height: 90,
                  ),
                  pw.SizedBox(width: 20),
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('GARANTIE: ${warrantyDays > 0 ? '$warrantyDays jours' : '6 mois'}', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                        pw.SizedBox(height: 8),
                        pw.Text('Valable du $handoverDate au $expiryDate', style: const pw.TextStyle(fontSize: 11)),
                        pw.SizedBox(height: 8),
                        pw.Text('La garantie couvre les pièces remplacées et la main d\'œuvre.\nExclut les dommages physiques, l\'oxydation et les interventions par des tiers.',
                            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 24),
            pw.Text('CONDITIONS DE GARANTIE', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
            pw.SizedBox(height: 8),
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(color: PdfColors.grey100, borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4))),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('1. La garantie couvre les défauts de fabrication des pièces remplacées.', style: const pw.TextStyle(fontSize: 9)),
                  pw.Text('2. La garantie couvre les défauts liés à la main d\'œuvre de réparation.', style: const pw.TextStyle(fontSize: 9)),
                  pw.Text('3. Sont exclus: dommages physiques (chute, choc), oxydation, immersion dans l\'eau.', style: const pw.TextStyle(fontSize: 9)),
                  pw.Text('4. Toute intervention par un tiers annule automatiquement la garantie.', style: const pw.TextStyle(fontSize: 9)),
                  pw.Text('5. Ce certificat doit être présenté pour toute réclamation sous garantie.', style: const pw.TextStyle(fontSize: 9)),
                  pw.Text('6. La garantie ne couvre pas les pertes de données. Sauvegardez vos données.', style: const pw.TextStyle(fontSize: 9)),
                ],
              ),
            ),
            pw.SizedBox(height: 30),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                  pw.Text('Signature du Client', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 40),
                  pw.Text('(Cachet et signature)', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey)),
                ]),
                pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
                  pw.Text('LaidaniRepair', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.blue700)),
                  pw.SizedBox(height: 40),
                  pw.Text('(Cachet du magasin)', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey)),
                ]),
              ],
            ),
          ],
        );
      },
    ),
  );

  return pdf.save();
}

pw.Widget _warrantyRow(String label, String value) {
  return pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 6),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(width: 120, child: pw.Text('$label:', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.grey))),
        pw.Expanded(child: pw.Text(value, style: const pw.TextStyle(fontSize: 10))),
      ],
    ),
  );
}

Future<void> previewOrPrintWarrantyPdf(Map<String, dynamic> ticket, List<Map<String, dynamic>> parts) async {
  final pdfData = await generateWarrantyPdf(ticket, parts);
  await Printing.sharePdf(bytes: pdfData, filename: 'garantie_${ticket['id']}.pdf');
}
