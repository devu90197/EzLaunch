import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';
import '../services/supabase_service.dart';
import '../services/local_storage_service.dart';
import '../models/barcode_item.dart';
import 'edit_item_screen.dart';
import '../widgets/add_item_dialog.dart';


class ScannerScreen extends StatefulWidget {
  final String mode; // 'Library', 'Fresh', or 'Lookup'
  final String? businessId;
  final String? branchId;
  
  const ScannerScreen({
    super.key, 
    required this.mode, 
    this.businessId, 
    this.branchId
  });

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  final SupabaseService _supabaseService = SupabaseService();
  final LocalStorageService _localStorage = LocalStorageService();
  bool _isProcessing = false;
  final List<BarcodeItem> _scannedItems = [];
  final Set<String> _pendingBarcodes = {}; // To prevent double-processing during rapid scan
  final MobileScannerController _controller = MobileScannerController(
    formats: [BarcodeFormat.code128, BarcodeFormat.ean13, BarcodeFormat.ean8],
  );

  void _onDetect(BarcodeCapture capture) async {
    if (_isProcessing) return;

    final barcode = capture.barcodes.first.rawValue?.trim();
    if (barcode == null || barcode.isEmpty) return;

    // 1. Check if already in session list
    if (_scannedItems.any((item) => item.barcode == barcode)) {
      return; // Silently ignore already scanned items for "rapid" feel
    }

    // 2. Check if currently being looked up
    if (_pendingBarcodes.contains(barcode)) return;

    if (widget.mode == 'Lookup') {
      setState(() => _isProcessing = true);
      _controller.stop();
      Navigator.pop(context, barcode);
      return;
    }

    // Rapid Scan Mode: Don't stop controller immediately for known items
    // But we need to handle "not found" which requires stopping
    _pendingBarcodes.add(barcode);
    
    try {
      final item = await _supabaseService.lookupBarcode(barcode);
      _pendingBarcodes.remove(barcode);

      if (!mounted) return;

      if (item != null) {
        // LOG: Found in library
        _supabaseService.logOnboardingEvent(barcode: barcode, status: 'found');
        
        setState(() {
          _scannedItems.add(item);
        });
        _saveCurrentQueue();
        _showSuccessSnackBar('Added: ${item.itemName}');
      } else {
        // LOG: Not found in library
        _supabaseService.logOnboardingEvent(barcode: barcode, status: 'not_found');
        
        // Stop scanner only when item is NOT found to show the "Create" flow
        setState(() => _isProcessing = true);
        _controller.stop();
        _handleNotFound(barcode);
      }
    } catch (e) {
      _pendingBarcodes.remove(barcode);
    }
  }

  void _showErrorSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

