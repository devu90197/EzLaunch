import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/barcode_item.dart';
import '../services/supabase_service.dart';

class AddItemDialog extends StatefulWidget {
  final String barcode;
  const AddItemDialog({super.key, required this.barcode});

  @override
  State<AddItemDialog> createState() => _AddItemDialogState();
}

class _AddItemDialogState extends State<AddItemDialog> {
  final _formKey = GlobalKey<FormState>();
  final _supabaseService = SupabaseService();
  
  late TextEditingController _nameController;
  late TextEditingController _mrpController;
  late TextEditingController _hsnController;
  late TextEditingController _taxController;
  
  String? _category;
  String? _selectedUnit;
  
  List<String> _categories = [];
  List<String> _units = [];
  bool _isLoadingData = true;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _mrpController = TextEditingController();
    _hsnController = TextEditingController();
    _taxController = TextEditingController(text: '0');
    _loadMetadata();
  }

  Future<void> _loadMetadata() async {
    final cats = await _supabaseService.getCategories();
    final unts = await _supabaseService.getUnits();
    
    if (mounted) {
      setState(() {
        _categories = cats.map((e) => e['name'] as String).toList();
        _units = unts.map((e) => e['name'] as String).toList();
        
        if (_categories.isNotEmpty) _category = _categories[0];
        if (_units.isNotEmpty) _selectedUnit = _units[0];
        
        _isLoadingData = false;
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _mrpController.dispose();
    _hsnController.dispose();
    _taxController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        left: 24, right: 24, top: 12,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Apple Handle
          Container(
            width: 40,
            height: 5,
            decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2.5)),
          ),
          const SizedBox(height: 24),
          
          Flexible(
            child: SingleChildScrollView(
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Add New Item', style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold)),
                        IconButton(
                          onPressed: () => Navigator.pop(context), 
                          icon: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(color: Colors.grey[100], shape: BoxShape.circle),
                            child: const Icon(Icons.close, size: 20, color: Colors.grey),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text('Barcode: ${widget.barcode}', style: GoogleFonts.outfit(color: Colors.grey[500], fontSize: 14)),
                    const SizedBox(height: 32),
                    
                    _buildField(_nameController, 'Item Name', Icons.shopping_bag_outlined),
                    const SizedBox(height: 16),
                    
                    _buildField(_mrpController, 'MRP (Sale Price)', Icons.currency_rupee_rounded, keyboardType: TextInputType.number),
                    const SizedBox(height: 16),
                    
                    _buildField(_taxController, 'Tax Rate (%)', Icons.percent_rounded, keyboardType: TextInputType.number),
                    const SizedBox(height: 16),
                    
                    if (_isLoadingData)
                      const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()))
                    else
                      Row(
                        children: [
                          Expanded(
                            child: _buildSelectionField(
                              label: 'Category',
                              value: _category,
                              icon: Icons.category_outlined,
                              onTap: () => _showSelectionSheet(
                                title: 'Select Category',
                                items: _categories,
                                currentValue: _category,
                                onSelected: (val) => setState(() => _category = val),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildSelectionField(
                              label: 'Unit',
                              value: _selectedUnit,
                              icon: Icons.straighten_rounded,
                              onTap: () => _showSelectionSheet(
                                title: 'Select Unit',
                                items: _units,
                                currentValue: _selectedUnit,
                                onSelected: (val) => setState(() => _selectedUnit = val),
                              ),
                            ),
                          ),
                        ],
                      ),
                    
                    const SizedBox(height: 16),
                    _buildField(_hsnController, 'HSN Code', Icons.numbers_rounded, required: false),
                    
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 0,
                        ),
                        child: Text('Save to Global Library', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildField(TextEditingController controller, String label, IconData icon, {TextInputType? keyboardType, bool required = true}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey[700])),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          style: GoogleFonts.outfit(fontSize: 15),
          decoration: InputDecoration(
            prefixIcon: Icon(icon, size: 20, color: Colors.grey[400]),
            hintText: 'Enter $label',
            hintStyle: GoogleFonts.outfit(color: Colors.grey[400]),
            filled: true,
            fillColor: Colors.grey.withValues(alpha: 0.05),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.1))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.1))),
            contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
          ),
          validator: (value) => (required && (value == null || value.isEmpty)) ? 'Required' : null,
        ),
      ],
    );
  }

  void _showSelectionSheet({
    required String title,
    required List<String> items,
    required String? currentValue,
    required Function(String) onSelected,
  }) {
    String searchQuery = "";
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          final filteredItems = items
              .where((item) => item.toLowerCase().contains(searchQuery.toLowerCase()))
              .toList();

          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
            ),
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              left: 20, right: 20, top: 12,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2.5))),
                const SizedBox(height: 24),
                Text(title, style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                
                // Sheet Search Bar
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
                  ),
                  child: TextField(
                    onChanged: (val) => setModalState(() => searchQuery = val),
                    style: GoogleFonts.outfit(fontSize: 15),
                    decoration: InputDecoration(
                      hintText: 'Search $title...',
                      hintStyle: GoogleFonts.outfit(color: Colors.grey[400]),
                      prefixIcon: Icon(Icons.search_rounded, size: 20, color: Colors.grey[400]),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                
                ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.4),
                  child: filteredItems.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.symmetric(vertical: 40),
                        child: Text('No results match your search', style: GoogleFonts.outfit(color: Colors.grey[400])),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        itemCount: filteredItems.length,
                        separatorBuilder: (context, index) => Divider(color: Colors.grey.withValues(alpha: 0.1), height: 1),
                        itemBuilder: (context, index) {
                          final item = filteredItems[index];
                          final isSelected = item == currentValue;
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            title: Text(item, style: GoogleFonts.outfit(
                              fontSize: 16, 
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              color: isSelected ? const Color(0xFF2563EB) : Colors.black87,
                            )),
                            trailing: isSelected ? const Icon(Icons.check_circle_rounded, color: Color(0xFF2563EB)) : null,
                            onTap: () {
                              onSelected(item);
                              Navigator.pop(context);
                            },
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

  Widget _buildSelectionField({required String label, required String? value, required VoidCallback onTap, required IconData icon}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey[700])),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
            ),
            child: Row(
              children: [
                Icon(icon, size: 20, color: Colors.grey[400]),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    value ?? 'Select $label',
                    style: GoogleFonts.outfit(
                      fontSize: 15, 
                      color: value == null ? Colors.grey[400] : Colors.black,
                    ),
                  ),
                ),
                Icon(Icons.keyboard_arrow_down_rounded, color: Colors.grey[400], size: 20),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      final mrp = double.tryParse(_mrpController.text) ?? 0;
      final taxRate = double.tryParse(_taxController.text) ?? 0;
      final item = BarcodeItem(
        barcode: widget.barcode,
        itemName: _nameController.text.trim(),
        mrp: mrp,
        salePrice: mrp, // Sale Price = MRP
        purchasePrice: 0, // Not used
        taxRate: taxRate,
        hsn: _hsnController.text.trim(),
        category: _category,
        unit: _selectedUnit,
      );
      Navigator.pop(context, item);
    }
  }
}
