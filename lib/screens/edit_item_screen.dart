import 'package:flutter/material.dart';
import '../models/barcode_item.dart';

class EditItemScreen extends StatefulWidget {
  final BarcodeItem item;
  const EditItemScreen({super.key, required this.item});

  @override
  State<EditItemScreen> createState() => _EditItemScreenState();
}

class _EditItemScreenState extends State<EditItemScreen> {
  late TextEditingController _nameController;
  late TextEditingController _mrpController;
  late TextEditingController _salePriceController;
  late TextEditingController _purchasePriceController;
  late TextEditingController _skuController;
  late TextEditingController _hsnController;
  late TextEditingController _brandController;
  late TextEditingController _notesController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.item.itemName);
    _mrpController = TextEditingController(text: widget.item.mrp.toString());
    _salePriceController = TextEditingController(text: widget.item.salePrice.toString());
    _purchasePriceController = TextEditingController(text: widget.item.purchasePrice.toString());
    _skuController = TextEditingController(text: widget.item.sku);
    _hsnController = TextEditingController(text: widget.item.hsn);
    _brandController = TextEditingController(text: widget.item.brand);
    _notesController = TextEditingController(text: widget.item.notes);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Item Details')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            _buildSectionTitle('Basic Info'),
            _buildField(_nameController, 'Item Name', Icons.shopping_bag_outlined),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _buildField(_brandController, 'Brand', Icons.workspace_premium_outlined)),
                const SizedBox(width: 16),
                Expanded(child: _buildField(_skuController, 'SKU', Icons.tag)),
              ],
            ),
            const SizedBox(height: 16),
            _buildField(_hsnController, 'HSN Code', Icons.numbers),
            
            const SizedBox(height: 32),
            _buildSectionTitle('Pricing & Tax'),
            Row(
              children: [
                Expanded(child: _buildField(_mrpController, 'MRP', Icons.currency_rupee, keyboardType: TextInputType.number)),
                const SizedBox(width: 16),
                Expanded(child: _buildField(_salePriceController, 'Sale Price', Icons.sell_outlined, keyboardType: TextInputType.number)),
              ],
            ),
            const SizedBox(height: 16),
            _buildField(_purchasePriceController, 'Purchase Price', Icons.shopping_cart_outlined, keyboardType: TextInputType.number),
            
            const SizedBox(height: 32),
            _buildSectionTitle('Additional Details'),
            _buildField(_notesController, 'Internal Notes (Optional)', Icons.notes, maxLines: 3),
            
            const SizedBox(height: 48),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text('Save Changes', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _save() {
    final updatedItem = widget.item.copyWith(
      itemName: _nameController.text,
      brand: _brandController.text,
      sku: _skuController.text,
      hsn: _hsnController.text,
      mrp: double.tryParse(_mrpController.text) ?? 0,
      salePrice: double.tryParse(_salePriceController.text) ?? 0,
      purchasePrice: double.tryParse(_purchasePriceController.text) ?? 0,
      notes: _notesController.text,
    );
    Navigator.pop(context, updatedItem);
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(width: 8),
          const Expanded(child: Divider()),
        ],
      ),
    );
  }

  Widget _buildField(TextEditingController controller, String label, IconData icon, {TextInputType? keyboardType, int maxLines = 1}) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: Colors.grey[50],
      ),
    );
  }
}