  void _showReviewSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Container(
          height: MediaQuery.of(context).size.height * 0.7,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2.5))),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Text('Review Scanned Items', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold)),
                    const Spacer(),
                    Text('${_scannedItems.length} items', style: GoogleFonts.outfit(color: Colors.blue, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              Expanded(
                child: _scannedItems.isEmpty
                    ? Center(child: Text('No items scanned yet', style: GoogleFonts.outfit(color: Colors.grey)))
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        itemCount: _scannedItems.length,
                        itemBuilder: (context, index) {
                          final item = _scannedItems[index];
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: (Colors.grey[50] ?? Colors.white).withOpacity(0.5),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey.withOpacity(0.1)),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(item.itemName, style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
                                      Text(item.barcode, style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey)),
                                    ],
                                  ),
                                ),
                                CupertinoButton(
                                  padding: EdgeInsets.zero,
                                  onPressed: () {
                                    setState(() {
                                      _scannedItems.removeAt(index);
                                    });
                                    _saveCurrentQueue();
                                    setSheetState(() {});
                                  },
                                  child: const Icon(CupertinoIcons.trash, color: Colors.red, size: 20),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: Text('Keep Scanning', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleNotFound(String barcode) async {
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
              decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), shape: BoxShape.circle),
              child: const Icon(Icons.inventory_2_outlined, size: 40, color: Colors.orange),
            ),
            const SizedBox(height: 16),
            Text('Item Not Found', style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('This item isn\'t in the library yet.\nWould you like to onboard it now?', 
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
                child: Text('Start Onboarding', style: GoogleFonts.outfit(fontSize: 17, fontWeight: FontWeight.bold)),
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

    if (proceed != true) {
      _resumeScanner();
      return;
    }

    if (!mounted) return;

    final newItem = await showModalBottomSheet<BarcodeItem>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddItemDialog(barcode: barcode),
    );

    if (newItem != null) {
      // LOG: Added new item
      _supabaseService.logOnboardingEvent(barcode: barcode, status: 'added');
      
      setState(() {
        _scannedItems.add(newItem);
      });
      _saveCurrentQueue();
      _showSuccessSnackBar('Item added to session queue');
    }
    _resumeScanner();
  }

  Future<void> _syncAllScanned() async {
    if (_scannedItems.isEmpty) return;

    setState(() => _isProcessing = true);
    _controller.stop();

    try {
      // 1. Update Library (Upsert all to Product Master)
      await _supabaseService.updateLibraryBatch(_scannedItems);

      int totalToSync = _scannedItems.length;
      int actualSynced = 0;

      // 2. Sync to Billify V2 if target selected
      if (widget.businessId != null && widget.branchId != null) {
        const int batchSize = 250;
        for (int i = 0; i < _scannedItems.length; i += batchSize) {
          final int end = (i + batchSize < _scannedItems.length) ? i + batchSize : _scannedItems.length;
          final List<BarcodeItem> batch = _scannedItems.sublist(i, end);
          
          final result = await _supabaseService.syncToBillifyV2(
            companyId: widget.businessId!,
            branchId: widget.branchId!,
            items: batch,
          );
          
          final results = result['results'] ?? result;
          actualSynced += (results['success_count'] as num?)?.toInt() ?? batch.length;
        }
      } else {
        actualSynced = totalToSync;
      }

      setState(() {
        _scannedItems.clear();
      });

      if (widget.businessId != null && widget.branchId != null) {
        await _localStorage.clearScanQueue(widget.businessId!, widget.branchId!);
      }
      
      if (mounted) {
        _showSyncSuccessOverlay(actualSynced);
      }
    } catch (e) {
      _showErrorSnackBar('Sync failed: $e');
      if (mounted) _resumeScanner();
    } finally {
      // Logic moved to overlay dismissal
    }
  }

  void _showSyncSuccessOverlay(int count) {
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.9),
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (context, anim1, anim2) {
        return Scaffold(
          backgroundColor: Colors.transparent,
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ZoomIn(
                  duration: const Duration(milliseconds: 600),
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: const BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check_rounded, color: Colors.white, size: 80),
                  ),
                ),
                const SizedBox(height: 32),
                FadeInUp(
                  duration: const Duration(milliseconds: 600),
                  delay: const Duration(milliseconds: 400),
                  child: Text(
                    'Sync Successful!',
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                FadeInUp(
                  duration: const Duration(milliseconds: 600),
                  delay: const Duration(milliseconds: 600),
                  child: Text(
                    '$count items synced to your shop',
                    style: GoogleFonts.outfit(
                      color: Colors.white70,
                      fontSize: 18,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    // Auto dismiss and exit
    Future.delayed(const Duration(milliseconds: 2200), () {
      if (mounted) {
        Navigator.pop(context); // Close dialog
        Navigator.pop(context); // Exit scanner
      }
    });
  }


  void _showItemFoundActions(BarcodeItem item) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
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
          children: [
            // iOS Handle
            Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2.5))),
            const SizedBox(height: 20),
            
            // Success Icon
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(CupertinoIcons.checkmark_circle_fill, color: Colors.green, size: 48),
            ),
            const SizedBox(height: 16),
            
            // Item Info
            Text(item.itemName, style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
            const SizedBox(height: 4),
            Text('Barcode: ${item.barcode}', style: GoogleFonts.outfit(color: Colors.grey[500], fontSize: 14)),
            const SizedBox(height: 12),
            
            // Price & Tax Badges
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text('MRP: ₹${item.mrp}', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18, color: const Color(0xFF2563EB))),
                ),
                if (item.taxRate != null) ...[
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text('Tax: ${item.taxRate}%', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.green)),
                  ),
                ],
              ],
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
                    onPressed: () => _editItem(item),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(CupertinoIcons.pencil, color: Color(0xFF64748B), size: 20),
                        const SizedBox(width: 8),
                        Text('Edit', style: GoogleFonts.outfit(color: const Color(0xFF64748B), fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: CupertinoButton(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    color: const Color(0xFF2563EB),
                    borderRadius: BorderRadius.circular(14),
                    onPressed: () => _pushItem(item),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(CupertinoIcons.cloud_upload_fill, color: Colors.white, size: 20),
                        const SizedBox(width: 8),
                        Text('Push', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            // Cancel
            CupertinoButton(
              onPressed: () => Navigator.pop(sheetContext),
              child: Text('Cancel', style: GoogleFonts.outfit(color: Colors.grey[500], fontWeight: FontWeight.w600)),
            ),
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
    if (widget.businessId == null || widget.branchId == null) return;
    
    showCupertinoDialog(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: const Text('Save Changes'),
        content: const Text('Where do you want to save these changes?'),
        actions: [
          CupertinoDialogAction(
            onPressed: () async {
              Navigator.pop(dialogContext);
              await _supabaseService.pushToClient(
                item: item, 
                businessId: widget.businessId!, 
                branchId: widget.branchId!,
              );
              _showSuccessSnackBar('Pushed to client only.');
            },
            child: const Text('Client Only'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () async {
              Navigator.pop(dialogContext);
              await _supabaseService.updateLibrary(item);
              await _supabaseService.pushToClient(
                item: item, 
                businessId: widget.businessId!, 
                branchId: widget.branchId!,
              );
              _showSuccessSnackBar('Updated library & pushed to client!');
            },
            child: const Text('Library + Client'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );

  }

  Future<void> _pushItem(BarcodeItem item) async {
    if (widget.businessId == null || widget.branchId == null) return;
    Navigator.pop(context);
    await _supabaseService.pushToClient(
      item: item, 
      businessId: widget.businessId!, 
      branchId: widget.branchId!,
    );
    _showSuccessSnackBar('Item pushed to billing software successfully.');
  }

  @override
  void initState() {
    super.initState();
    _loadPersistedQueue();
  }

  Future<void> _loadPersistedQueue() async {
    if (widget.businessId != null && widget.branchId != null) {
      final items = await _localStorage.loadScanQueue(widget.businessId!, widget.branchId!);
      if (items.isNotEmpty) {
        setState(() {
          _scannedItems.addAll(items);
        });
        _showSuccessSnackBar('Restored ${items.length} items from previous session');
      }
    }
  }

  Future<void> _saveCurrentQueue() async {
    if (widget.businessId != null && widget.branchId != null) {
      await _localStorage.saveScanQueue(widget.businessId!, widget.branchId!, _scannedItems);
    }
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
        title: Text(widget.mode == 'Lookup' ? 'Scan Barcode' : 'Onboarding: ${widget.mode}', 
          style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 18)
        ),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
          ),
          
          // Cinematic Overlay
          Container(
            decoration: ShapeDecoration(
              shape: _ScannerOverlayShape(
                borderColor: const Color(0xFF2563EB),
                borderRadius: 32,
                borderLength: 40,
                borderWidth: 5,
                cutOutSize: 320,
                cutOutHeight: 160,
              ),
            ),
          ),
          
          // Instruction Overlay
          Positioned(
            bottom: MediaQuery.of(context).size.height * 0.2,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.65),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.barcode_reader, color: Colors.white, size: 18),
                    const SizedBox(width: 12),
                    Text(
                      'Rapid Scan Mode Active',
                      style: GoogleFonts.outfit(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          // Review Button (Top Right)
          if (_scannedItems.isNotEmpty)
            Positioned(
              top: 100,
              right: 20,
              child: FadeInRight(
                child: CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: _showReviewSheet,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(CupertinoIcons.list_bullet, color: Colors.black, size: 20),
                        const SizedBox(width: 8),
                        Text('Review (${_scannedItems.length})', style: GoogleFonts.outfit(color: Colors.black, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          
          if (_isProcessing)
            Container(
              color: Colors.black.withOpacity(0.4),
              child: const Center(
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
              ),
            ),

          // Bottom Session Summary & Sync Button
          if (_scannedItems.isNotEmpty && !_isProcessing)
            Positioned(
              bottom: 30,
              left: 20,
              right: 20,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Session List Preview (Short)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${_scannedItems.length} items ready to sync',
                      style: GoogleFonts.outfit(color: Colors.white70, fontSize: 13),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 60,
                    child: ElevatedButton.icon(
                      onPressed: _syncAllScanned,
                      icon: const Icon(CupertinoIcons.cloud_upload_fill),
                      label: Text('Sync Bulk (${_scannedItems.length})', 
                        style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold)
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                        elevation: 8,
                        shadowColor: const Color(0xFF2563EB).withOpacity(0.5),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ScannerOverlayShape extends ShapeBorder {
  final Color borderColor;
  final double borderWidth;
  final double borderRadius;
  final double borderLength;
  final double cutOutSize;
  final double cutOutHeight;

  const _ScannerOverlayShape({
    this.borderColor = Colors.white,
    this.borderWidth = 4.0,
    this.borderRadius = 0,
    this.borderLength = 40,
    this.cutOutSize = 250,
    this.cutOutHeight = 250,
  });

  @override
  EdgeInsetsGeometry get dimensions => const EdgeInsets.all(10);

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) => Path();

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) => Path()..addRect(rect);

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    final width = rect.width;
    final height = rect.height;

    final cutOutRect = Rect.fromCenter(
      center: Offset(width / 2, height / 2),
      width: cutOutSize,
      height: cutOutHeight,
    );

    final backgroundPaint = Paint()
      ..color = Colors.black.withOpacity(0.7)
      ..style = PaintingStyle.fill;

    final path = Path()
      ..addRect(rect)
      ..addRRect(RRect.fromRectAndRadius(cutOutRect, Radius.circular(borderRadius)))
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(path, backgroundPaint);

    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth
      ..strokeCap = StrokeCap.round;

    final RRect rrect = RRect.fromRectAndRadius(cutOutRect, Radius.circular(borderRadius));

    // Top Left
    canvas.drawPath(
      Path()
        ..moveTo(rrect.left, rrect.top + borderLength)
        ..lineTo(rrect.left, rrect.top + borderRadius)
        ..arcToPoint(Offset(rrect.left + borderRadius, rrect.top), radius: Radius.circular(borderRadius))
        ..lineTo(rrect.left + borderLength, rrect.top),
      borderPaint,
    );

    // Top Right
    canvas.drawPath(
      Path()
        ..moveTo(rrect.right - borderLength, rrect.top)
        ..lineTo(rrect.right - borderRadius, rrect.top)
        ..arcToPoint(Offset(rrect.right, rrect.top + borderRadius), radius: Radius.circular(borderRadius))
        ..lineTo(rrect.right, rrect.top + borderLength),
      borderPaint,
    );

    // Bottom Left
    canvas.drawPath(
      Path()
        ..moveTo(rrect.left + borderLength, rrect.bottom)
        ..lineTo(rrect.left + borderRadius, rrect.bottom)
        ..arcToPoint(Offset(rrect.left, rrect.bottom - borderRadius), radius: Radius.circular(borderRadius))
        ..lineTo(rrect.left, rrect.bottom - borderLength),
      borderPaint,
    );

    // Bottom Right
    canvas.drawPath(
      Path()
        ..moveTo(rrect.right, rrect.bottom - borderLength)
        ..lineTo(rrect.right, rrect.bottom - borderRadius)
        ..arcToPoint(Offset(rrect.right - borderRadius, rrect.bottom), radius: Radius.circular(borderRadius))
        ..lineTo(rrect.right - borderLength, rrect.bottom),
      borderPaint,
    );
  }

  @override
  ShapeBorder scale(double t) => this;
}
