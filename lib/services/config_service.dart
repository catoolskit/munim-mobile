import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:munim_mobile/models/company.dart';
import 'package:munim_mobile/models/party.dart';
import 'package:munim_mobile/models/stock_item.dart';

class AppConfig {
  final Company company;
  final List<Party> parties;
  final List<StockItem> stockItems;
  final int lastSalesVno;

  AppConfig({
    required this.company,
    required this.parties,
    required this.stockItems,
    required this.lastSalesVno,
  });

  factory AppConfig.fromJson(Map<String, dynamic> json) {
    return AppConfig(
      company: Company.fromJson(json['company'] ?? {}),
      parties: (json['parties'] as List? ?? [])
          .map((p) => Party.fromJson(p))
          .toList(),
      stockItems: (json['stock_items'] as List? ?? [])
          .map((s) => StockItem.fromJson(s))
          .toList(),
      lastSalesVno: json['last_sales_vno'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'company':        company.toJson(),
    'parties':        parties.map((p) => p.toJson()).toList(),
    'stock_items':    stockItems.map((s) => s.toJson()).toList(),
    'last_sales_vno': lastSalesVno,
  };

  // Customers only
  List<Party> get customers =>
      parties.where((p) => p.isCustomer).toList();
}

class ConfigService {
  static const _key = 'munim_config';

  // Load config from local storage
  static Future<AppConfig?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return null;
    try {
      return AppConfig.fromJson(jsonDecode(raw));
    } catch (_) {
      return null;
    }
  }

  // Save config to local storage
  static Future<void> save(AppConfig config) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(config.toJson()));
  }

  // Import config from a JSON file string
  static Future<AppConfig> importFromString(String jsonStr) async {
    final map = jsonDecode(jsonStr) as Map<String, dynamic>;
    // Validate it's a MUNIM config
    if (!map.containsKey('company') || !map.containsKey('stock_items')) {
      throw Exception(
          'Invalid config file. Please export a fresh config from MUNIM.');
    }
    final config = AppConfig.fromJson(map);
    await save(config);
    return config;
  }

  // Clear config (reset app)
  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }

  // Update last vno after creating an invoice
  static Future<AppConfig> incrementVno(AppConfig config) async {
    final updated = AppConfig(
      company:      config.company,
      parties:      config.parties,
      stockItems:   config.stockItems,
      lastSalesVno: config.lastSalesVno + 1,
    );
    await save(updated);
    return updated;
  }

  // Add a new party to config (after auto-create)
  static Future<AppConfig> addParty(AppConfig config, Party party) async {
    final updated = AppConfig(
      company:      config.company,
      parties:      [...config.parties, party],
      stockItems:   config.stockItems,
      lastSalesVno: config.lastSalesVno,
    );
    await save(updated);
    return updated;
  }
}
