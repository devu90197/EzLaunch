import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/barcode_item.dart';

class LocalStorageService {
  static const String _scanQueueKey = 'scan_queue_';

  Future<void> saveScanQueue(String companyId, String branchId, List<BarcodeItem> items) async {
    final prefs = await SharedPreferences.getInstance();
    final String key = '$_scanQueueKey${companyId}_$branchId';
    final String data = jsonEncode(items.map((e) => e.toJson()).toList());
    await prefs.setString(key, data);
  }

  Future<List<BarcodeItem>> loadScanQueue(String companyId, String branchId) async {
    final prefs = await SharedPreferences.getInstance();
    final String key = '$_scanQueueKey${companyId}_$branchId';
    final String? data = prefs.getString(key);
    
    if (data == null) return [];
    
    try {
      final List<dynamic> jsonList = jsonDecode(data);
      return jsonList.map((e) => BarcodeItem.fromJson(e)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> clearScanQueue(String companyId, String branchId) async {
    final prefs = await SharedPreferences.getInstance();
    final String key = '$_scanQueueKey${companyId}_$branchId';
    await prefs.remove(key);
  }

  Future<Map<String, int>> getAllPendingCounts() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => k.startsWith(_scanQueueKey));
    
    Map<String, int> counts = {};
    for (final key in keys) {
      final data = prefs.getString(key);
      if (data != null) {
        try {
          final list = jsonDecode(data) as List;
          if (list.isNotEmpty) {
            counts[key.replaceFirst(_scanQueueKey, '')] = list.length;
          }
        } catch (_) {}
      }
    }
    return counts;
  }
}
