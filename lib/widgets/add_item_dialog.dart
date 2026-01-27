import 'package:flutter/material.dart';
import '../models/barcode_item.dart';

class AddItemDialog extends StatefulWidget {
  final String barcode;
  const AddItemDialog({super.key, required this.barcode});

  @override
  State<AddItemDialog> createState() => _AddItemDialogState();
}

class _AddItemDialogState extends State<AddItemDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _mrpController;
  late TextEditingController _salePriceController;
  late TextEditingController _purchasePriceController;
  late TextEditingController _hsnController;
  late TextEditingController _skuController;
  String _category = 'Grocery';

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _mrpController = TextEditingController();
    _salePriceController = TextEditingController();
    _purchasePriceController = TextEditingController();
    _hsnController = TextEditingController();
    _skuController = TextEditingController();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        left: 24, right: 24, top: 30,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Add New Item', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('Collecting data for barcode: ${widget.barcode}', style: const TextStyle(color: Colors.grey)),
              const SizedBox(height: 24),
              _buildField(_nameController, 'Item Name', Icons.shopping_bag),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: _buildField(_mrpController, 'MRP', Icons.currency_rupee, keyboardType: TextInputType.number)),
                  const SizedBox(width: 16),
                  Expanded(child: _buildField(_salePriceController, 'Sale Price', Icons.sell, keyboardType: TextInputType.number)),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: _buildField(_hsnController, 'HSN', Icons.numbers)),
                  const SizedBox(width: 16),
                  Expanded(child: _buildField(_skuController, 'SKU', Icons.tag)),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text('Add to Library & Push', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildField(TextEditingController controller, String label, IconData icon, {TextInputType? keyboardType}) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: Colors.grey[50],
      ),
      validator: (value) => value!.isEmpty ? 'Required' : null,
    );
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      final item = BarcodeItem(
        barcode: widget.barcode,
        itemName: _nameController.text,
        mrp: double.parse(_mrpController.text),
        salePrice: double.parse(_salePriceController.text),
        purchasePrice: double.tryParse(_purchasePriceController.text) ?? 0,
        sku: _skuController.text,
        hsn: _hsnController.text,
        category: _category,
      );
      Navigator.pop(context, item);
    }
  }
}
