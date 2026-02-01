class BarcodeItem {
  final String barcode;
  final String itemName;
  final String? brand;
  final String? category;
  final String? hsn;
  final String? sku;
  final double mrp;
  final double salePrice;
  final double purchasePrice;
  final double? taxRate;
  final String? unit;
  final String? notes;
  final String status;

  BarcodeItem({
    required this.barcode,
    required this.itemName,
    this.brand,
    this.category,
    this.hsn,
    this.sku,
    required this.mrp,
    required this.salePrice,
    required this.purchasePrice,
    this.taxRate,
    this.unit,
    this.notes,
    this.status = 'pending',
  });

  factory BarcodeItem.fromJson(Map<String, dynamic> json) {
    return BarcodeItem(
      barcode: json['barcode']?.toString() ?? '',
      itemName: (json['name'] ?? json['item_name'] ?? '').toString(),
      brand: json['brand']?.toString(),
      category: json['category']?.toString(),
      hsn: (json['hsn'] ?? json['hsn_code'] ?? json['hsncode'])?.toString(),
      sku: json['sku']?.toString(),
      mrp: (json['mrp'] as num?)?.toDouble() ?? 0.0,
      salePrice: (json['sale_price'] as num?)?.toDouble() ?? 0.0,
      purchasePrice: (json['purchase_price'] as num?)?.toDouble() ?? 0.0,
      taxRate: (json['tax_rate'] as num?)?.toDouble() ?? (json['gst_rate'] as num?)?.toDouble(),
      unit: json['unit']?.toString(),
      notes: json['notes']?.toString(),
      status: json['status']?.toString() ?? 'pending',
    );
  }


  Map<String, dynamic> toJson() {
    return {
      'barcode': barcode,
      'item_name': itemName,
      'brand': brand,
      'category': category,
      'hsn_code': hsn,
      'sku': sku,
      'mrp': mrp,
      'sale_price': salePrice,
      'purchase_price': purchasePrice,
      'tax_rate': taxRate,
      'unit': unit,
      'notes': notes,
      'status': status,
    };
  }

  BarcodeItem copyWith({
    String? itemName,
    String? brand,
    String? category,
    String? hsn,
    String? sku,
    double? mrp,
    double? salePrice,
    double? purchasePrice,
    double? taxRate,
    String? unit,
    String? notes,
    String? status,
  }) {
    return BarcodeItem(
      barcode: barcode,
      itemName: itemName ?? this.itemName,
      brand: brand ?? this.brand,
      category: category ?? this.category,
      hsn: hsn ?? this.hsn,
      sku: sku ?? this.sku,
      mrp: mrp ?? this.mrp,
      salePrice: salePrice ?? this.salePrice,
      purchasePrice: purchasePrice ?? this.purchasePrice,
      taxRate: taxRate ?? this.taxRate,
      unit: unit ?? this.unit,
      notes: notes ?? this.notes,
      status: status ?? this.status,
    );
  }
}
