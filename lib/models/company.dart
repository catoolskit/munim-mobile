class Company {
  final String name;
  final String address;
  final String gstin;
  final String stateName;
  final String phone;
  final String invoicePrefix;
  final bool gstRegistered;
  final String fy;

  Company({
    required this.name,
    required this.address,
    required this.gstin,
    required this.stateName,
    required this.phone,
    required this.invoicePrefix,
    required this.gstRegistered,
    required this.fy,
  });

  factory Company.fromJson(Map<String, dynamic> json) {
    return Company(
      name:          json['name']           ?? '',
      address:       json['address']        ?? '',
      gstin:         json['gstin']          ?? '',
      stateName:     json['state_name']     ?? '',
      phone:         json['phone']          ?? '',
      invoicePrefix: json['invoice_prefix'] ?? '',
      gstRegistered: json['gst_registered'] ?? true,
      fy:            json['fy']             ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'name':           name,
    'address':        address,
    'gstin':          gstin,
    'state_name':     stateName,
    'phone':          phone,
    'invoice_prefix': invoicePrefix,
    'gst_registered': gstRegistered,
    'fy':             fy,
  };
}
