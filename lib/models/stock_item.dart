class StockItem {
  final String name;
  final String hsn;
  final String unit;
  final String gstRate;

  StockItem({
    required this.name,
    required this.hsn,
    required this.unit,
    required this.gstRate,
  });

  factory StockItem.fromJson(Map<String, dynamic> json) {
    return StockItem(
      name:    json['name']     ?? '',
      hsn:     json['hsn']     ?? '',
      unit:    json['unit']    ?? 'pcs',
      gstRate: json['gst_rate'] ?? '0',
    );
  }

  Map<String, dynamic> toJson() => {
    'name':     name,
    'hsn':      hsn,
    'unit':     unit,
    'gst_rate': gstRate,
  };

  double get gstRateDouble => double.tryParse(gstRate) ?? 0.0;

  @override
  String toString() => name;
}
