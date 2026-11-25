import 'package:flutter/material.dart';
import 'package:munim_mobile/models/invoice.dart';
import 'package:munim_mobile/services/config_service.dart';
import 'package:munim_mobile/services/export_service.dart';
import 'package:munim_mobile/theme.dart';

class InvoiceDetailScreen extends StatelessWidget {
  final Invoice invoice;
  final AppConfig config;

  const InvoiceDetailScreen({
    super.key,
    required this.invoice,
    required this.config,
  });

  Future<void> _sharePdf(BuildContext context) async {
    try {
      await ExportService.shareInvoicePdf(invoice, config.company);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not create PDF: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final inv = invoice;
    final company = config.company;
    return Scaffold(
      appBar: AppBar(
        title: Text(inv.invNo),
        actions: [
          IconButton(
            tooltip: 'Share invoice PDF',
            icon: const Icon(Icons.picture_as_pdf_outlined),
            onPressed: () => _sharePdf(context),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [MunimTheme.navy, MunimTheme.navyHover],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(company.name, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                if (company.address.trim().isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Text(company.address, style: TextStyle(color: Colors.white.withOpacity(.78), fontSize: 12)),
                ],
                const SizedBox(height: 18),
                Text('INVOICE ${inv.invNo}', style: TextStyle(color: Colors.white.withOpacity(.75), fontSize: 12, letterSpacing: 1)),
                const SizedBox(height: 5),
                Text('₹${ExportService.inr(inv.grandTotal)}',
                  style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
                const SizedBox(height: 5),
                Text(ExportService.fmtDate(inv.date), style: TextStyle(color: Colors.white.withOpacity(.78), fontSize: 13)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _section('BILL TO', [
            _detailRow('Party', inv.party),
            if (inv.customerName.trim().isNotEmpty) _detailRow('Contact name', inv.customerName),
            if (inv.partyAddress.trim().isNotEmpty) _detailRow('Address', inv.partyAddress),
            if (inv.partyPhone.trim().isNotEmpty) _detailRow('Phone', inv.partyPhone),
            if (inv.partyGstin.trim().isNotEmpty) _detailRow('GSTIN', inv.partyGstin),
          ]),
          const SizedBox(height: 16),
          _section('ITEMS', [
            ...inv.items.map((item) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(child: Text(item.name, style: const TextStyle(fontWeight: FontWeight.w600, color: MunimTheme.text))),
                    const SizedBox(width: 12),
                    Text('₹${ExportService.inr(item.total)}', style: const TextStyle(fontWeight: FontWeight.bold, color: MunimTheme.text)),
                  ]),
                  const SizedBox(height: 4),
                  Text('${item.qty % 1 == 0 ? item.qty.toInt() : item.qty} × ₹${ExportService.inr(item.rate)}  •  GST ${item.gstRate}%',
                    style: const TextStyle(fontSize: 12, color: MunimTheme.muted)),
                  if (item.hsn.trim().isNotEmpty)
                    Text('HSN: ${item.hsn}', style: const TextStyle(fontSize: 11, color: MunimTheme.muted)),
                ],
              ),
            )),
          ]),
          const SizedBox(height: 16),
          _section('TAX SUMMARY', [
            _detailRow('Taxable value', '₹${ExportService.inr(inv.taxable)}'),
            if (inv.interstate)
              _detailRow('IGST', '₹${ExportService.inr(inv.igst)}')
            else ...[
              _detailRow('CGST', '₹${ExportService.inr(inv.cgst)}'),
              _detailRow('SGST', '₹${ExportService.inr(inv.sgst)}'),
            ],
            const Divider(height: 20),
            _detailRow('Invoice total', '₹${ExportService.inr(inv.grandTotal)}', bold: true),
          ]),
          const SizedBox(height: 18),
          ElevatedButton.icon(
            onPressed: () => _sharePdf(context),
            icon: const Icon(Icons.share_outlined),
            label: const Text('Share invoice PDF'),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _section(String title, List<Widget> children) => Container(
    padding: const EdgeInsets.all(16),
    decoration: MunimTheme.cardBox(),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1, color: MunimTheme.muted)),
      const SizedBox(height: 10),
      ...children,
    ]),
  );

  Widget _detailRow(String label, String value, {bool bold = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Expanded(child: Text(label, style: const TextStyle(fontSize: 13, color: MunimTheme.muted))),
      const SizedBox(width: 12),
      Flexible(child: Text(value, textAlign: TextAlign.end, style: TextStyle(fontSize: 13, color: MunimTheme.text, fontWeight: bold ? FontWeight.bold : FontWeight.w500))),
    ]),
  );
}
