import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';
import '../services/supabase_service.dart';
import '../models/barcode_item.dart';
import '../widgets/add_item_dialog.dart';
import 'scanner_screen.dart';

class ProductListScreen extends StatefulWidget {
  const ProductListScreen({super.key});

  @override
  State<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends State<ProductListScreen> {
  final SupabaseService _supabaseService = SupabaseService();
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _allProducts = [];
  List<Map<String, dynamic>> _filteredProducts = [];
  bool _isLoading = true;
  String _searchQuery = "";

  @override
  void initState() {
    super.initState();
    _fetchProducts();
  }

  Future<void> _fetchProducts() async {
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
      _searchQuery = query;
      if (query.isEmpty) {
        _filteredProducts = _allProducts;
      } else {
        _filteredProducts = _allProducts
            .where((p) =>
                p['item_name'].toString().toLowerCase().contains(query.toLowerCase()) ||
                p['barcode'].toString().toLowerCase().contains(query.toLowerCase()))
            .toList();
      }
    });
  }

  void _openScanner() async {
    final barcode = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (context) => const ScannerScreen(mode: 'Lookup')),
    );

    if (barcode != null) {
      _searchController.text = barcode;
      _filterProducts(barcode);
      
      // If nothing found locally, check remote database before triggering onboarding
      if (_filteredProducts.isEmpty) {
        setState(() => _isLoading = true);
        final remoteItem = await _supabaseService.lookupBarcode(barcode);
        setState(() => _isLoading = false);

        if (remoteItem != null) {
          // Found remotely! Show details directly to avoid pagination issues
          _showProductDetails(remoteItem.toJson());
          // Also trigger a background refresh of the full list if needed
          _fetchProducts(); 
        } else {
          // Genuinely not found anywhere
          _onboardNewItem(barcode);
        }
      } else {
        // Found locally, show details
        _showProductDetails(_filteredProducts.first);
      }
    }
  }

  void _onboardNewItem([String? barcode]) async {
    final proceed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2.5))),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.orange.withValues(alpha: 0.1), shape: BoxShape.circle),
              child: const Icon(Icons.inventory_2_outlined, size: 40, color: Colors.orange),
            ),
            const SizedBox(height: 16),
            Text('Onboard New Item', style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(barcode != null 
              ? 'Barcode $barcode isn\'t in your registry.\nAdd it to your master library now?' 
              : 'Add a new item to your master library\nand synchronize it across branches.', 
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(fontSize: 16, color: Colors.grey[600])
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: Text('Start Setup', style: GoogleFonts.outfit(fontSize: 17, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Cancel', style: GoogleFonts.outfit(color: Colors.grey[500], fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );

    if (proceed != true) return;
    if (!mounted) return;

    final newItem = await showModalBottomSheet<BarcodeItem>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddItemDialog(barcode: barcode ?? ''),
    );

    if (newItem != null) {
      setState(() => _isLoading = true);
      await _supabaseService.updateLibrary(newItem);
      await _fetchProducts();
      if (_searchController.text.isNotEmpty) {
        _filterProducts(_searchController.text);
      }
    }
  }

  void _showProductDetails(Map<String, dynamic> product) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(sheetContext).padding.bottom + 24,
          left: 24, right: 24, top: 12,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // iOS Handle
            Center(
              child: Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2.5))),
            ),
            const SizedBox(height: 20),
            
            // Header with Edit/Close
            Row(
              children: [
                Container(
                  width: 56, height: 56,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFF3B82F6), Color(0xFF2563EB)]),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.inventory_2_rounded, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(product['item_name'] ?? 'Unknown', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 2),
                      Text(product['barcode'] ?? 'No Barcode', style: GoogleFonts.outfit(color: Colors.grey[500], fontSize: 13)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),
            
            // Pricing Section
            Text('PRICING', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey[400], letterSpacing: 1.2)),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
                  _buildDetailRow('MRP (Sale Price)', '₹${product['mrp'] ?? '0'}', Icons.currency_rupee_rounded),
                  Divider(height: 1, color: Colors.grey[200]),
                  _buildDetailRow('Tax Rate', '${product['tax_rate'] ?? '0'}%', CupertinoIcons.percent),
                ],
              ),
            ),

            const SizedBox(height: 24),
            
            // Specs Section
            Text('SPECIFICATIONS', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey[400], letterSpacing: 1.2)),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
                  _buildDetailRow('Category', product['category'] ?? 'General', CupertinoIcons.square_grid_2x2),
                  Divider(height: 1, color: Colors.grey[200]),
                  _buildDetailRow('Unit', product['unit'] ?? 'PCS', CupertinoIcons.square_stack),
                  Divider(height: 1, color: Colors.grey[200]),
                  _buildDetailRow('HSN Code', product['hsn_code'] ?? 'N/A', CupertinoIcons.number),
                ],
              ),
            ),
            const SizedBox(height: 28),
            
            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: CupertinoButton(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(14),
                    onPressed: () => Navigator.pop(sheetContext),
                    child: Text('Close', style: GoogleFonts.outfit(color: const Color(0xFF64748B), fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: CupertinoButton(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    color: const Color(0xFF2563EB),
                    borderRadius: BorderRadius.circular(14),
                    onPressed: () {
                      Navigator.pop(sheetContext);
                      _showEditSheet(product);
                    },
                    child: Text('Edit Item', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Icon(icon, size: 18, color: const Color(0xFF3B82F6)),
          const SizedBox(width: 12),
          Text(label, style: GoogleFonts.outfit(color: Colors.grey[600], fontSize: 15)),
          const Spacer(),
          Text(value, style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 15)),
        ],
      ),
    );
  }

  void _showEditSheet(Map<String, dynamic> product) {
    final nameController = TextEditingController(text: product['item_name'] ?? '');
    final mrpController = TextEditingController(text: product['mrp']?.toString() ?? '');
    final hsnController = TextEditingController(text: product['hsn_code'] ?? '');
    final taxController = TextEditingController(text: product['tax_rate']?.toString() ?? '0');
    String? selectedCategory = product['category'];
    String? selectedUnit = product['unit'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 24,
            left: 24, right: 24, top: 12,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2.5)))),
                const SizedBox(height: 20),
                
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Edit Product', style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold)),
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: () => Navigator.pop(sheetContext),
                      child: const Icon(CupertinoIcons.xmark_circle_fill, color: Colors.grey, size: 28),
                    ),
                  ],
                ),
                Text('Barcode: ${product['barcode']}', style: GoogleFonts.outfit(color: Colors.grey[500], fontSize: 13)),
                const SizedBox(height: 24),
                
                _buildCupertinoField('Item Name', nameController, CupertinoIcons.bag),
                const SizedBox(height: 16),
                
                Row(
                  children: [
                    Expanded(child: _buildCupertinoField('MRP (Sale Price)', mrpController, Icons.currency_rupee_rounded, isNumber: true)),
                    const SizedBox(width: 12),
                    Expanded(child: _buildCupertinoField('Tax Rate (%)', taxController, CupertinoIcons.percent, isNumber: true)),
                  ],
                ),
                const SizedBox(height: 16),
                _buildCupertinoField('HSN Code', hsnController, CupertinoIcons.number),
                const SizedBox(height: 16),
                
                Row(
                  children: [
                    Expanded(
                      child: _buildTapField('Category', selectedCategory, CupertinoIcons.square_grid_2x2, () async {
                        final cats = await _supabaseService.getCategories();
                        final items = cats.map((e) => e['name'] as String).toList();
                        if (!mounted) return;
                        _showPickerSheet(sheetContext, 'Category', items, selectedCategory, (val) {
                          setSheetState(() => selectedCategory = val);
                        });
                      }),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildTapField('Unit', selectedUnit, CupertinoIcons.square_stack, () async {
                        final units = await _supabaseService.getUnits();
                        final items = units.map((e) => e['name'] as String).toList();
                        if (!mounted) return;
                        _showPickerSheet(sheetContext, 'Unit', items, selectedUnit, (val) {
                          setSheetState(() => selectedUnit = val);
                        });
                      }),
                    ),
                  ],
                ),

                const SizedBox(height: 32),
                
                SizedBox(
                  width: double.infinity,
                  child: CupertinoButton(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    color: const Color(0xFF2563EB),
                    borderRadius: BorderRadius.circular(14),
                    onPressed: () async {
                      final mrp = double.tryParse(mrpController.text) ?? 0;
                      final taxRate = double.tryParse(taxController.text) ?? 0;
                      final updatedItem = BarcodeItem(
                        barcode: product['barcode'],
                        itemName: nameController.text.trim(),
                        mrp: mrp,
                        salePrice: mrp, // Sale Price = MRP
                        purchasePrice: 0,
                        taxRate: taxRate,
                        hsn: hsnController.text.trim(),
                        category: selectedCategory,
                        unit: selectedUnit,
                      );
                      Navigator.pop(sheetContext);
                      setState(() => _isLoading = true);
                      await _supabaseService.updateLibrary(updatedItem);
                      await _fetchProducts();
                    },
                    child: Text('Save Changes', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17)),
                  ),
                ),

              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCupertinoField(String label, TextEditingController controller, IconData icon, {bool isNumber = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey[500])),
        const SizedBox(height: 6),
        CupertinoTextField(
          controller: controller,
          keyboardType: isNumber ? TextInputType.number : TextInputType.text,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          prefix: Padding(
            padding: const EdgeInsets.only(left: 14),
            child: Icon(icon, size: 18, color: Colors.grey[400]),
          ),
          placeholder: label,
          placeholderStyle: GoogleFonts.outfit(color: Colors.grey[400]),
          style: GoogleFonts.outfit(fontSize: 15),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
        ),
      ],
    );
  }

  Widget _buildTapField(String label, String? value, IconData icon, VoidCallback onTap) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey[500])),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                Icon(icon, size: 18, color: Colors.grey[400]),
                const SizedBox(width: 10),
                Expanded(child: Text(value ?? 'Select', style: GoogleFonts.outfit(fontSize: 15, color: value == null ? Colors.grey[400] : Colors.black))),
                Icon(CupertinoIcons.chevron_down, size: 16, color: Colors.grey[400]),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showPickerSheet(BuildContext ctx, String title, List<String> items, String? current, Function(String) onSelect) {
    String searchQuery = '';
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          final filtered = items.where((i) => i.toLowerCase().contains(searchQuery.toLowerCase())).toList();
          return Container(
            decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 20, left: 20, right: 20, top: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2.5))),
                const SizedBox(height: 16),
                Text('Select $title', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                CupertinoSearchTextField(
                  onChanged: (val) => setSheetState(() => searchQuery = val),
                  placeholder: 'Search $title',
                  style: GoogleFonts.outfit(),
                ),
                const SizedBox(height: 12),
                ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.35),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: filtered.length,
                    separatorBuilder: (context, index) => Divider(height: 1, color: Colors.grey[200]),
                    itemBuilder: (context, index) {
                      final item = filtered[index];
                      final isSelected = item == current;
                      return CupertinoButton(
                        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                        onPressed: () {
                          onSelect(item);
                          Navigator.pop(context);
                        },
                        child: Row(
                          children: [
                            Expanded(child: Text(item, style: GoogleFonts.outfit(fontSize: 16, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, color: isSelected ? const Color(0xFF2563EB) : Colors.black87))),
                            if (isSelected) const Icon(CupertinoIcons.checkmark_circle_fill, color: Color(0xFF2563EB), size: 20),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _onboardNewItem(),
        backgroundColor: const Color(0xFF2563EB),
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: Text('New Product', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white)),
      ),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 120,
            pinned: true,
            centerTitle: true,
            backgroundColor: Colors.white,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.black),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              centerTitle: true,
              title: Text(
                'Product Master',
                style: GoogleFonts.outfit(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 18),
              ),
              titlePadding: const EdgeInsets.only(bottom: 16),
            ),
          ),
          
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: FadeInDown(
                duration: const Duration(milliseconds: 400),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4)),
                    ],
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: _filterProducts,
                    style: GoogleFonts.outfit(),
                    decoration: InputDecoration(
                      hintText: 'Search products or scan...',
                      hintStyle: GoogleFonts.outfit(color: Colors.grey[400]),
                      prefixIcon: Icon(Icons.search_rounded, color: Colors.grey[400]),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.barcode_reader, color: Color(0xFF2563EB)),
                        onPressed: _openScanner,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
              ),
            ),
          ),

          if (_isLoading)
            const SliverFillRemaining(child: Center(child: CupertinoActivityIndicator(radius: 12)))
          else if (_filteredProducts.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.inventory_2_outlined, size: 48, color: Colors.grey[300]),
                    const SizedBox(height: 16),
                    Text(_searchQuery.isEmpty ? "No products found" : "No results for '$_searchQuery'", style: GoogleFonts.outfit(color: Colors.grey[500], fontSize: 16)),
                    const SizedBox(height: 24),
                    if (_searchQuery.isNotEmpty) ...[
                      SizedBox(
                        width: 200,
                        child: OutlinedButton.icon(
                          onPressed: () => _onboardNewItem(_searchQuery),
                          icon: const Icon(Icons.add_rounded),
                          label: Text('Onboard this Item', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: 200,
                        child: TextButton.icon(
                          onPressed: () async {
                              setState(() => _isLoading = true);
                              final item = await _supabaseService.lookupBarcode(_searchQuery);
                              setState(() => _isLoading = false);
                              if (item != null) {
                                _showProductDetails(item.toJson());
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Not found in Master Library either'))
                                );
                              }
                          },
                          icon: const Icon(Icons.search_rounded),
                          label: Text('Search Master Library', style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final product = _filteredProducts[index];
                    return FadeInUp(
                      duration: const Duration(milliseconds: 300),
                      delay: Duration(milliseconds: index * 50),
                      child: GestureDetector(
                        onTap: () => _showProductDetails(product),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 48, height: 48,
                                decoration: BoxDecoration(color: const Color(0xFF2563EB).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                                child: const Icon(Icons.category_rounded, color: Color(0xFF2563EB), size: 24),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(product['item_name'] ?? 'Unknown Item', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16)),
                                    const SizedBox(height: 4),
                                    Text(product['barcode'] ?? 'No Barcode', style: GoogleFonts.outfit(color: Colors.grey[500], fontSize: 13)),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text('₹${product['mrp']?.toString() ?? '0.00'}', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: const Color(0xFF2563EB), fontSize: 16)),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text('${product['tax_rate'] ?? '0'}%', style: GoogleFonts.outfit(color: Colors.green, fontSize: 11, fontWeight: FontWeight.w600)),
                                      const SizedBox(width: 4),
                                      Text('TAX', style: GoogleFonts.outfit(color: Colors.grey[400], fontSize: 11)),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                  childCount: _filteredProducts.length,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
