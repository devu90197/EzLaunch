import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'dart:ui';
import 'package:animate_do/animate_do.dart';
import 'package:google_fonts/google_fonts.dart';
import 'scanner_screen.dart';
import 'login_screen.dart';
import 'product_list_screen.dart';
import 'library_sync_screen.dart';
import '../services/supabase_service.dart';
import '../services/local_storage_service.dart';


class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final SupabaseService _supabaseService = SupabaseService();
  final LocalStorageService _localStorage = LocalStorageService();
  String _onboardingMode = 'Fresh'; // 'Fresh' or 'Library'
  
  List<Map<String, dynamic>> _companies = [];
  List<Map<String, dynamic>> _branches = [];
  String? _selectedCompanyId;
  String? _selectedBranchId; // 'all' for all branches
  bool _isLoadingData = true;
  List<Map<String, dynamic>> _recentItems = [];
  int _pendingDraftCount = 0;

  final Color _appleAccent = const Color(0xFF2563EB);

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkUserName());
  }

  void _checkUserName() {
    final name = _supabaseService.getUserDisplayName();
    if (name == null || name.isEmpty) {
      _showNameDialog();
    }
  }

  void _showNameDialog() {
    final controller = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      enableDrag: false,
      isDismissible: false,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 32,
          left: 28, right: 28, top: 12,
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
            const SizedBox(height: 32),
            
            // Icon Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _appleAccent.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.person_outline_rounded, size: 40, color: _appleAccent),
            ),
            const SizedBox(height: 24),
            
            Text(
              'Welcome to EzLaunch',
              style: GoogleFonts.outfit(fontSize: 26, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Please enter your name to complete\nyour operator profile set-up.',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(color: Colors.grey[500], fontSize: 16),
            ),
            
            const SizedBox(height: 40),
            
            // iOS Styled Input
            Container(
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
              ),
              child: TextField(
                controller: controller,
                autofocus: true,
                style: GoogleFonts.outfit(fontSize: 17),
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  hintText: 'Full Name',
                  hintStyle: GoogleFonts.outfit(color: Colors.grey[400]),
                  prefixIcon: Icon(Icons.badge_outlined, color: Colors.grey[400]),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 18),
                ),
              ),
            ),
            
            const SizedBox(height: 32),
            
            // Primary Button
            SizedBox(
              width: double.infinity,
              height: 58,
              child: ElevatedButton(
                onPressed: () async {
                  if (controller.text.trim().isNotEmpty) {
                    await _supabaseService.updateUserDisplayName(controller.text.trim());
                    if (!context.mounted) return;
                    Navigator.pop(context);
                    setState(() {}); 
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _appleAccent,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: Text(
                  'Complete Setup',
                  style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoadingData = true);
    final companies = await _supabaseService.getCompanies();
    setState(() {
      _companies = companies;
      _isLoadingData = false;
      
      if (_companies.length == 1) {
        _selectedCompanyId = _companies[0]['id'].toString();
        _loadBranches(_selectedCompanyId!);
        _loadRecentItems();
      }
    });
  }

  Future<void> _loadRecentItems() async {
    if (_selectedCompanyId == null) return;
    final items = await _supabaseService.getSyncedItems(
      _selectedCompanyId!, 
      _selectedBranchId ?? 'all'
    );
    setState(() {
      _recentItems = items;
    });
    _checkLocalDrafts();
  }

  Future<void> _checkLocalDrafts() async {
    if (_selectedCompanyId == null || _selectedBranchId == null) return;
    final items = await _localStorage.loadScanQueue(_selectedCompanyId!, _selectedBranchId!);
    setState(() {
      _pendingDraftCount = items.length;
    });
  }

  Future<void> _loadBranches(String companyId) async {
    setState(() => _isLoadingData = true);
    final branches = await _supabaseService.getBranches(companyId);
    setState(() {
      _branches = branches;
      _isLoadingData = false;
      
      if (_branches.length == 1) {
        _selectedBranchId = _branches[0]['id'].toString();
      } else if (_branches.isNotEmpty) {
        _selectedBranchId = 'all';
      }
    });
  }

  void _showCompanyPicker() {
    String searchQuery = "";
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          final filteredCompanies = _companies.where((c) => 
            c['name'].toString().toLowerCase().contains(searchQuery.toLowerCase())
          ).toList();

          return _AppleSheet(
            title: 'Select Company',
            searchHint: 'Search companies...',
            onSearchChanged: (val) => setSheetState(() => searchQuery = val),
            child: filteredCompanies.isEmpty 
              ? _buildEmptySearchState()
              : ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: filteredCompanies.length,
                  separatorBuilder: (_, index) => const Divider(height: 1, indent: 60),
                  itemBuilder: (context, index) {
                    final company = filteredCompanies[index];
                    final id = company['id'].toString();
                    final isSelected = _selectedCompanyId == id;
                    return ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: Colors.blue.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                        child: const Icon(Icons.business_rounded, color: Colors.blue, size: 20),
                      ),
                      title: Text(company['name'], style: GoogleFonts.outfit(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                      trailing: isSelected ? const Icon(Icons.check_circle, color: Colors.blue) : null,
                      onTap: () {
                        Navigator.pop(context);
                        setState(() {
                          _selectedCompanyId = id;
                          _selectedBranchId = null;
                        });
                        _loadBranches(id);
                        _loadRecentItems();
                      },
                    );
                  },
                ),
          );
        }
      ),
    );
  }

  void _showBranchPicker() {
    String searchQuery = "";
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          final filteredBranches = _branches.where((b) => 
            b['name'].toString().toLowerCase().contains(searchQuery.toLowerCase())
          ).toList();

          bool showAllBranches = 'all branches'.contains(searchQuery.toLowerCase());

          return _AppleSheet(
            title: 'Select Branch',
            searchHint: 'Search branches...',
            onSearchChanged: (val) => setSheetState(() => searchQuery = val),
            child: (filteredBranches.isEmpty && !showAllBranches)
              ? _buildEmptySearchState()
              : Column(
                  children: [
                    if (showAllBranches) ...[
                      ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: Colors.orange.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                          child: const Icon(Icons.layers_rounded, color: Colors.orange, size: 20),
                        ),
                        title: Text('All Branches', style: GoogleFonts.outfit(fontWeight: _selectedBranchId == 'all' ? FontWeight.bold : FontWeight.normal)),
                        trailing: _selectedBranchId == 'all' ? const Icon(Icons.check_circle, color: Colors.blue) : null,
                        onTap: () {
                          Navigator.pop(context);
                          setState(() => _selectedBranchId = 'all');
                          _loadRecentItems();
                        },
                      ),
                      if (filteredBranches.isNotEmpty) const Divider(height: 1, indent: 60),
                    ],
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: filteredBranches.length,
                      separatorBuilder: (_, index) => const Divider(height: 1, indent: 60),
                      itemBuilder: (context, index) {
                        final branch = filteredBranches[index];
                        final id = branch['id'].toString();
                        final isSelected = _selectedBranchId == id;
                        return ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(color: Colors.grey.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                            child: const Icon(Icons.location_on_rounded, color: Colors.grey, size: 20),
                          ),
                          title: Text(branch['name'], style: GoogleFonts.outfit(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                          trailing: isSelected ? const Icon(Icons.check_circle, color: Colors.blue) : null,
                          onTap: () {
                            Navigator.pop(context);
                            setState(() => _selectedBranchId = id);
                            _loadRecentItems();
                          },
                        );
                      },
                    ),
                  ],
                ),
          );
        }
      ),
    );
  }

  Widget _buildEmptySearchState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40),
      alignment: Alignment.center,
      child: Column(
        children: [
          Icon(Icons.search_off_rounded, size: 48, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text('No matching items found', style: GoogleFonts.outfit(color: Colors.grey[500], fontSize: 16)),
        ],
      ),
    );
  }

  void _showSignOutConfirmation() {
    final navigator = Navigator.of(context);
    
    showCupertinoDialog(
      context: context,
      builder: (BuildContext dialogContext) => CupertinoAlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: <CupertinoDialogAction>[
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () async {
              Navigator.pop(dialogContext);
              await _supabaseService.signOut();
              navigator.pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (route) => false,
              );
            },
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9), // Slate 50
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 120.0,
            floating: false,
            pinned: true,
            backgroundColor: Colors.white,
            elevation: 0,
            flexibleSpace: FlexibleSpaceBar(
              title: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Image.asset(
                        'assets/images/logomain.png',
                        height: 22,
                        fit: BoxFit.contain,
                      ),
                      const SizedBox(width: 8),
                      Text("EzLaunch", style: GoogleFonts.outfit(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 18)),
                    ],
                  ),
                  Text(
                    'Operator: ${_supabaseService.getUserDisplayName() ?? "Setup Needed"}',
                    style: GoogleFonts.outfit(fontSize: 10, color: Colors.grey[600], fontWeight: FontWeight.normal),
                  ),
                ],
              ),
              titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
            ),
            actions: [
              IconButton(
                onPressed: _showSignOutConfirmation,
                icon: const Icon(Icons.logout_rounded, color: Colors.blueAccent),
                tooltip: 'Sign Out',
              ),
              if (_isLoadingData)
                const Padding(
                  padding: EdgeInsets.only(right: 16.0),
                  child: Center(child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))),
                )
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FadeInDown(
                    duration: const Duration(milliseconds: 600),
                    child: Text('Target Destination', style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 4),
                  Text('Where should onboarding data sync?', style: GoogleFonts.outfit(color: Colors.grey[600])),
                  const SizedBox(height: 24),
                  
                  _SelectionCard(
                    title: 'Company',
                    value: _getCompanyName(),
                    icon: Icons.business_rounded,
                    onTap: _showCompanyPicker,
                  ),
                  const SizedBox(height: 12),
                  _SelectionCard(
                    title: 'Branch',
                    value: _getBranchNameDisplay(),
                    icon: Icons.store_rounded,
                    onTap: _selectedCompanyId == null ? null : _showBranchPicker,
                    isEnabled: _selectedCompanyId != null,
                  ),
                  const SizedBox(height: 32),
                  Text('Inventory Controls', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const ProductListScreen()),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.inventory_2_rounded, color: Color(0xFF2563EB)),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Product Master', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16)),
                                Text('View and search central catalog', style: GoogleFonts.outfit(color: Colors.grey[500], fontSize: 13)),
                              ],
                            ),
                          ),
                          Icon(Icons.chevron_right_rounded, color: Colors.grey[400]),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),
                  Text('Onboarding Strategy', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  
                  _buildModeCard(
                    title: 'Fresh Inventory Build',
                    subtitle: 'Scan barcodes to add new products',
                    icon: Icons.qr_code_scanner_rounded,
                    mode: 'Fresh',
                    color: Colors.deepOrange,
                  ),
                  const SizedBox(height: 12),
                  _buildModeCard(
                    title: 'Global Library Sync',
                    subtitle: 'Push existing products to client',
                    icon: Icons.cloud_upload_rounded,
                    mode: 'Library',
                    color: const Color(0xFF2563EB),
                  ),

                  if (_selectedCompanyId != null && _recentItems.isNotEmpty) ...[
                    const SizedBox(height: 32),
                    Row(
                      children: [
                        Text('Recent for this Shop', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold)),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(color: Colors.blue.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                          child: Text('${_recentItems.length} items', style: GoogleFonts.outfit(color: Colors.blue, fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _recentItems.length,
                      itemBuilder: (context, index) {
                        final item = _recentItems[index];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 5, offset: const Offset(0, 2)),
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(color: Colors.grey.withValues(alpha: 0.05), shape: BoxShape.circle),
                                child: const Icon(Icons.check_circle_outline, color: Colors.green, size: 20),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(item['name'] ?? 'Unknown', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 15)),
                                    Text(item['barcode'] ?? '', style: GoogleFonts.outfit(color: Colors.grey, fontSize: 12)),
                                  ],
                                ),
                              ),
                              Text('₹${item['mrp'] ?? '0'}', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.blue)),
                            ],
                          ),
                        );
                      },
                    ),
                  ],

                  
                  const SizedBox(height: 100), // Space for FAB
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: AnimatedSwitcher(
        duration: const Duration(milliseconds: 500),
        transitionBuilder: (Widget child, Animation<double> animation) {
          return ScaleTransition(
            scale: CurvedAnimation(
              parent: animation,
              curve: Curves.elasticOut,
            ),
            child: FadeTransition(
              opacity: animation,
              child: child,
            ),
          );
        },
        child: (_selectedCompanyId == null || _selectedBranchId == null)
            ? const SizedBox.shrink(key: ValueKey('empty_fab'))
            : Container(
                key: const ValueKey('scanner_fab'),
                margin: const EdgeInsets.symmetric(horizontal: 24),
                width: double.infinity,
                height: 68,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(34),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF2563EB).withValues(alpha: 0.35),
                      blurRadius: 40,
                      offset: const Offset(0, 15),
                    ),
                    BoxShadow(
                      color: Colors.white.withValues(alpha: 0.1),
                      blurRadius: 20,
                      offset: const Offset(0, -5),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(34),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFF3B82F6).withValues(alpha: 0.75),
                            const Color(0xFF2563EB).withValues(alpha: 0.85),
                            const Color(0xFF1E40AF).withValues(alpha: 0.9),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          stops: const [0.0, 0.4, 1.0],
                        ),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.3),
                          width: 1.5,
                        ),
                      ),
                      child: ElevatedButton(
                        onPressed: () {
                          if (_onboardingMode == 'Fresh') {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ScannerScreen(
                                  mode: _onboardingMode,
                                  businessId: _selectedCompanyId!,
                                  branchId: _selectedBranchId!,
                                ),
                              ),
                            ).then((_) => _loadRecentItems());
                          } else {
                            // Library Sync - Navigate to Product Picker
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => LibrarySyncScreen(
                                  businessId: _selectedCompanyId!,
                                  branchId: _selectedBranchId!,
                                ),
                              ),
                            ).then((_) => _loadRecentItems());
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(34)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                _onboardingMode == 'Fresh' 
                                  ? Icons.qr_code_scanner_rounded 
                                  : Icons.cloud_upload_rounded, 
                                color: Colors.white, 
                                size: 24
                              ),
                            ),
                             const SizedBox(width: 16),
                             Expanded(
                               child: Column(
                                 crossAxisAlignment: CrossAxisAlignment.start,
                                 mainAxisAlignment: MainAxisAlignment.center,
                                 children: [
                                   Text(
                                     _onboardingMode == 'Fresh' 
                                       ? 'Initialize Scanner' 
                                       : 'Open Library Sync',
                                     style: GoogleFonts.outfit(
                                       color: Colors.white,
                                       fontSize: 18,
                                       fontWeight: FontWeight.bold,
                                       letterSpacing: 0.8,
                                     ),
                                   ),
                                   if (_pendingDraftCount > 0 && _onboardingMode == 'Fresh')
                                     Text(
                                       'Resume draft with $_pendingDraftCount items',
                                       style: GoogleFonts.outfit(color: Colors.white.withValues(alpha: 0.8), fontSize: 12),
                                     ),
                                 ],
                               ),
                             ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
      ),
    );
  }


  String _getCompanyName() {
    if (_selectedCompanyId == null) return "Choose Business";
    return _companies.firstWhere((c) => c['id'].toString() == _selectedCompanyId, orElse: () => {'name': 'Select Business'})['name'];
  }

  String _getBranchNameDisplay() {
    if (_selectedCompanyId == null) return "Select company first";
    if (_selectedBranchId == 'all') return "All Branches";
    if (_selectedBranchId == null) return "Choose Branch";
    return _branches.firstWhere((b) => b['id'].toString() == _selectedBranchId, orElse: () => {'name': 'Select Branch'})['name'];
  }

  Widget _buildModeCard({required String title, required String subtitle, required IconData icon, required String mode, required Color color}) {
    bool isSelected = _onboardingMode == mode;
    return GestureDetector(
      onTap: () => setState(() => _onboardingMode = mode),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? color : Colors.transparent, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(14)),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold)),
                  Text(subtitle, style: GoogleFonts.outfit(color: Colors.grey[600], fontSize: 13)),
                ],
              ),
            ),
            if (isSelected) Icon(Icons.check_circle_rounded, color: color),
          ],
        ),
      ),
    );
  }
}

