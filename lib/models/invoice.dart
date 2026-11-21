class InvoiceItem {
  final String name;
  final String hsn;
  final double qty;
  final double rate;
  final double gstRate;

  InvoiceItem({
    required this.name,
    required this.hsn,
    required this.qty,
    required this.rate,
    required this.gstRate,
  });

  double get amount => qty * rate;
  double get gstAmount => amount * gstRate / 100;
  double get total => amount + gstAmount;

  factory InvoiceItem.fromJson(Map<String, dynamic> json) {
    return InvoiceItem(
      name:    json['name']     ?? '',
      hsn:     json['hsn']     ?? '',
      qty:     double.tryParse(json['qty'].toString())     ?? 0,
      rate:    double.tryParse(json['rate'].toString())    ?? 0,
      gstRate: double.tryParse(json['gst_rate'].toString()) ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'name':     name,
    'hsn':      hsn,
    'qty':      qty.toString(),
    'rate':     rate.toString(),
    'gst_rate': gstRate.toString(),
  };
}

class Invoice {
  final String mobileId;
  final String invNo;
  final String date;
  final String party;
  final String partyType;
  final String partyGstin;
  final String partyPhone;
  final String partyAddress;
  final bool interstate;
  final String customerName;
  final List<InvoiceItem> items;
  final DateTime createdAt;

  Invoice({
    required this.mobileId,
    required this.invNo,
    required this.date,
    required this.party,
    required this.partyType,
    required this.partyGstin,
    required this.partyPhone,
    required this.partyAddress,
    required this.interstate,
    required this.customerName,
    required this.items,
    required this.createdAt,
  });

  double get taxable => items.fold(0, (s, i) => s + i.amount);
  double get totalGst => items.fold(0, (s, i) => s + i.gstAmount);
  double get grandTotal => taxable + totalGst;
  double get cgst => interstate ? 0 : totalGst / 2;
  double get sgst => interstate ? 0 : totalGst / 2;
  double get igst => interstate ? totalGst : 0;

  factory Invoice.fromJson(Map<String, dynamic> json) {
    return Invoice(
      mobileId:     json['mobile_id']      ?? '',
      invNo:        json['inv_no']         ?? '',
      date:         json['date']           ?? '',
      party:        json['party']          ?? '',
      partyType:    json['party_type']     ?? 'Customer',
      partyGstin:   json['party_gstin']   ?? '',
      partyPhone:   json['party_phone']   ?? '',
      partyAddress: json['party_address'] ?? '',
      interstate:   json['interstate']    ?? false,
      customerName: json['customer_name'] ?? '',
      items: (json['items'] as List? ?? [])
          .map((i) => InvoiceItem.fromJson(i))
          .toList(),
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'mobile_id':      mobileId,
    'inv_no':         invNo,
    'date':           date,
    'party':          party,
    'party_type':     partyType,
    'party_gstin':    partyGstin,
    'party_phone':    partyPhone,
    'party_address':  partyAddress,
    'interstate':     interstate,
    'customer_name':  customerName,
    'items':          items.map((i) => i.toJson()).toList(),
    'created_at':     createdAt.toIso8601String(),
  };
}
