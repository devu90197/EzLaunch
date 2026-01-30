import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/barcode_item.dart';
import '../core/constants.dart';

class SupabaseService {
  // Client 1: EzLaunch (Primary/Auth & Big Dataset)
  // This client is initialized in main.dart and handles User Login
  final SupabaseClient _libraryClient = Supabase.instance.client;

  // Client 2: EZBillify V2 (Secondary/Sync Target)
  // We use the Service Role key here to fetch companies/branches 
  // and push data without needing a separate login for Billify.
  final SupabaseClient _billifyClient = SupabaseClient(
    AppConstants.billifyUrl,
    AppConstants.billifyKey,
  );

  // --- PRODUCT MASTER OPERATIONS (Single Source of Truth) ---

  /// Lookup a barcode in the Product Master (unified source)
  Future<BarcodeItem?> lookupBarcode(String barcode) async {
    try {
      final response = await _libraryClient
          .from('product_master')
          .select()
          .eq('barcode', barcode)
          .maybeSingle();

      if (response != null) {
        return BarcodeItem.fromJson(response);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Log scan events for auditing and analytics
  Future<void> logOnboardingEvent({required String barcode, required String status}) async {
    try {
      final user = _libraryClient.auth.currentUser;
      await _libraryClient.from('onboarding_logs').insert({
        'barcode': barcode,
        'status': status,
        'user_email': user?.email,
        'user_id': user?.id,
      });
    } catch (e) {
      print('ERROR Logging Event: $e');
    }
  }

  /// Add or update items in Product Master (Batch)
  Future<void> updateLibraryBatch(List<BarcodeItem> items) async {
    try {
      print('DEBUG: Starting library batch update for ${items.length} items');
      final data = items.map((item) => {
        'barcode': item.barcode,
        'item_name': item.itemName,
        'category': item.category,
        'hsn_code': item.hsn,
        'mrp': item.mrp,
        'tax_rate': item.taxRate,
        'unit': item.unit,
      }).toList();

      final response = await _libraryClient.from('product_master').upsert(data, onConflict: 'barcode').select();
      print('DEBUG: Library update success. Response items: ${response.length}');
    } catch (e) {
      print('DEBUG: Library update FAILED: $e');
      rethrow;
    }
  }

  /// Add or update an item in Product Master
  Future<void> updateLibrary(BarcodeItem item) async {
    await updateLibraryBatch([item]);
  }


  Future<List<Map<String, dynamic>>> getProducts() async {
    try {
      final response = await _libraryClient
          .from('product_master')
          .select()
          .order('item_name');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getCategories() async {
    try {
      final response = await _libraryClient
          .from('categories')
          .select()
          .order('name');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getUnits() async {
    try {
      final response = await _libraryClient
          .from('units')
          .select()
          .order('name');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      return [];
    }
  }

  // --- BILLIFY OPERATIONS (EZBillify V2 Target) ---
  // Note: Since we use Service Role for _billifyClient, we can see all records.

  Future<List<Map<String, dynamic>>> getCompanies() async {
    try {
      // Fetching all companies from Billify V2 using Service Role
      final response = await _billifyClient
          .from('companies')
          .select('id, name')
          .order('name');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getBranches(String companyId) async {
    try {
      final response = await _billifyClient
          .from('branches')
          .select('id, name')
          .eq('company_id', companyId)
          .order('name');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getSyncedItems(String companyId, String branchId) async {
    try {
      var query = _billifyClient
          .from('items')
          .select('name, barcode, created_at, mrp, category')
          .eq('business_id', companyId);
      
      if (branchId != 'all') {
        query = query.eq('branch_id', branchId);
      }
      
      final response = await query
          .order('created_at', ascending: false)
          .limit(20);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      return [];
    }
  }

  Future<Map<String, dynamic>> syncToBillifyV2({
    required String companyId,
    required String branchId,
    required List<BarcodeItem> items,
  }) async {
    final payload = {
      'company_id': companyId,
      'branch_id': branchId,
      'items': items.map((item) => {
        'item_name': item.itemName,
        'barcode': item.barcode,
        'unit': item.unit ?? 'pcs',
        'mrp': item.mrp,
        'hsn_code': item.hsn,
        'category': item.category,
        'tax_rate': item.taxRate,
      }).toList(),
    };

    try {
      print('DEBUG: Syncing to ${AppConstants.billifySyncUrl}');
      print('DEBUG: Payload summary: Company $companyId, Branch $branchId, Items ${items.length}');
      
      final response = await http.post(
        Uri.parse(AppConstants.billifySyncUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${AppConstants.billifySyncToken}',
        },
        body: jsonEncode(payload),
      );

      print('DEBUG: Sync Response Status: ${response.statusCode}');
      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonDecode(response.body);
      } else {
        print('DEBUG: Sync FAILED with body: ${response.body}');
        throw Exception('API Error (${response.statusCode}): ${response.body}');
      }
    } catch (e) {
      print('DEBUG: Sync EXCEPTION: $e');
      rethrow;
    }
  }

  Future<void> pushToClient({
    required BarcodeItem item,
    required String businessId,
    required String branchId,
    bool syncToBilling = true,
  }) async {
    // Deprecated in favor of syncToBillifyV2 batch integration
    // But keeping it for backward compatibility if needed elsewhere
    await syncToBillifyV2(
      companyId: businessId,
      branchId: branchId,
      items: [item],
    );
  }

  // --- AUTH METADATA ---

  String? getUserDisplayName() {
    final user = _libraryClient.auth.currentUser;
    return user?.userMetadata?['full_name'] as String?;
  }

  Future<void> updateUserDisplayName(String name) async {
    try {
      await _libraryClient.auth.updateUser(
        UserAttributes(data: {'full_name': name}),
      );
    } catch (e) {
      rethrow;
    }
  }

  Future<void> signOut() async {
    await _libraryClient.auth.signOut();
  }
}
