import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/product.dart';

class ApiService {
  // เช็ค IP ให้ตรงกับเครื่องคอมฯ นะครับ (10.0.2.2 สำหรับ Emulator, หรือ 192.168... สำหรับเครื่องจริง)
  static const String baseUrl = 'http://172.20.10.11:5000/api/products';

  // 1. ฟังก์ชันดึงทั้งหมด
  Future<List<Product>> getProducts() async {
    try {
      final response = await http.get(Uri.parse(baseUrl));
      if (response.statusCode == 200) {
        List<dynamic> body = jsonDecode(response.body);
        return body.map((dynamic item) => Product.fromJson(item)).toList();
      } else {
        throw Exception('Failed to load products');
      }
    } catch (e) {
      throw Exception('Error: $e');
    }
  }

  // ---------------------------------------------------------
  // 2. ฟังก์ชันค้นหาสินค้าจากบาร์โค้ด (CROSS_REFERENCE)
  // ---------------------------------------------------------
  Future<Product?> getProductByBarcode(String barcodeToFind) async {
    try {
      // ดึงสินค้ามาทั้งหมดก่อน
      List<Product> allProducts = await getProducts();

      // กรองหาตัวที่ CROSS_REFERENCE ตรงกับที่สแกน
      try {
        return allProducts.firstWhere((p) => p.crossReference == barcodeToFind);
      } catch (e) {
        return null; // ถ้าหาไม่เจอ
      }
    } catch (e) {
      return null;
    }
  }

  // ---------------------------------------------------------
  // 3. ฟังก์ชันค้นหาสินค้าจากรหัสสินค้า (SEGMENT1)
  // ---------------------------------------------------------
  Future<Product?> getProductByCode(String code) async {
    try {
      List<Product> allProducts = await getProducts();

      try {
        return allProducts.firstWhere((p) => p.segment1 == code);
      } catch (e) {
        return null;
      }
    } catch (e) {
      return null;
    }
  }
}
