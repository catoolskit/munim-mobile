import 'package:flutter/material.dart';
import 'package:munim_mobile/theme.dart';
import 'package:munim_mobile/services/config_service.dart';
import 'package:munim_mobile/services/storage_service.dart';
import 'package:munim_mobile/services/export_service.dart';
import 'package:munim_mobile/models/invoice.dart';
import 'package:munim_mobile/screens/setup_screen.dart';
import 'package:munim_mobile/screens/invoice_screen.dart';
import 'package:munim_mobile/screens/invoice_list_screen.dart';

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
    setState(() { _invoices = invoices; _loading = false; });
  }

  Future<void> _newInvoice() async {
    final result = await Navigator.push<AppConfig>(
      context,
      MaterialPageRoute(
        builder: (_) => InvoiceScreen(config: _config),
      ),
    );
    if (result != null) {
      setState(() => _config = result);
    }
    await _load();
  }

  Future<void> _share() async {
    if (_invoices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No invoices to share yet.')));
      return;
    }
    try {
      await ExportService.shareInvoices(_invoices, _config.company);
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
          'This will remove your company config and all saved invoices. '
          'Are you sure?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reset',
              style: TextStyle(color: MunimTheme.danger))),
        ],
      ),
    );
    if (ok != true) return;
    await ConfigService.clear();
    await StorageService.clearInvoices();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const SetupScreen()),
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
            onPressed: _load,
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Reset app',
            onPressed: _reset,
          ),
        ],
