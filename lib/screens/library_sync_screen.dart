import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/supabase_service.dart';
import '../models/barcode_item.dart';

class LibrarySyncScreen extends StatefulWidget {
  final String businessId;
  final String branchId;

  const LibrarySyncScreen({
    super.key,
    required this.businessId,
    required this.branchId,
  });

  @override
  State<LibrarySyncScreen> createState() => _LibrarySyncScreenState();
}

class _LibrarySyncScreenState extends State<LibrarySyncScreen> {
  final SupabaseService _supabaseService = SupabaseService();
  final TextEditingController _searchController = TextEditingController();
  
  List<Map<String, dynamic>> _allProducts = [];
  List<Map<String, dynamic>> _filteredProducts = [];
  Set<String> _selectedBarcodes = {};
  bool _isLoading = true;
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    setState(() => _isLoading = true);
    final products = await _supabaseService.getProducts();
    setState(() {
      _allProducts = products;
      _filteredProducts = products;
      _isLoading = false;
    });
  }

  void _filterProducts(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredProducts = _allProducts;
      } else {
        _filteredProducts = _allProducts.where((p) =>
          p['item_name'].toString().toLowerCase().contains(query.toLowerCase()) ||
          p['barcode'].toString().toLowerCase().contains(query.toLowerCase()) ||
          (p['category'] ?? '').toString().toLowerCase().contains(query.toLowerCase())
        ).toList();
      }
    });
  }

  void _toggleSelection(String barcode) {
    setState(() {
      if (_selectedBarcodes.contains(barcode)) {
        _selectedBarcodes.remove(barcode);
      } else {
        _selectedBarcodes.add(barcode);
      }
    });
  }

  void _selectAll() {
    setState(() {
      if (_selectedBarcodes.length == _filteredProducts.length) {
        _selectedBarcodes.clear();
      } else {
        _selectedBarcodes = _filteredProducts.map((p) => p['barcode'].toString()).toSet();
      }
    });
  }

  Future<void> _syncSelectedProducts() async {
    if (_selectedBarcodes.isEmpty) return;

    setState(() => _isSyncing = true);

    int totalSuccessCount = 0;
    int totalFailCount = 0;

    // Convert selected barcodes to list of items
    final List<BarcodeItem> allSelectedItems = [];
    for (final barcode in _selectedBarcodes) {
      final product = _allProducts.firstWhere(
        (p) => p['barcode'] == barcode,
        orElse: () => {},
      );
      
      if (product.isNotEmpty) {
        allSelectedItems.add(BarcodeItem(
          barcode: product['barcode'],
          itemName: product['item_name'] ?? '',
          mrp: (product['mrp'] as num?)?.toDouble() ?? 0,
          salePrice: (product['sale_price'] as num?)?.toDouble() ?? (product['mrp'] as num?)?.toDouble() ?? 0,
          purchasePrice: 0,
          category: product['category'],
          unit: product['unit'],
          hsn: product['hsn_code'],
          taxRate: (product['tax_rate'] as num?)?.toDouble() ?? (product['gst_rate'] as num?)?.toDouble(),
        ));
      }
    }

    // Batch process items in groups of 100
    const int batchSize = 100;
    for (int i = 0; i < allSelectedItems.length; i += batchSize) {
      final int end = (i + batchSize < allSelectedItems.length) ? i + batchSize : allSelectedItems.length;
      final List<BarcodeItem> batch = allSelectedItems.sublist(i, end);

      try {
        final result = await _supabaseService.syncToBillifyV2(
          companyId: widget.businessId,
          branchId: widget.branchId,
          items: batch,
        );
        
        // Assuming response structure: { "success": true, "results": { "success_count": X, "failed_count": Y, ... } }
        // or just { "success_count": X, "failed_count": Y }
        final results = result['results'] ?? result;
        totalSuccessCount += (results['success_count'] as num?)?.toInt() ?? batch.length;
        totalFailCount += (results['failed_count'] as num?)?.toInt() ?? 0;
      } catch (e) {
        totalFailCount += batch.length;
      }
    }

    setState(() => _isSyncing = false);

    if (!mounted) return;
    
    _showSyncResult(totalSuccessCount, totalFailCount);
  }

  void _showSyncResult(int success, int failed) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2.5))),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: failed == 0 ? Colors.green.withValues(alpha: 0.1) : Colors.orange.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                failed == 0 ? Icons.check_circle_rounded : Icons.warning_rounded,
                size: 48,
                color: failed == 0 ? Colors.green : Colors.orange,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              failed == 0 ? 'Sync Complete!' : 'Sync Complete with Errors',
              style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              '$success items pushed successfully${failed > 0 ? '\n$failed items failed' : ''}',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(color: Colors.grey[600], fontSize: 16),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: CupertinoButton(
                color: const Color(0xFF2563EB),
                borderRadius: BorderRadius.circular(14),
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pop(context);
                },
                child: Text('Done', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          child: const Icon(CupertinoIcons.back, color: Color(0xFF2563EB)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Library Sync', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.black)),
        centerTitle: true,
        actions: [
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            onPressed: _selectAll,
            child: Text(
              _selectedBarcodes.length == _filteredProducts.length && _filteredProducts.isNotEmpty
                ? 'Deselect All'
                : 'Select All',
              style: GoogleFonts.outfit(color: const Color(0xFF2563EB), fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: CupertinoSearchTextField(
              controller: _searchController,
              onChanged: _filterProducts,
              placeholder: 'Search products...',
              style: GoogleFonts.outfit(),
            ),
          ),
          
          // Selected Count
          if (_selectedBarcodes.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: const Color(0xFF2563EB).withValues(alpha: 0.1),
              child: Row(
                children: [
                  const Icon(CupertinoIcons.checkmark_circle_fill, color: Color(0xFF2563EB), size: 20),
                  const SizedBox(width: 8),
                  Text(
                    '${_selectedBarcodes.length} items selected',
                    style: GoogleFonts.outfit(color: const Color(0xFF2563EB), fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () => setState(() => _selectedBarcodes.clear()),
                    child: Text('Clear', style: GoogleFonts.outfit(color: Colors.red, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
          
          // Product List
          Expanded(
            child: _isLoading
              ? const Center(child: CupertinoActivityIndicator())
              : _filteredProducts.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(CupertinoIcons.cube_box, size: 64, color: Colors.grey[300]),
                        const SizedBox(height: 16),
                        Text('No products found', style: GoogleFonts.outfit(color: Colors.grey[500], fontSize: 18)),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _filteredProducts.length,
                    itemBuilder: (context, index) {
                      final product = _filteredProducts[index];
                      final barcode = product['barcode'].toString();
                      final isSelected = _selectedBarcodes.contains(barcode);
                      
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: isSelected 
                            ? Border.all(color: const Color(0xFF2563EB), width: 2)
                            : Border.all(color: Colors.grey.withValues(alpha: 0.1)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.03),
                              blurRadius: 10,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () => _toggleSelection(barcode),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  // Selection Checkbox
                                  Container(
                                    width: 28,
                                    height: 28,
                                    decoration: BoxDecoration(
                                      color: isSelected ? const Color(0xFF2563EB) : Colors.grey.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: isSelected
                                      ? const Icon(CupertinoIcons.checkmark, color: Colors.white, size: 18)
                                      : null,
                                  ),
                                  const SizedBox(width: 14),
                                  
                                  // Product Info
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          product['item_name'] ?? 'Unknown',
                                          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 15),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Text(
                                              barcode,
                                              style: GoogleFonts.outfit(color: Colors.grey[500], fontSize: 12),
                                            ),
                                            if (product['category'] != null) ...[
                                              const SizedBox(width: 8),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: Text(
                                                  product['category'],
                                                  style: GoogleFonts.outfit(color: const Color(0xFF2563EB), fontSize: 11, fontWeight: FontWeight.w600),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  
                                  // Price
                                  Text(
                                    '₹${product['mrp'] ?? '0'}',
                                    style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16, color: const Color(0xFF2563EB)),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      
      // Sync Button
      bottomNavigationBar: _selectedBarcodes.isNotEmpty
        ? Container(
            padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).padding.bottom + 16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: CupertinoButton(
              color: const Color(0xFF2563EB),
              borderRadius: BorderRadius.circular(14),
              onPressed: _isSyncing ? null : _syncSelectedProducts,
              child: _isSyncing
                ? const CupertinoActivityIndicator(color: Colors.white)
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(CupertinoIcons.cloud_upload_fill, color: Colors.white),
                      const SizedBox(width: 12),
                      Text(
                        'Push ${_selectedBarcodes.length} Items to Client',
                        style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17),
                      ),
                    ],
                  ),
            ),
          )
        : null,
    );
  }
}
