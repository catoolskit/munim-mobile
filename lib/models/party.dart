class Party {
  final String name;
  final String ptype;
  final String gstin;
  final String phone;
  final String address;

  Party({
    required this.name,
    required this.ptype,
    required this.gstin,
    required this.phone,
    required this.address,
  });

  factory Party.fromJson(Map<String, dynamic> json) {
    return Party(
      name:    json['name']    ?? '',
      ptype:   json['ptype']   ?? 'Customer',
      gstin:   json['gstin']   ?? '',
      phone:   json['phone']   ?? '',
      address: json['address'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'name':    name,
    'ptype':   ptype,
    'gstin':   gstin,
    'phone':   phone,
    'address': address,
  };

  bool get isCustomer => ptype == 'Customer';

  @override
  String toString() => name;
}
