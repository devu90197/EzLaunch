import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../services/supabase_service.dart';
import '../models/barcode_item.dart';
import 'edit_item_screen.dart';
import '../widgets/add_item_dialog.dart';

class ScannerScreen extends StatefulWidget {
  final String mode; // 'Library' or 'Fresh'
  const ScannerScreen({super.key, required this.mode});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  final SupabaseService _supabaseService = SupabaseService();
  bool _isProcessing = false;
  final MobileScannerController _controller = MobileScannerController(
    formats: [BarcodeFormat.code128, BarcodeFormat.ean13],
  );

  void _onDetect(BarcodeCapture capture) async {
    if (_isProcessing) return;

    final barcode = capture.barcodes.first.rawValue;
    if (barcode == null) return;

    setState(() => _isProcessing = true);
    _controller.stop();

    _showBarcodeDetectedPreview(barcode);
  }

  void _showBarcodeDetectedPreview(String barcode) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.qr_code_2_rounded, size: 64, color: Colors.blue),
            const SizedBox(height: 16),
            const Text('Barcode Detected', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(10)),
              child: Text(barcode, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 2)),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  if (widget.mode == 'Library') {
                    _processLibraryLookup(barcode);
                  } else {
                    _handleNotFound(barcode); // Go straight to add in Fresh Mode
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4F46E5),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text('Proceed to Add Details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _resumeScanner();
              },
              child: const Text('Scan Again'),
            ),
          ],
        ),
      ),
    );
  }

  void _processLibraryLookup(String barcode) async {
    final item = await _supabaseService.lookupBarcode(barcode);
    if (item != null) {
      _showItemFoundActions(item);
    } else {
      _handleNotFound(barcode);
    }
  }

  void _handleNotFound(String barcode) async {
    final newItem = await showModalBottomSheet<BarcodeItem>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddItemDialog(barcode: barcode),
    );

    if (newItem != null) {
      await _supabaseService.updateLibrary(newItem);
      await _supabaseService.pushToClient(item: newItem, businessId: 'CLIENT_123');
      _showSuccessSnackBar('Saved to library and pushed to client!');
    }
    _resumeScanner();
  }

  void _showItemFoundActions(BarcodeItem item, {bool isFreshMode = false}) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 48),
            const SizedBox(height: 16),
            Text(item.itemName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            Text('Barcode: ${item.barcode}', style: TextStyle(color: Colors.grey[600])),
            const SizedBox(height: 8),
            Text('MRP: ₹${item.mrp} | Sale: ₹${item.salePrice}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const Divider(height: 32),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _editItem(item),
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Edit'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _pushItem(item),
                    icon: const Icon(Icons.send_rounded),
                    label: const Text('Push to Client'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4F46E5),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ],
        ),
      ),
    ).then((_) => _resumeScanner());
  }

  Future<void> _editItem(BarcodeItem item) async {
    Navigator.pop(context); // Close sheet
    final updatedItem = await Navigator.push<BarcodeItem>(
      context,
      MaterialPageRoute(builder: (context) => EditItemScreen(item: item)),
    );

    if (updatedItem != null) {
      _askUpdateTarget(updatedItem);
    }
  }

  void _askUpdateTarget(BarcodeItem item) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Save Changes'),
        content: const Text('Where do you want to update these changes?'),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _supabaseService.pushToClient(item: item, businessId: 'CLIENT_123');
              _showSuccessSnackBar('Updated local price and pushed to client.');
            },
            child: const Text('Local Only'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _supabaseService.updateLibrary(item);
              await _supabaseService.pushToClient(item: item, businessId: 'CLIENT_123');
              _showSuccessSnackBar('Updated global library and pushed to client!');
            },
            child: const Text('Global Library + Client'),
          ),
        ],
      ),
    );
  }

  Future<void> _pushItem(BarcodeItem item) async {
    Navigator.pop(context);
    await _supabaseService.pushToClient(item: item, businessId: 'CLIENT_123');
    _showSuccessSnackBar('Item pushed to billing software successfully.');
  }

  void _resumeScanner() {
    setState(() => _isProcessing = false);
    _controller.start();
  }

  void _showSuccessSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.green),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text('Onboarding: ${widget.mode}'),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            errorBuilder: (context, error, child) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 64),
                    const SizedBox(height: 16),
                    Text(
                      'Scanner Error: ${error.errorCode}',
                      style: const TextStyle(color: Colors.white),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: () => _controller.start(),
                      child: const Text('Retry Scanner'),
                    ),
                  ],
                ),
              );
            },
          ),
          // Scanner Overlay
          Center(
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white.withOpacity(0.5), width: 2),
                borderRadius: BorderRadius.circular(40),
              ),
              child: Stack(
                children: [
                  _buildCorner(0, 0, isTop: true, isBottom: false, isLeft: true, isRight: false),
                  _buildCorner(null, 0, isTop: true, isBottom: false, isLeft: false, isRight: true),
                  _buildCorner(0, null, isTop: false, isBottom: true, isLeft: true, isRight: false),
                  _buildCorner(null, null, isTop: false, isBottom: true, isLeft: false, isRight: true),
                ],
              ),
            ),
          ),
          // Instruction Overlay
          Positioned(
            bottom: 80,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Align Barcode (Code 128 / EAN 13) within the frame',
                  style: TextStyle(color: Colors.white, fontSize: 14),
                ),
              ),
            ),
          ),
          if (_isProcessing)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: const Center(
                child: CircularProgressIndicator(color: Colors.blue),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCorner(double? leftPos, double? topPos, {required bool isTop, required bool isBottom, required bool isLeft, required bool isRight}) {
    return Positioned(
      top: isTop ? 0 : null,
      bottom: isBottom ? 0 : null,
      left: isLeft ? 0 : null,
      right: isRight ? 0 : null,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          border: Border(
            top: isTop ? const BorderSide(color: Colors.blue, width: 4) : BorderSide.none,
            bottom: isBottom ? const BorderSide(color: Colors.blue, width: 4) : BorderSide.none,
            left: isLeft ? const BorderSide(color: Colors.blue, width: 4) : BorderSide.none,
            right: isRight ? const BorderSide(color: Colors.blue, width: 4) : BorderSide.none,
          ),
        ),
      ),
    );
  }
}
