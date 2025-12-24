class Product {
  final String barcode;
  final String sku;
  final String productName;
  final double unitPrice;    // ราคาขายจริง
  final double memberPrice;  // ราคาสำหรับสมาชิก (มีมาให้แล้ว!)
  final double normalPrice;  // ราคาปกติ (มีมาให้แล้ว!)

  Product({
    required this.barcode,
    required this.sku,
    required this.productName,
    required this.unitPrice,
    required this.memberPrice,
    required this.normalPrice,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      // แปลงข้อมูลจาก JSON (ตามรูป image_534d88.png)
      barcode: json['Barcode']?.toString() ?? '', 
      sku: json['SKU']?.toString() ?? '',
      productName: json['ProductName']?.toString() ?? '',
      
      // แปลงตัวเลขราคา (ถ้าเป็น null ให้เป็น 0.0)
      unitPrice: double.tryParse(json['UnitPrice'].toString()) ?? 0.0,
      memberPrice: double.tryParse(json['MemberPrice'].toString()) ?? 0.0,
      normalPrice: double.tryParse(json['NormalPrice'].toString()) ?? 0.0,
    );
  }
}