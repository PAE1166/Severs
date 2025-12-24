import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/product.dart';

class ApiService {
  // เช็ค IP ให้ตรงกับเครื่องคอมฯ นะครับ (10.0.2.2 สำหรับ Emulator, หรือ 192.168... สำหรับเครื่องจริง)
  static const String baseUrl = 'http://172.20.10.11:5000/api/products';

  // 1. ฟังก์ชันดึงทั้งหมด (ของเดิม)
  Future<List<Product>> getProducts() async {
    // ... (โค้ดเดิมของคุณ) ...
    // เพื่อความชัวร์ ใส่โค้ดนี้แทนได้เลยครับ
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
  // 2. เพิ่มฟังก์ชันนี้เข้าไปครับ (เพื่อให้หน้า Scan เรียกใช้ได้)
  // ---------------------------------------------------------
  Future<Product?> getProductByBarcode(String barcodeToFind) async {
    try {
      // ดึงสินค้ามาทั้งหมดก่อน (เพราะ API เราส่งมาหมด)
      List<Product> allProducts = await getProducts();
      
      // กรองหาตัวที่ Barcode ตรงกับที่สแกน
      try {
        return allProducts.firstWhere((p) => p.barcode == barcodeToFind);
      } catch (e) {
        return null; // ถ้าหาไม่เจอ
      }
    } catch (e) {
      return null;
    }
  }
}