import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';
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
  late TextEditingController _hsnController;
  late TextEditingController _brandController;
  late TextEditingController _taxController;
  late TextEditingController _notesController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.item.itemName);
    _mrpController = TextEditingController(text: widget.item.mrp.toString());
    _hsnController = TextEditingController(text: widget.item.hsn);
    _brandController = TextEditingController(text: widget.item.brand);
    _taxController = TextEditingController(text: widget.item.taxRate?.toString() ?? '0');
    _notesController = TextEditingController(text: widget.item.notes);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _mrpController.dispose();
    _hsnController.dispose();
    _brandController.dispose();
    _taxController.dispose();
    _notesController.dispose();
    super.dispose();
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
        title: Text('Edit Item', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.black)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Barcode Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  const Icon(CupertinoIcons.barcode, color: Color(0xFF2563EB), size: 24),
                  const SizedBox(width: 12),
                  Text(widget.item.barcode, style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18, color: const Color(0xFF2563EB))),
                ],
              ),
            ),
            const SizedBox(height: 24),
            
            // Basic Info Section
            Text('BASIC INFO', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey[400], letterSpacing: 1.2)),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
              ),
              child: Column(
                children: [
                  _buildCupertinoField('Item Name', _nameController, CupertinoIcons.bag),
                  Divider(height: 1, color: Colors.grey[100]),
                  _buildCupertinoField('Brand', _brandController, CupertinoIcons.tag),
                ],
              ),
            ),
            const SizedBox(height: 24),
            
            // Pricing Section
            Text('PRICING', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey[400], letterSpacing: 1.2)),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
              ),
              child: Column(
                children: [
                  _buildCupertinoField('MRP (Sale Price)', _mrpController, Icons.currency_rupee_rounded, isNumber: true),
                  Divider(height: 1, color: Colors.grey[100]),
                  _buildCupertinoField('Tax Rate (%)', _taxController, CupertinoIcons.percent, isNumber: true),
                  Divider(height: 1, color: Colors.grey[100]),
                  _buildCupertinoField('HSN Code', _hsnController, CupertinoIcons.number),
                ],
              ),
            ),
            const SizedBox(height: 24),
            
            // Notes Section
            Text('NOTES', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey[400], letterSpacing: 1.2)),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
              ),
              padding: const EdgeInsets.all(16),
              child: CupertinoTextField(
                controller: _notesController,
                placeholder: 'Internal notes (optional)',
                placeholderStyle: GoogleFonts.outfit(color: Colors.grey[400]),
                style: GoogleFonts.outfit(),
                maxLines: 3,
                decoration: null,
                padding: EdgeInsets.zero,
              ),
            ),
            
            const SizedBox(height: 40),
            
            // Save Button
            SizedBox(
              width: double.infinity,
              child: CupertinoButton(
                padding: const EdgeInsets.symmetric(vertical: 18),
                color: const Color(0xFF2563EB),
                borderRadius: BorderRadius.circular(14),
                onPressed: _save,
                child: Text('Save Changes', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17)),
              ),
            ),
            const SizedBox(height: 16),
            
            // Cancel Button
            SizedBox(
              width: double.infinity,
              child: CupertinoButton(
                padding: const EdgeInsets.symmetric(vertical: 18),
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(14),
                onPressed: () => Navigator.pop(context),
                child: Text('Cancel', style: GoogleFonts.outfit(color: const Color(0xFF64748B), fontWeight: FontWeight.w600, fontSize: 17)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCupertinoField(String label, TextEditingController controller, IconData icon, {bool isNumber = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Icon(icon, size: 22, color: Colors.grey[400]),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey[500])),
                const SizedBox(height: 4),
                CupertinoTextField(
                  controller: controller,
                  placeholder: 'Enter $label',
                  placeholderStyle: GoogleFonts.outfit(color: Colors.grey[300]),
                  style: GoogleFonts.outfit(fontSize: 16),
                  keyboardType: isNumber ? TextInputType.number : TextInputType.text,
                  decoration: null,
                  padding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _save() {
    final mrp = double.tryParse(_mrpController.text) ?? 0;
    final taxRate = double.tryParse(_taxController.text) ?? 0;
    final updatedItem = widget.item.copyWith(
      itemName: _nameController.text,
      brand: _brandController.text,
      hsn: _hsnController.text,
      mrp: mrp,
      salePrice: mrp, // Sale Price = MRP
      purchasePrice: 0,
      taxRate: taxRate,
      notes: _notesController.text,
    );
    Navigator.pop(context, updatedItem);
  }
}
