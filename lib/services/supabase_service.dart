import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/barcode_item.dart';

class SupabaseService {
  final _client = Supabase.instance.client;

  Future<BarcodeItem?> lookupBarcode(String barcode) async {
    try {
      final response = await _client
          .from('item_library')
          .select()
          .eq('barcode', barcode)
          .maybeSingle();

      if (response != null) {
        return BarcodeItem.fromJson(response);
      }
      return null;
    } catch (e) {
      print('Error looking up barcode: $e');
      return null;
    }
  }

  Future<void> pushToClient({
    required BarcodeItem item,
    required String businessId,
    bool syncToBilling = true,
  }) async {
    try {
      // 1. Save to client_items table
      await _client.from('client_items').upsert({
        'business_id': businessId,
        'barcode': item.barcode,
        'name': item.itemName,
        'sale_price': item.salePrice,
        'purchase_price': item.purchasePrice,
        'mrp': item.mrp,
        'added_at': DateTime.now().toIso8601String(),
      });

      // 2. Mock Call to Billing API
      if (syncToBilling) {
        print('Pushed ${item.itemName} to Billing API for business: $businessId');
        // Simulate a POST request
      }

      // 3. Log History
      await _client.from('onboarding_history').insert({
        'business_id': businessId,
        'barcode': item.barcode,
        'action': 'pushed',
        'details': {'name': item.itemName, 'price': item.salePrice},
      });
    } catch (e) {
      print('Error pushing to client: $e');
      rethrow;
    }
  }

  Future<void> updateLibrary(BarcodeItem item) async {
    try {
      await _client.from('item_library').upsert(item.toJson());
      
      // Log Update
      await _client.from('onboarding_history').insert({
        'business_id': _client.auth.currentUser?.id ?? 'ADMIN',
        'barcode': item.barcode,
        'action': 'library_update',
        'details': {'name': item.itemName},
      });
    } catch (e) {
      print('Error updating library: $e');
      rethrow;
    }
  }
}