class _SelectionCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final VoidCallback? onTap;
  final bool isEnabled;

  const _SelectionCard({
    required this.title,
    required this.value,
    required this.icon,
    this.onTap,
    this.isEnabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Opacity(
        opacity: isEnabled ? 1.0 : 0.5,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              )
            ],
          ),
          child: Row(
            children: [
              Icon(icon, color: Colors.blueGrey, size: 24),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey[500], fontWeight: FontWeight.w500)),
                  Text(value, style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black87)),
                ],
              ),
              const Spacer(),
              const Icon(Icons.chevron_right_rounded, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}

class _AppleSheet extends StatelessWidget {
  final String title;
  final Widget child;
  final Function(String)? onSearchChanged;
  final String? searchHint;

  const _AppleSheet({
    required this.title, 
    required this.child,
    this.onSearchChanged,
    this.searchHint,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          // Handle
          Container(
            width: 40,
            height: 5,
            decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2.5)),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Text(title, style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          
          if (onSearchChanged != null) ...[
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TextField(
                  onChanged: onSearchChanged,
                  autofocus: true,
                  style: GoogleFonts.outfit(),
                  decoration: InputDecoration(
                    hintText: searchHint ?? 'Search...',
                    hintStyle: GoogleFonts.outfit(color: Colors.grey[500]),
                    prefixIcon: const Icon(Icons.search, color: Colors.grey),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ),
          ],
          
          const SizedBox(height: 16),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}
