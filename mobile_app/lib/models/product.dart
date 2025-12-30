class Product {
  final String index;
  final String crossReference;
  final String segment1;
  final String description;
  final String primaryUomCode;
  final double cashNotMember;  // เงินสดรับเอง_ไม่สมาชิก
  final double cashMember;      // เงินสดรับเอง_สมาชิก_
  final DateTime maxDate;       // Max

  Product({
    required this.index,
    required this.crossReference,
    required this.segment1,
    required this.description,
    required this.primaryUomCode,
    required this.cashNotMember,
    required this.cashMember,
    required this.maxDate,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      // แปลงข้อมูลจาก JSON ให้ตรงกับชื่อคอลัมน์ใน Database
      index: json['Index']?.toString() ?? '',
      crossReference: json['CROSS_REFERENCE']?.toString() ?? '',
      segment1: json['SEGMENT1']?.toString() ?? '',
      description: json['DESCRIPTION']?.toString() ?? '',
      primaryUomCode: json['PRIMARY_UOM_CODE']?.toString() ?? '',
      
      // แปลงตัวเลขราคา
      cashNotMember: double.tryParse(json['เงินสดรับเอง_ไม่สมาชิก']?.toString() ?? '0') ?? 0.0,
      cashMember: double.tryParse(json['เงินสดรับเอง_สมาชิก_']?.toString() ?? '0') ?? 0.0,
      
      // แปลงวันที่
      maxDate: json['Max'] != null 
          ? DateTime.parse(json['Max'].toString()) 
          : DateTime.now(),
    );
  }
}