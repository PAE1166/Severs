class Product {
  final String index;
  final String crossReference;
  final String segment1;
  final String description;
  final String primaryUomCode;
  final double cashNotMember;
  final double cashMember;
  final String maxDate;

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
    
    
    String formatDateToThai(dynamic rawValue) {
      if (rawValue == null) {
        return '';
      }

      String dateStr = rawValue.toString();
      
      
      DateTime? parsed = DateTime.tryParse(dateStr);

    
      if (parsed == null) {
        try {
          
          List<String> parts = dateStr.split(' ');
          
          
          if (parts.length >= 4) {
            int day = int.parse(parts[1]); 
            String monthStr = parts[2];    
            int year = int.parse(parts[3]); 
            
           
            const months = {
              'Jan': 1, 'Feb': 2, 'Mar': 3, 'Apr': 4, 'May': 5, 'Jun': 6,
              'Jul': 7, 'Aug': 8, 'Sep': 9, 'Oct': 10, 'Nov': 11, 'Dec': 12
            };
            int month = months[monthStr] ?? 1;

            parsed = DateTime(year, month, day);
          }
        } catch (e) {
          
          parsed = null;
        }
      }

      if (parsed == null) {
        
        return dateStr; 
      }

      final day = parsed.day.toString().padLeft(2, '0');
      final month = parsed.month.toString().padLeft(2, '0');
      final year = parsed.year + 543; 

      return "$day/$month/$year";
    }

    return Product(
      index: json['Index']?.toString() ?? '',
      crossReference: json['CROSS_REFERENCE']?.toString() ?? '',
      segment1: json['SEGMENT1']?.toString() ?? '',
      description: json['DESCRIPTION']?.toString() ?? '',
      primaryUomCode: json['PRIMARY_UOM_CODE']?.toString() ?? '',

      cashNotMember:
          double.tryParse(json['เงินสดรับเอง_ไม่สมาชิก_']?.toString() ?? '0') ??
              0.0,
      cashMember:
          double.tryParse(json['เงินสดรับเอง_สมาชิก_']?.toString() ?? '0') ??
              0.0,

      maxDate: formatDateToThai(json['Maxราคาณ__วันที่']),
    );
  }
}