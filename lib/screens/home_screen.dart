import 'package:flutter/material.dart';
import 'package:munim_mobile/theme.dart';
import 'package:munim_mobile/services/config_service.dart';
import 'package:munim_mobile/services/storage_service.dart';
import 'package:munim_mobile/services/export_service.dart';
import 'package:munim_mobile/models/invoice.dart';
import 'package:munim_mobile/screens/setup_screen.dart';
import 'package:munim_mobile/screens/invoice_screen.dart';
import 'package:munim_mobile/screens/invoice_list_screen.dart';
import 'package:munim_mobile/screens/invoice_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  final AppConfig config;
  const HomeScreen({super.key, required this.config});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late AppConfig _config;
  List<Invoice> _invoices = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _config = widget.config;
    _load();
  }

  Future<void> _load() async {
    final invoices = await StorageService.loadInvoices();
    setState(() {
      _invoices = invoices;
      _loading = false;
    });
  }

  Future<void> _newInvoice() async {
    final result = await Navigator.push<AppConfig>(
      context,
      MaterialPageRoute(
        builder: (_) => InvoiceScreen(config: _config)),
    );
    if (result != null) setState(() => _config = result);
    await _load();
  }

  Future<void> _shareAll() async {
    if (_invoices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No invoices to share yet.')));
      return;
    }
    try {
      await ExportService.shareInvoices(
          _invoices, _config.company);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _sharePdf(Invoice inv) async {
    try {
      await ExportService.shareInvoicePdf(
          inv, _config.company);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _reset() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Reset App'),
        content: const Text(
          'This will remove your company config and all '
          'saved invoices. Are you sure?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reset',
              style: TextStyle(
                color: MunimTheme.danger))),
        ],
      ),
    );
    if (ok != true) return;
    await ConfigService.clear();
    await StorageService.clearInvoices();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => const SetupScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final company = _config.company;
    return Scaffold(
      appBar: AppBar(
        title: const Text('MUNIM'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _load),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Reset app',
            onPressed: _reset),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: SingleChildScrollView(
                physics:
                    const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    // Company card
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            MunimTheme.navy,
                            Color(0xFF1B3156)
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius:
                            BorderRadius.circular(16),
                      ),
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Text(company.name,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white)),
                          const SizedBox(height: 4),
                          Text(company.gstin.isEmpty
                            ? 'No GSTIN'
                            : company.gstin,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.white
                                  .withOpacity(0.6))),
                          const SizedBox(height: 4),
                          Text('FY ${company.fy}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white
                                  .withOpacity(0.5))),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Stats
                    Row(children: [
                      _statCard(
                        'Invoices',
                        '${_invoices.length}',
                        Icons.receipt_outlined,
                        MunimTheme.accent),
                      const SizedBox(width: 12),
                      _statCard(
                        'Total Sales',
                        'Rs ${ExportService.inr(_invoices.fold(0.0, (s, i) => s + i.grandTotal))}',
                        Icons.trending_up,
                        MunimTheme.ok),
                    ]),
                    const SizedBox(height: 16),

                    // Buttons
                    Row(children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _newInvoice,
                          icon: const Icon(Icons.add),
                          label: const Text(
                            'New Invoice'),
                          style:
                              ElevatedButton.styleFrom(
                            padding:
                                const EdgeInsets.symmetric(
                                    vertical: 14)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _shareAll,
                          icon: const Icon(Icons.share),
                          label: const Text(
                            'Share JSON'),
                          style:
                              OutlinedButton.styleFrom(
                            padding:
                                const EdgeInsets.symmetric(
                                    vertical: 14),
                            foregroundColor:
                                MunimTheme.accent,
                            side: const BorderSide(
                              color: MunimTheme.accent),
                          ),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 20),

                    // Recent invoices
                    Row(
                      mainAxisAlignment:
                          MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Recent Invoices',
                          style:
                              MunimTheme.headingStyle),
                        if (_invoices.isNotEmpty)
                          TextButton(
                            onPressed: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                    InvoiceListScreen(
                                      config: _config,
                                      invoices:
                                          _invoices,
                                    ),
                                ),
                              );
                              _load();
                            },
                            child:
                              const Text('View all')),
                      ],
                    ),
                    const SizedBox(height: 8),

                    if (_invoices.isEmpty)
                      Container(
                        width: double.infinity,
                        padding:
                            const EdgeInsets.all(32),
                        decoration:
                            MunimTheme.cardBox(),
                        child: Column(children: [
                          Icon(
                            Icons
                              .receipt_long_outlined,
                            size: 48,
                            color: MunimTheme.muted
                              .withOpacity(0.4)),
                          const SizedBox(height: 12),
                          const Text(
                            'No invoices yet',
                            style: TextStyle(
                              color: MunimTheme.muted,
                              fontSize: 14)),
                          const SizedBox(height: 4),
                          const Text(
                            'Tap New Invoice to create one',
                            style: TextStyle(
                              color: MunimTheme.muted,
                              fontSize: 12)),
                        ]),
                      )
                    else
                      ..._invoices.take(5).map(
                        (inv) => _invoiceTile(inv)),
                  ],
                ),
              ),
            ),
      floatingActionButton:
          FloatingActionButton.extended(
        onPressed: _newInvoice,
        backgroundColor: MunimTheme.accent,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('New Invoice',
          style: TextStyle(
            fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _statCard(String label, String value,
      IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: MunimTheme.cardBox(),
        child: Row(children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(label,
                  style: const TextStyle(
                    fontSize: 11,
                    color: MunimTheme.muted)),
                SizedBox(
                  width: double.infinity,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(value,
                      maxLines: 1,
                      softWrap: false,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: MunimTheme.text)),
                  ),
                ),
              ],
            ),
          ),
        ]),
      ),
    );
  }

  Widget _invoiceTile(Invoice inv) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => InvoiceDetailScreen(invoice: inv, config: _config),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: MunimTheme.cardBox(),
        child: Row(children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color:
                MunimTheme.accent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.picture_as_pdf,
              color: MunimTheme.accent, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(inv.invNo,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: MunimTheme.text)),
                Text(inv.party,
                  style: const TextStyle(
                    fontSize: 12,
                    color: MunimTheme.muted)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment:
                CrossAxisAlignment.end,
            children: [
              Text(
                'Rs ${ExportService.inr(inv.grandTotal)}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: MunimTheme.accent)),
              Text(ExportService.fmtDate(inv.date),
                style: const TextStyle(
                  fontSize: 11,
                  color: MunimTheme.muted)),
            ],
          ),
        ]),
      ),
    );
  }
}
