import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:munim_mobile/models/invoice.dart';
import 'package:munim_mobile/models/company.dart';

class ExportService {
  // ── JSON export ───────────────────────────────────────────
  static Future<String> exportInvoices(
      List<Invoice> invoices, Company company) async {
    final now = DateTime.now();
    final dateStr = DateFormat('yyyyMMdd_HHmm').format(now);
    final companySlug =
        company.name.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
    final fileName = 'munim_invoices_${companySlug}_$dateStr.json';
    final payload = {
      'munim_version': 'v0.17',
      'exported_at': now.toIso8601String(),
      'company_name': company.name,
      'invoice_count': invoices.length,
      'invoices': invoices.map((i) => i.toJson()).toList(),
    };
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$fileName');
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(payload));
    return file.path;
  }

  static Future<void> shareInvoices(
      List<Invoice> invoices, Company company) async {
    final path = await exportInvoices(invoices, company);
    final xFile = XFile(path, mimeType: 'application/json');
    await Share.shareXFiles(
      [xFile],
      subject: 'MUNIM Invoices — ${company.name}',
      text: 'Please find the MUNIM mobile invoices attached.\n'
          'Import this file into MUNIM on your PC via '
          'Utilities → Import Mobile Invoices.',
    );
  }

  // ── PDF generation ────────────────────────────────────────
  static Future<String> generateInvoicePdf(
      Invoice inv, Company company) async {
    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Row(
                mainAxisAlignment:
                    pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment:
                        pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(company.name,
                        style: pw.TextStyle(
                          fontSize: 20,
                          fontWeight: pw.FontWeight.bold)),
                      if (company.address.isNotEmpty)
                        pw.Text(company.address,
                          style: const pw.TextStyle(
                            fontSize: 10)),
                      if (company.gstin.isNotEmpty)
                        pw.Text('GSTIN: ${company.gstin}',
                          style: const pw.TextStyle(
                            fontSize: 10)),
                      if (company.phone.isNotEmpty)
                        pw.Text('Ph: ${company.phone}',
                          style: const pw.TextStyle(
                            fontSize: 10)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment:
                        pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('TAX INVOICE',
                        style: pw.TextStyle(
                          fontSize: 16,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.blue800)),
                      pw.Text('Invoice No: ${inv.invNo}',
                        style: const pw.TextStyle(
                          fontSize: 11)),
                      pw.Text(
                        'Date: ${fmtDate(inv.date)}',
                        style: const pw.TextStyle(
                          fontSize: 11)),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 16),
              pw.Divider(),
              pw.SizedBox(height: 8),

              // Bill To
              pw.Text('Bill To:',
                style: pw.TextStyle(
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 4),
              pw.Text(inv.party,
                style: pw.TextStyle(
                  fontSize: 13,
                  fontWeight: pw.FontWeight.bold)),
              if (inv.partyGstin.isNotEmpty)
                pw.Text('GSTIN: ${inv.partyGstin}',
                  style: const pw.TextStyle(fontSize: 10)),
              if (inv.partyPhone.isNotEmpty)
                pw.Text('Ph: ${inv.partyPhone}',
                  style: const pw.TextStyle(fontSize: 10)),
              pw.SizedBox(height: 20),

              // Items table
              pw.Table(
                border: pw.TableBorder.all(
                  color: PdfColors.grey400, width: 0.5),
                columnWidths: {
                  0: const pw.FlexColumnWidth(3),
                  1: const pw.FlexColumnWidth(1.2),
                  2: const pw.FlexColumnWidth(1.5),
                  3: const pw.FlexColumnWidth(1),
                  4: const pw.FlexColumnWidth(1.5),
                },
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(
                      color: PdfColors.blueGrey100),
                    children: [
                      _cell('Item / HSN', bold: true),
                      _cell('Qty', bold: true, center: true),
                      _cell('Rate (Rs)',
                        bold: true, center: true),
                      _cell('GST%', bold: true, center: true),
                      _cell('Amount (Rs)',
                        bold: true, right: true),
                    ],
                  ),
                  ...inv.items.map((it) => pw.TableRow(
                    children: [
                      _cell(it.hsn.isNotEmpty
                        ? '${it.name}\nHSN: ${it.hsn}'
                        : it.name, small: true),
                      _cell(it.qty % 1 == 0
                        ? it.qty.toInt().toString()
                        : it.qty.toString(),
                        center: true),
                      _cell(inr(it.rate), center: true),
                      _cell('${it.gstRate}%', center: true),
                      _cell(inr(it.amount), right: true),
                    ],
                  )),
                ],
              ),
              pw.SizedBox(height: 16),

              // Totals
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.SizedBox(
                  width: 230,
                  child: pw.Column(children: [
                    _totalRow('Taxable Amount',
                      inr(inv.taxable)),
                    if (!inv.interstate) ...[
                      _totalRow('CGST', inr(inv.cgst)),
                      _totalRow('SGST', inr(inv.sgst)),
                    ] else
                      _totalRow('IGST', inr(inv.igst)),
                    pw.Divider(
                      color: PdfColors.grey400),
                    _totalRow(
                      'Grand Total',
                      'Rs ${inr(inv.grandTotal)}',
                      bold: true),
                  ]),
                ),
              ),
              pw.Spacer(),

              // Footer
              pw.Divider(),
              pw.Text(
                'This is a computer generated invoice.',
                style: pw.TextStyle(
                  fontSize: 9,
                  color: PdfColors.grey600,
                  fontStyle: pw.FontStyle.italic)),
              pw.Text(
                'Generated by MUNIM Mobile · ${company.name}',
                style: const pw.TextStyle(
                  fontSize: 9,
                  color: PdfColors.grey600)),
            ],
          );
        },
      ),
    );

    final dir = await getTemporaryDirectory();
    final fileName =
      'Invoice_${inv.invNo}_${inv.party}.pdf'
        .replaceAll(RegExp(r'[^a-zA-Z0-9_.]'), '_');
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(await pdf.save());
    return file.path;
  }

  static Future<void> shareInvoicePdf(
      Invoice inv, Company company) async {
    final path = await generateInvoicePdf(inv, company);
    final xFile = XFile(path, mimeType: 'application/pdf');
    await Share.shareXFiles(
      [xFile],
      subject: 'Invoice ${inv.invNo} — ${company.name}',
      text: 'Please find your invoice attached.',
    );
  }

  // ── Helpers ───────────────────────────────────────────────
  static String inr(double amount) {
    final formatter = NumberFormat('#,##,##,###.##', 'en_IN');
    return formatter.format(amount);
  }

  static String fmtDate(String isoDate) {
    try {
      final d = DateTime.parse(isoDate);
      return DateFormat('dd-MM-yyyy').format(d);
    } catch (_) {
      return isoDate;
    }
  }

  static pw.Widget _cell(String text,
      {bool bold = false,
      bool center = false,
      bool right = false,
      bool small = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        text,
        textAlign: right
            ? pw.TextAlign.right
            : center
                ? pw.TextAlign.center
                : pw.TextAlign.left,
        style: pw.TextStyle(
          fontSize: small ? 9 : 10,
          fontWeight: bold
              ? pw.FontWeight.bold
              : pw.FontWeight.normal)),
    );
  }

  static pw.Widget _totalRow(String label, String value,
      {bool bold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3),
      child: pw.Row(
        mainAxisAlignment:
            pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label,
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: bold
                  ? pw.FontWeight.bold
                  : pw.FontWeight.normal)),
          pw.Text(value,
            style: pw.TextStyle(
              fontSize: bold ? 11 : 10,
              fontWeight: bold
                  ? pw.FontWeight.bold
                  : pw.FontWeight.normal)),
        ],
      ),
    );
  }
}
