import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:munim_mobile/theme.dart';
import 'package:munim_mobile/services/config_service.dart';
import 'package:munim_mobile/services/storage_service.dart';
import 'package:munim_mobile/services/export_service.dart';
import 'package:munim_mobile/models/invoice.dart';
import 'package:munim_mobile/models/party.dart';
import 'package:munim_mobile/models/stock_item.dart';

class InvoiceScreen extends StatefulWidget {
  final AppConfig config;
  const InvoiceScreen({super.key, required this.config});

  @override
  State<InvoiceScreen> createState() => _InvoiceScreenState();
}

class _InvoiceScreenState extends State<InvoiceScreen> {
  late AppConfig _config;
  final _formKey = GlobalKey<FormState>();

  Party? _selectedParty;
  final _partyNameCtrl  = TextEditingController();
  final _partyGstinCtrl = TextEditingController();
  final _partyPhoneCtrl = TextEditingController();
  bool _newParty    = false;
  String _partyType = 'Customer';
  bool _interstate  = false;
  DateTime _date    = DateTime.now();

  final List<_ItemRow> _rows = [];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _config = widget.config;
    _addRow();
  }

  void _addRow() => setState(() => _rows.add(_ItemRow()));
  void _removeRow(int i) {
    if (_rows.length == 1) return;
    setState(() => _rows.removeAt(i));
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (d != null) setState(() => _date = d);
  }

  double get _taxable =>
      _rows.fold(0, (s, r) => s + r.amount);
  double get _totalGst =>
      _rows.fold(0, (s, r) => s + r.gstAmount);
  double get _grandTotal => _taxable + _totalGst;
  double get _cgst => _interstate ? 0 : _totalGst / 2;
  double get _sgst => _interstate ? 0 : _totalGst / 2;
  double get _igst => _interstate ? _totalGst : 0;

  // ── v0.18: respect GST registration ──────────────────────
  bool get _gstRegistered =>
      _config.company.gstRegistered;

  // If unregistered, grand total = taxable only (no GST)
  double get _effectiveGrandTotal =>
      _gstRegistered ? _grandTotal : _taxable;

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedParty == null && !_newParty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select or add a party')));
      return;
    }
    final validRows = _rows.where((r) =>
      r.effectiveName.isNotEmpty &&
      r.qty > 0 &&
      r.rate > 0).toList();
    if (validRows.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add at least one item')));
      return;
    }

    setState(() => _saving = true);

    try {
      AppConfig config = _config;
      String partyName;
      String partyGstin = '';
      String partyPhone = '';
      String partyType  = _partyType;

      if (_newParty) {
        partyName  = _partyNameCtrl.text.trim();
        partyGstin =
            _partyGstinCtrl.text.trim().toUpperCase();
        partyPhone = _partyPhoneCtrl.text.trim();
        final newP = Party(
          name: partyName, ptype: partyType,
          gstin: partyGstin, phone: partyPhone,
          address: '');
        config = await ConfigService.addParty(config, newP);
      } else {
        partyName  = _selectedParty!.name;
        partyGstin = _selectedParty!.gstin;
        partyPhone = _selectedParty!.phone;
        partyType  = _selectedParty!.ptype;
      }

      config = await ConfigService.incrementVno(config);
      final vno    = config.lastSalesVno;
      final prefix = config.company.invoicePrefix;
      final invNo  = '$prefix$vno';

      final items = validRows.map((r) => InvoiceItem(
        name:    r.effectiveName,
        hsn:     r.effectiveHsn,
        qty:     r.qty,
        rate:    r.rate,
        gstRate: r.effectiveGstRate,
      )).toList();

      final invoice = Invoice(
        mobileId:     const Uuid().v4(),
        invNo:        invNo,
        date:         DateFormat('yyyy-MM-dd').format(_date),
        party:        partyName,
        partyType:    partyType,
        partyGstin:   partyGstin,
        partyPhone:   partyPhone,
        partyAddress: '',
        interstate:   _interstate,
        customerName: partyName,
        items:        items,
        createdAt:    DateTime.now(),
      );

      await StorageService.addInvoice(invoice);
      if (!mounted) return;
      Navigator.pop(context, config);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✓ Invoice $invNo saved'),
          backgroundColor: MunimTheme.ok));
    } catch (e) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final customers = _config.parties
        .where((p) => p.isCustomer)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(_gstRegistered
            ? 'New Sale Invoice'
            : 'New Retail Invoice'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 18, height: 18,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2))
                : const Text('SAVE',
                    style: TextStyle(
                      color: MunimTheme.gold,
                      fontWeight: FontWeight.bold,
                      fontSize: 15)),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              // ── Party ─────────────────────────────
              _sectionTitle('Party Details'),
              const SizedBox(height: 8),
              Container(
                decoration: MunimTheme.cardBox(),
                padding: const EdgeInsets.all(16),
                child: Column(children: [
                  Row(
                    mainAxisAlignment:
                        MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('New party?',
                        style: TextStyle(
                          fontSize: 13,
                          color: MunimTheme.muted)),
                      Switch(
                        value: _newParty,
                        activeColor: MunimTheme.accent,
                        onChanged: (v) => setState(() {
                          _newParty = v;
                          _selectedParty = null;
                        }),
                      ),
                    ],
                  ),
                  const Divider(),
                  if (!_newParty)
                    DropdownButtonFormField<Party>(
                      value: _selectedParty,
                      decoration: const InputDecoration(
                        labelText: 'Select customer *'),
                      items: customers.map((p) =>
                        DropdownMenuItem(
                          value: p,
                          child: Text(p.name))).toList(),
                      onChanged: (p) => setState(
                          () => _selectedParty = p),
                      validator: (v) =>
                        v == null && !_newParty
                          ? 'Select a party' : null,
                    )
                  else ...[
                    TextFormField(
                      controller: _partyNameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Party name *'),
                      validator: (v) =>
                        (v?.trim().isEmpty ?? true)
                          ? 'Required' : null,
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      value: _partyType,
                      decoration: const InputDecoration(
                        labelText: 'Type'),
                      items: ['Customer', 'Supplier']
                        .map((t) => DropdownMenuItem(
                          value: t, child: Text(t)))
                        .toList(),
                      onChanged: (v) => setState(
                          () => _partyType = v!),
                    ),
                    const SizedBox(height: 10),
                    // Only show GSTIN field if registered
                    if (_gstRegistered) ...[
                      TextFormField(
                        controller: _partyGstinCtrl,
                        decoration: const InputDecoration(
                          labelText: 'GSTIN (optional)'),
                        textCapitalization:
                            TextCapitalization.characters,
                      ),
                      const SizedBox(height: 10),
                    ],
                    TextFormField(
                      controller: _partyPhoneCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Phone (optional)'),
                      keyboardType:
                          TextInputType.phone,
                    ),
                  ],
                  const SizedBox(height: 10),
                  // Only show interstate toggle if registered
                  if (_gstRegistered)
                    Row(
                      mainAxisAlignment:
                          MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Inter-state (IGST)?',
                          style: TextStyle(
                            fontSize: 13,
                            color: MunimTheme.muted)),
                        Switch(
                          value: _interstate,
                          activeColor: MunimTheme.accent,
                          onChanged: (v) => setState(
                              () => _interstate = v),
                        ),
                      ],
                    ),
                ]),
              ),
              const SizedBox(height: 16),

              // ── Date ──────────────────────────────
              _sectionTitle('Invoice Date'),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: _pickDate,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 14),
                  decoration: MunimTheme.cardBox(),
                  child: Row(children: [
                    const Icon(Icons.calendar_today,
                      color: MunimTheme.accent,
                      size: 18),
                    const SizedBox(width: 10),
                    Text(
                      DateFormat('dd-MM-yyyy')
                          .format(_date),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: MunimTheme.text)),
                    const Spacer(),
                    const Icon(Icons.arrow_drop_down,
                      color: MunimTheme.muted),
                  ]),
                ),
              ),
              const SizedBox(height: 16),

              // ── Items ─────────────────────────────
              _sectionTitle('Items'),
              const SizedBox(height: 8),
              ReorderableListView(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                buildDefaultDragHandles: false,
                onReorder: (oldIndex, newIndex) {
                  setState(() {
                    if (newIndex > oldIndex) newIndex--;
                    final row = _rows.removeAt(oldIndex);
                    _rows.insert(newIndex, row);
                  });
                },
                children: _rows.asMap().entries.map((e) =>
                  _ItemRowWidget(
                    key: ValueKey(e.key),
                    row: e.value,
                    stockItems: _config.stockItems,
                    index: e.key,
                    gstRegistered: _gstRegistered,
                    onRemove: () => _removeRow(e.key),
                    onChanged: () => setState(() {}),
                  ),
                ).toList(),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: _addRow,
                icon: const Icon(Icons.add),
                label: const Text('Add item'),
              ),
              const SizedBox(height: 16),

              // ── Totals ────────────────────────────
              Container(
                decoration: MunimTheme.cardBox(),
                padding: const EdgeInsets.all(16),
                child: Column(children: [
                  _totalRow('Taxable amount',
                    ExportService.inr(_taxable)),
                  // Show GST breakdown only if registered
                  if (_gstRegistered) ...[
                    if (!_interstate) ...[
                      _totalRow('CGST',
                        ExportService.inr(_cgst)),
                      _totalRow('SGST',
                        ExportService.inr(_sgst)),
                    ] else
                      _totalRow('IGST',
                        ExportService.inr(_igst)),
                  ],
                  const Divider(),
                  _totalRow(
                    'Grand Total',
                    'Rs ${ExportService.inr(_effectiveGrandTotal)}',
                    bold: true,
                    color: MunimTheme.accent),
                ]),
              ),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) => Text(title,
    style: const TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.bold,
      color: MunimTheme.muted,
      letterSpacing: 0.8));

  // ── v0.18: Fixed truncation with Flexible ─────────────────
  Widget _totalRow(String label, String value,
      {bool bold = false,
      Color color = MunimTheme.text}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment:
            MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            flex: 2,
            child: Text(label,
              style: TextStyle(
                fontSize: 13,
                color: bold
                    ? MunimTheme.text
                    : MunimTheme.muted,
                fontWeight: bold
                    ? FontWeight.bold
                    : FontWeight.normal)),
          ),
          const SizedBox(width: 8),
          Flexible(
            flex: 3,
            child: Text(value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: bold ? 14 : 13,
                color: color,
                fontWeight: bold
                    ? FontWeight.bold
                    : FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}

// ── Item row model ─────────────────────────────────────────────

class _ItemRow {
  StockItem? selectedItem;
  bool isCustom = false;
  String customName    = '';
  String customHsn     = '';
  String customGstRate = '0';

  double qty  = 1;
  double rate = 0;

  String get effectiveName =>
      isCustom ? customName : (selectedItem?.name ?? '');
  String get effectiveHsn =>
      isCustom ? customHsn : (selectedItem?.hsn ?? '');
  double get effectiveGstRate =>
      isCustom
          ? (double.tryParse(customGstRate) ?? 0)
          : (selectedItem?.gstRateDouble ?? 0);

  double get amount    => qty * rate;
  double get gstAmount => amount * effectiveGstRate / 100;
  double get total     => amount + gstAmount;
}

// ── Item row widget ────────────────────────────────────────────

class _ItemRowWidget extends StatefulWidget {
  final _ItemRow row;
  final List<StockItem> stockItems;
  final int index;
  final bool gstRegistered;
  final VoidCallback onRemove;
  final VoidCallback onChanged;

  const _ItemRowWidget({
    super.key,
    required this.row,
    required this.stockItems,
    required this.index,
    required this.gstRegistered,
    required this.onRemove,
    required this.onChanged,
  });

  @override
  State<_ItemRowWidget> createState() =>
      _ItemRowWidgetState();
}

class _ItemRowWidgetState
    extends State<_ItemRowWidget> {
  late TextEditingController _qtyCtrl;
  late TextEditingController _rateCtrl;
  late TextEditingController _customNameCtrl;
  late TextEditingController _customHsnCtrl;
  late TextEditingController _customGstCtrl;

  @override
  void initState() {
    super.initState();
    _qtyCtrl = TextEditingController(
      text: widget.row.qty == 1
          ? '' : widget.row.qty.toString());
    _rateCtrl = TextEditingController(
      text: widget.row.rate == 0
          ? '' : widget.row.rate.toString());
    _customNameCtrl = TextEditingController(
      text: widget.row.customName);
    _customHsnCtrl = TextEditingController(
      text: widget.row.customHsn);
    _customGstCtrl = TextEditingController(
      text: widget.row.customGstRate);
  }

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _rateCtrl.dispose();
    _customNameCtrl.dispose();
    _customHsnCtrl.dispose();
    _customGstCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: MunimTheme.cardBox(),
      child: Column(children: [
        // ── Custom toggle + remove + drag handle ──
        Row(
          mainAxisAlignment:
              MainAxisAlignment.spaceBetween,
          children: [
            Row(children: [
              const Text('Custom item',
                style: TextStyle(
                  fontSize: 12,
                  color: MunimTheme.muted)),
              const SizedBox(width: 6),
              Switch(
                value: widget.row.isCustom,
                activeColor: MunimTheme.accent,
                materialTapTargetSize:
                    MaterialTapTargetSize.shrinkWrap,
                onChanged: (v) {
                  setState(() {
                    widget.row.isCustom = v;
                    widget.row.selectedItem = null;
                  });
                  widget.onChanged();
                },
              ),
            ]),
            Row(children: [
              IconButton(
                icon: const Icon(
                  Icons.remove_circle_outline,
                  color: MunimTheme.danger),
                onPressed: widget.onRemove,
              ),
              // Drag handle
              ReorderableDragStartListener(
                index: widget.index,
                child: const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Icon(
                    Icons.drag_handle,
                    color: MunimTheme.muted,
                    size: 20),
                ),
              ),
            ]),
          ],
        ),
        const SizedBox(height: 4),

        // ── Stock item dropdown ────────────────
        if (!widget.row.isCustom) ...[
          DropdownButtonFormField<StockItem>(
            value: widget.row.selectedItem,
            decoration: const InputDecoration(
              labelText: 'Select item *',
              contentPadding: EdgeInsets.symmetric(
                horizontal: 10, vertical: 10)),
            items: widget.stockItems.map((s) =>
              DropdownMenuItem(
                value: s,
                child: Text(s.name))).toList(),
            onChanged: (s) {
              setState(() =>
                  widget.row.selectedItem = s);
              widget.onChanged();
            },
          ),
          const SizedBox(height: 8),
          if (widget.row.selectedItem != null)
            Row(children: [
              // Show HSN and GST only if registered
              if (widget.gstRegistered) ...[
                _chip('HSN: ${widget.row.selectedItem!.hsn}'),
                const SizedBox(width: 8),
                _chip('GST: ${widget.row.selectedItem!.gstRate}%'),
                const SizedBox(width: 8),
              ],
              _chip(widget.row.selectedItem!.unit),
            ]),
        ]

        // ── Custom item fields ─────────────────
        else ...[
          TextFormField(
            controller: _customNameCtrl,
            decoration: const InputDecoration(
              labelText: 'Item name *',
              contentPadding: EdgeInsets.symmetric(
                horizontal: 10, vertical: 10)),
            onChanged: (v) {
              widget.row.customName = v;
              widget.onChanged();
            },
          ),
          // Show HSN and GST fields only if registered
          if (widget.gstRegistered) ...[
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                child: TextFormField(
                  controller: _customHsnCtrl,
                  decoration: const InputDecoration(
                    labelText: 'HSN/SAC',
                    contentPadding:
                      EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 10)),
                  onChanged: (v) {
                    widget.row.customHsn = v;
                    widget.onChanged();
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextFormField(
                  controller: _customGstCtrl,
                  decoration: const InputDecoration(
                    labelText: 'GST %',
                    contentPadding:
                      EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 10)),
                  keyboardType:
                    const TextInputType
                      .numberWithOptions(decimal: true),
                  onChanged: (v) {
                    widget.row.customGstRate =
                        v.isEmpty ? '0' : v;
                    widget.onChanged();
                  },
                ),
              ),
            ]),
          ],
        ],

        const SizedBox(height: 10),

        // ── Qty + Rate ────────────────────────
        Row(children: [
          Expanded(
            child: TextFormField(
              controller: _qtyCtrl,
              decoration: const InputDecoration(
                labelText: 'Qty *',
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 10, vertical: 10)),
              keyboardType:
                const TextInputType
                  .numberWithOptions(decimal: true),
              onChanged: (v) {
                widget.row.qty =
                    double.tryParse(v) ?? 0;
                widget.onChanged();
              },
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextFormField(
              controller: _rateCtrl,
              decoration: const InputDecoration(
                labelText: 'Rate (Rs) *',
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 10, vertical: 10)),
              keyboardType:
                const TextInputType
                  .numberWithOptions(decimal: true),
              onChanged: (v) {
                widget.row.rate =
                    double.tryParse(v) ?? 0;
                widget.onChanged();
              },
            ),
          ),
        ]),

        // ── Live amount ───────────────────────
        if (widget.row.amount > 0) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment:
                MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  'Taxable: Rs ${ExportService.inr(widget.row.amount)}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: MunimTheme.muted)),
              ),
              // Show GST only if registered
              if (widget.gstRegistered)
                Flexible(
                  child: Text(
                    'GST: Rs ${ExportService.inr(widget.row.gstAmount)}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: MunimTheme.muted)),
                ),
              Flexible(
                child: Text(
                  'Total: Rs ${ExportService.inr(widget.gstRegistered ? widget.row.total : widget.row.amount)}',
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: MunimTheme.accent)),
              ),
            ],
          ),
        ],
      ]),
    );
  }

  Widget _chip(String label) => Container(
    padding: const EdgeInsets.symmetric(
      horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: MunimTheme.accent.withOpacity(0.08),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(label,
      style: const TextStyle(
        fontSize: 11,
        color: MunimTheme.accent,
        fontWeight: FontWeight.w600)),
  );
}
