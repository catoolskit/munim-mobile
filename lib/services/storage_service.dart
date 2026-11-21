import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:munim_mobile/models/invoice.dart';

class StorageService {
  static const _key = 'munim_invoices';

  // Load all invoices from local storage
  static Future<List<Invoice>> loadInvoices() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list.map((i) => Invoice.fromJson(i)).toList();
    } catch (_) {
      return [];
    }
  }

  // Save all invoices to local storage
  static Future<void> saveInvoices(List<Invoice> invoices) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode(invoices.map((i) => i.toJson()).toList()),
    );
  }

  // Add a single invoice
  static Future<List<Invoice>> addInvoice(Invoice invoice) async {
    final invoices = await loadInvoices();
    invoices.insert(0, invoice);
    await saveInvoices(invoices);
    return invoices;
  }

  // Delete a single invoice by mobileId
  static Future<List<Invoice>> deleteInvoice(String mobileId) async {
    final invoices = await loadInvoices();
    invoices.removeWhere((i) => i.mobileId == mobileId);
    await saveInvoices(invoices);
    return invoices;
  }

  // Clear all invoices (after successful import to desktop)
  static Future<void> clearInvoices() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }

  // Check if a mobileId already exists (duplicate prevention)
  static Future<bool> exists(String mobileId) async {
    final invoices = await loadInvoices();
    return invoices.any((i) => i.mobileId == mobileId);
  }

  // Count unsynced invoices
  static Future<int> count() async {
    final invoices = await loadInvoices();
    return invoices.length;
  }
}
