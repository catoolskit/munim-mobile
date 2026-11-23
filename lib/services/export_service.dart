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
    final fileName =
        'munim_invoices_${companySlug}_$dateStr.json';
    final payload = {
      'munim_version': 'v0.18',
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

    // ── v0.18: GST registered flag ────────────────────────
    final bool gstRegistered = company.gstRegistered;
    final String invoiceHeading =
        gstRegistered ? 'TAX INVOICE' : 'RETAIL INVOICE';

    // Build HSN summary (only needed for registered)
    final Map<String, _HsnRow> hsnMap = {};
    if (gstRegistered) {
      for (final it in inv.items) {
        final key = it.hsn.isNotEmpty ? it.hsn : 'NA';
        if (!hsnMap.containsKey(key)) {
          hsnMap[key] = _HsnRow(
            hsn: key,
            gstRate: it.gstRate,
            taxable: 0,
            qty: 0,
          );
        }
        hsnMap[key]!.taxable += it.amount;
        hsnMap[key]!.qty += it.qty;
      }
    }
    final hsnRows = hsnMap.values.toList();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // ── Title bar ─────────────────────────────
              pw.Container(
                width: double.infinity,
                padding:
                    const pw.EdgeInsets.symmetric(vertical: 6),
                decoration: const pw.BoxDecoration(
                    border: pw.Border(
                        bottom: pw.BorderSide(width: 1.5))),
                child: pw.Center(
                  child: pw.Text(
                    invoiceHeading,
                    style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                        letterSpacing: 2)),
                ),
              ),
              pw.SizedBox(height: 10),

              // ── Seller + Invoice details ───────────────
              pw.Row(
                crossAxisAlignment:
                    pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment:
                          pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('SELLER',
                            style: pw.TextStyle(
                                fontSize: 8,
                                color: PdfColors.grey600,
                                fontWeight:
                                    pw.FontWeight.bold)),
                        pw.SizedBox(height: 3),
                        pw.Text(company.name,
                            style: pw.TextStyle(
                                fontSize: 13,
                                fontWeight:
                                    pw.FontWeight.bold)),
                        if (company.address.isNotEmpty)
                          pw.Text(company.address,
                              style: const pw.TextStyle(
                                  fontSize: 9)),
                        // Only show GSTIN if registered
                        if (gstRegistered &&
                            company.gstin.isNotEmpty)
                          pw.Text(
                              'GSTIN: ${company.gstin}',
                              style: const pw.TextStyle(
                                  fontSize: 9)),
                        if (company.phone.isNotEmpty)
                          pw.Text(
                              'Ph: ${company.phone}',
                              style: const pw.TextStyle(
                                  fontSize: 9)),
                      ],
                    ),
                  ),
                  pw.SizedBox(width: 20),
                  pw.Column(
                    crossAxisAlignment:
                        pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('Invoice No.',
                          style: pw.TextStyle(
                              fontSize: 8,
                              color: PdfColors.grey600)),
                      pw.Text(inv.invNo,
                          style: pw.TextStyle(
                              fontSize: 13,
                              fontWeight:
                                  pw.FontWeight.bold)),
                      pw.SizedBox(height: 4),
                      pw.Text('Date',
                          style: pw.TextStyle(
                              fontSize: 8,
                              color: PdfColors.grey600)),
                      pw.Text(fmtDate(inv.date),
                          style: const pw.TextStyle(
                              fontSize: 10)),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 10),
              pw.Divider(thickness: 0.5),
              pw.SizedBox(height: 6),

              // ── Buyer ─────────────────────────────────
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                    border: pw.Border.all(
                        color: PdfColors.grey400,
                        width: 0.5)),
                child: pw.Column(
                  crossAxisAlignment:
                      pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('BILL TO',
                        style: pw.TextStyle(
                            fontSize: 8,
                            color: PdfColors.grey600,
                            fontWeight:
                                pw.FontWeight.bold)),
                    pw.SizedBox(height: 4),
                    pw.Text(inv.party,
                        style: pw.TextStyle(
                            fontSize: 14,
                            fontWeight:
                                pw.FontWeight.bold)),
                    // Only show buyer GSTIN if registered
                    if (gstRegistered &&
                        inv.partyGstin.isNotEmpty)
                      pw.Text(
                          'GSTIN: ${inv.partyGstin}',
                          style: const pw.TextStyle(
                              fontSize: 10)),
                    if (inv.partyPhone.isNotEmpty)
                      pw.Text(
                          'Ph: ${inv.partyPhone}',
                          style: const pw.TextStyle(
                              fontSize: 10)),
                    if (inv.partyAddress.isNotEmpty)
                      pw.Text(inv.partyAddress,
                          style: const pw.TextStyle(
                              fontSize: 10)),
                  ],
                ),
              ),
              pw.SizedBox(height: 6),
              pw.Divider(thickness: 0.5),
              pw.SizedBox(height: 6),

              // ── Items table ───────────────────────────
              // Columns differ: registered shows HSN + GST%,
              // unregistered shows simpler table
              if (gstRegistered)
                pw.Table(
                  border: pw.TableBorder.all(
                      color: PdfColors.grey400,
                      width: 0.5),
                  columnWidths: {
                    0: const pw.FixedColumnWidth(24),
                    1: const pw.FixedColumnWidth(52),
                    2: const pw.FlexColumnWidth(3),
                    3: const pw.FixedColumnWidth(36),
                    4: const pw.FixedColumnWidth(72),
                    5: const pw.FixedColumnWidth(36),
                    6: const pw.FixedColumnWidth(72),
                  },
                  children: [
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(
                          color: PdfColors.grey200),
                      children: [
                        _th('#'),
                        _th('HSN'),
                        _th('Description'),
                        _th('Qty', center: true),
                        _th('Rate/Unit', right: true),
                        _th('GST%', center: true),
                        _th('Amount', right: true),
                      ],
                    ),
                    ...inv.items.asMap().entries.map(
                      (e) => pw.TableRow(children: [
                        _td('${e.key + 1}',
                            center: true),
                        _td(e.value.hsn),
                        _td(e.value.name),
                        _td(
                            e.value.qty % 1 == 0
                                ? e.value.qty
                                    .toInt()
                                    .toString()
                                : e.value.qty.toString(),
                            center: true),
                        _td(inr(e.value.rate),
                            right: true),
                        _td('${e.value.gstRate}%',
                            center: true),
                        _td(inr(e.value.amount),
                            right: true),
                      ]),
                    ),
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(
                          color: PdfColors.grey100),
                      children: [
                        _td('', span: true),
                        _td('', span: true),
                        _td('Total',
                            bold: true, span: true),
                        _td('', span: true),
                        _td('', span: true),
                        _td('', span: true),
                        _td(inr(inv.taxable),
                            right: true, bold: true),
                      ],
                    ),
                  ],
                )
              else
                // Unregistered: simpler table, no HSN/GST columns
                pw.Table(
                  border: pw.TableBorder.all(
                      color: PdfColors.grey400,
                      width: 0.5),
                  columnWidths: {
                    0: const pw.FixedColumnWidth(24),
                    1: const pw.FlexColumnWidth(3),
                    2: const pw.FixedColumnWidth(40),
                    3: const pw.FixedColumnWidth(80),
                    4: const pw.FixedColumnWidth(80),
                  },
                  children: [
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(
                          color: PdfColors.grey200),
                      children: [
                        _th('#'),
                        _th('Description'),
                        _th('Qty', center: true),
                        _th('Rate/Unit', right: true),
                        _th('Amount', right: true),
                      ],
                    ),
                    ...inv.items.asMap().entries.map(
                      (e) => pw.TableRow(children: [
                        _td('${e.key + 1}',
                            center: true),
                        _td(e.value.name),
                        _td(
                            e.value.qty % 1 == 0
                                ? e.value.qty
                                    .toInt()
                                    .toString()
                                : e.value.qty.toString(),
                            center: true),
                        _td(inr(e.value.rate),
                            right: true),
                        _td(inr(e.value.amount),
                            right: true),
                      ]),
                    ),
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(
                          color: PdfColors.grey100),
                      children: [
                        _td('', span: true),
                        _td('Total',
                            bold: true, span: true),
                        _td('', span: true),
                        _td('', span: true),
                        _td(inr(inv.taxable),
                            right: true, bold: true),
                      ],
                    ),
                  ],
                ),
              pw.SizedBox(height: 12),

              // ── HSN Summary (registered only) ─────────
              if (gstRegistered && hsnRows.isNotEmpty) ...[
                pw.Text('HSN/SAC Summary',
                    style: pw.TextStyle(
                        fontSize: 9,
                        fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 4),
                pw.Table(
                  border: pw.TableBorder.all(
                      color: PdfColors.grey400,
                      width: 0.5),
                  columnWidths: {
                    0: const pw.FlexColumnWidth(1.2),
                    1: const pw.FlexColumnWidth(1.5),
                    2: const pw.FlexColumnWidth(0.8),
                    3: const pw.FlexColumnWidth(0.8),
                    4: const pw.FlexColumnWidth(1.2),
                    5: const pw.FlexColumnWidth(0.8),
                    6: const pw.FlexColumnWidth(1.2),
                    7: const pw.FlexColumnWidth(1.2),
                  },
                  children: [
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(
                          color: PdfColors.grey200),
                      children: [
                        _th('HSN/SAC'),
                        _th('Taxable Amt', right: true),
                        _th('Qty', center: true),
                        _th('CGST%', center: true),
                        _th('CGST Amt', right: true),
                        _th('SGST%', center: true),
                        _th('SGST Amt', right: true),
                        _th('Total Tax', right: true),
                      ],
                    ),
                    ...hsnRows.map((h) {
                      final halfRate = h.gstRate / 2;
                      final cgst = inv.interstate
                          ? 0.0
                          : h.taxable * halfRate / 100;
                      final sgst = inv.interstate
                          ? 0.0
                          : h.taxable * halfRate / 100;
                      final igst = inv.interstate
                          ? h.taxable * h.gstRate / 100
                          : 0.0;
                      final totalTax = inv.interstate
                          ? igst
                          : cgst + sgst;
                      return pw.TableRow(children: [
                        _td(h.hsn),
                        _td(inr(h.taxable), right: true),
                        _td(
                            h.qty % 1 == 0
                                ? h.qty
                                    .toInt()
                                    .toString()
                                : h.qty.toString(),
                            center: true),
                        _td(
                            inv.interstate
                                ? '-'
                                : '${halfRate}%',
                            center: true),
                        _td(
                            inv.interstate
                                ? '-'
                                : inr(cgst),
                            right: true),
                        _td(
                            inv.interstate
                                ? '-'
                                : '${halfRate}%',
                            center: true),
                        _td(
                            inv.interstate
                                ? '-'
                                : inr(sgst),
                            right: true),
                        _td(inr(totalTax),
                            right: true, bold: true),
                      ]);
                    }),
                  ],
                ),
                pw.SizedBox(height: 12),
              ],

              // ── Tax summary + Grand total ──────────────
              pw.Row(
                crossAxisAlignment:
                    pw.CrossAxisAlignment.start,
                children: [
                  pw.Spacer(),
                  pw.SizedBox(
                    width: 220,
                    child: pw.Table(
                      border: pw.TableBorder.all(
                          color: PdfColors.grey300,
                          width: 0.5),
                      children: [
                        // Show GST breakdown only if registered
                        if (gstRegistered) ...[
                          if (!inv.interstate) ...[
                            _summaryRow(
                                'CGST', inr(inv.cgst)),
                            _summaryRow(
                                'SGST', inr(inv.sgst)),
                          ] else
                            _summaryRow(
                                'IGST', inr(inv.igst)),
                          _summaryRow('Taxable Amount',
                              inr(inv.taxable)),
                        ],
                        pw.TableRow(
                          decoration:
                              const pw.BoxDecoration(
                                  color:
                                      PdfColors.grey100),
                          children: [
                            pw.Padding(
                              padding:
                                  const pw.EdgeInsets
                                      .all(5),
                              child: pw.Text(
                                  'GRAND TOTAL',
                                  style: pw.TextStyle(
                                      fontSize: 10,
                                      fontWeight:
                                          pw.FontWeight
                                              .bold)),
                            ),
                            pw.Padding(
                              padding:
                                  const pw.EdgeInsets
                                      .all(5),
                              child: pw.Text(
                                  inr(inv.grandTotal),
                                  textAlign:
                                      pw.TextAlign.right,
                                  style: pw.TextStyle(
                                      fontSize: 10,
                                      fontWeight:
                                          pw.FontWeight
                                              .bold)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              pw.Spacer(),

              // ── Footer ────────────────────────────────
              pw.Divider(thickness: 0.5),
              pw.Row(
                mainAxisAlignment:
                    pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    gstRegistered
                        ? 'This is a computer generated invoice.'
                        : 'Not registered under GST — tax not collected on this invoice.',
                    style: pw.TextStyle(
                        fontSize: 8,
                        color: PdfColors.grey600,
                        fontStyle: pw.FontStyle.italic)),
                  pw.Text(
                    'For ${company.name}',
                    style: const pw.TextStyle(
                        fontSize: 8,
                        color: PdfColors.grey600)),
                ],
              ),
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
    final xFile =
        XFile(path, mimeType: 'application/pdf');
    await Share.shareXFiles(
      [xFile],
      subject:
          'Invoice ${inv.invNo} — ${company.name}',
      text: 'Please find your invoice attached.',
    );
  }

  // ── Helpers ───────────────────────────────────────────────
  static String inr(double amount) {
    final formatter =
        NumberFormat('#,##,##,###.##', 'en_IN');
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

  static pw.Widget _th(String text,
      {bool right = false, bool center = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(5),
      child: pw.Text(text,
          textAlign: right
              ? pw.TextAlign.right
              : center
                  ? pw.TextAlign.center
                  : pw.TextAlign.left,
          style: pw.TextStyle(
              fontSize: 8,
              fontWeight: pw.FontWeight.bold)),
    );
  }

  static pw.Widget _td(String text,
      {bool right = false,
      bool center = false,
      bool bold = false,
      bool span = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(5),
      child: pw.Text(text,
          textAlign: right
              ? pw.TextAlign.right
              : center
                  ? pw.TextAlign.center
                  : pw.TextAlign.left,
          style: pw.TextStyle(
              fontSize: 9,
              fontWeight: bold
                  ? pw.FontWeight.bold
                  : pw.FontWeight.normal)),
    );
  }

  static pw.TableRow _summaryRow(
      String label, String value) {
    return pw.TableRow(children: [
      pw.Padding(
          padding: const pw.EdgeInsets.all(5),
          child: pw.Text(label,
              style:
                  const pw.TextStyle(fontSize: 9))),
      pw.Padding(
          padding: const pw.EdgeInsets.all(5),
          child: pw.Text(value,
              textAlign: pw.TextAlign.right,
              style:
                  const pw.TextStyle(fontSize: 9))),
    ]);
  }
}

class _HsnRow {
  final String hsn;
  final double gstRate;
  double taxable;
  double qty;

  _HsnRow({
    required this.hsn,
    required this.gstRate,
    required this.taxable,
    required this.qty,
  });
}
