import 'package:flutter/material.dart';
import 'package:munim_mobile/theme.dart';
import 'package:munim_mobile/services/config_service.dart';
import 'package:munim_mobile/services/storage_service.dart';
import 'package:munim_mobile/services/export_service.dart';
import 'package:munim_mobile/models/invoice.dart';

class InvoiceListScreen extends StatefulWidget {
  final AppConfig config;
  final List<Invoice> invoices;

  const InvoiceListScreen({
    super.key,
    required this.config,
    required this.invoices,
  });

  @override
  State<InvoiceListScreen> createState() => _InvoiceListScreenState();
}

class _InvoiceListScreenState extends State<InvoiceListScreen> {
  late List<Invoice> _invoices;

  @override
  void initState() {
    super.initState();
    _invoices = widget.invoices;
  }

  Future<void> _delete(Invoice inv) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Invoice'),
        content: Text(
            'Delete invoice ${inv.invNo} for ${inv.party}?\n\n'
            'This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete',
              style: TextStyle(color: MunimTheme.danger))),
        ],
      ),
    );
    if (ok != true) return;
    final updated = await StorageService.deleteInvoice(inv.mobileId);
    setState(() => _invoices = updated);
  }

  Future<void> _shareAll() async {
    if (_invoices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No invoices to share.')));
      return;
    }
    try {
      await ExportService.shareInvoices(
          _invoices, widget.config.company);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _clearAll() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Clear All Invoices'),
        content: const Text(
          'Remove all invoices from this device?\n\n'
          'Make sure you have already imported them into MUNIM on your PC.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear all',
              style: TextStyle(color: MunimTheme.danger))),
        ],
      ),
    );
    if (ok != true) return;
    await StorageService.clearInvoices();
    setState(() => _invoices = []);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('All invoices cleared.')));
  }

  @override
  Widget build(BuildContext context) {
    final total = _invoices.fold(
        0.0, (s, i) => s + i.grandTotal);

    return Scaffold(
      appBar: AppBar(
        title: const Text('All Invoices'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: 'Share JSON',
            onPressed: _shareAll,
          ),
          IconButton(
            icon: const Icon(Icons.delete_sweep_outlined),
            tooltip: 'Clear all',
            onPressed: _clearAll,
          ),
        ],
      ),
      body: Column(
        children: [
          // Summary bar
          Container(
            color: MunimTheme.navy,
            padding: const EdgeInsets.symmetric(
                horizontal: 20, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${_invoices.length} invoices',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
                Text('Total: Rs ${ExportService.inr(total)}',
                  style: const TextStyle(
                    color: MunimTheme.gold,
                    fontSize: 14,
                    fontWeight: FontWeight.bold)),
              ],
            ),
          ),

          // List
          Expanded(
            child: _invoices.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.receipt_long_outlined,
                          size: 56,
                          color: MunimTheme.muted.withOpacity(0.3)),
                        const SizedBox(height: 14),
                        const Text('No invoices',
                          style: TextStyle(
                            color: MunimTheme.muted,
                            fontSize: 15)),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _invoices.length,
                    itemBuilder: (_, i) {
                      final inv = _invoices[i];
                      return _InvoiceCard(
                        invoice: inv,
                        onDelete: () => _delete(inv),
                      );
                    },
                  ),
          ),
        ],
      ),
      bottomNavigationBar: _invoices.isNotEmpty
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: ElevatedButton.icon(
                  onPressed: _shareAll,
                  icon: const Icon(Icons.share),
                  label: const Text('Share JSON to import in MUNIM'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14)),
                ),
              ),
            )
          : null,
    );
  }
}

class _InvoiceCard extends StatelessWidget {
  final Invoice invoice;
  final VoidCallback onDelete;

  const _InvoiceCard({
    required this.invoice,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final inv = invoice;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: MunimTheme.cardBox(),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: MunimTheme.accent.withOpacity(0.06),
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(12)),
            ),
            child: Row(children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(inv.invNo,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: MunimTheme.accent)),
                    Text(inv.party,
                      style: const TextStyle(
                        fontSize: 13,
                        color: MunimTheme.text)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('Rs ${ExportService.inr(inv.grandTotal)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: MunimTheme.text)),
                  Text(ExportService.fmtDate(inv.date),
                    style: const TextStyle(
                      fontSize: 11,
                      color: MunimTheme.muted)),
                ],
              ),
            ]),
          ),

          // Items
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 8),
            child: Column(
              children: inv.items.map((it) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(children: [
                  Expanded(
                    child: Text(
                      '${it.name}  ×  ${it.qty} ${it.qty == it.qty.roundToDouble() ? it.qty.toInt() : it.qty}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: MunimTheme.muted)),
                  ),
                  Text('Rs ${ExportService.inr(it.total)}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: MunimTheme.text,
                      fontWeight: FontWeight.w500)),
                ]),
              )).toList(),
            ),
          ),

          // GST summary
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 8),
            decoration: const BoxDecoration(
              border: Border(
                top: BorderSide(color: MunimTheme.border))),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(inv.interstate
                    ? 'IGST: Rs ${ExportService.inr(inv.igst)}'
                    : 'CGST: Rs ${ExportService.inr(inv.cgst)}  '
                      'SGST: Rs ${ExportService.inr(inv.sgst)}',
                  style: const TextStyle(
                    fontSize: 11, color: MunimTheme.muted)),
                TextButton(
                  onPressed: onDelete,
                  style: TextButton.styleFrom(
                    foregroundColor: MunimTheme.danger,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8)),
                  child: const Text('Delete',
                    style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
