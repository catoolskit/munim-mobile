import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import 'package:munim_mobile/models/invoice.dart';
import 'package:munim_mobile/models/company.dart';

class ExportService {
  // Export all invoices to a JSON file and share it
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
      const JsonEncoder.withIndent('  ').convert(payload),
    );

    return file.path;
  }

  // Share the exported JSON file via WhatsApp / email / any app
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

  // Format amount as Indian rupees
  static String inr(double amount) {
    final formatter = NumberFormat('#,##,##,###.##', 'en_IN');
    return formatter.format(amount);
  }

  // Format date as DD-MM-YYYY
  static String fmtDate(String isoDate) {
    try {
      final d = DateTime.parse(isoDate);
      return DateFormat('dd-MM-yyyy').format(d);
    } catch (_) {
      return isoDate;
    }
  }
}
