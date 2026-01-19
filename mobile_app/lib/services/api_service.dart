import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/product.dart';

class ApiService {
  static const String baseUrl = 'http://192.168.37.136:5000/api/products';

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
      throw Exception('Error connection: $e');
    }
  }

  Future<Product?> getProductByBarcode(String barcodeToFind) async {
    try {
      final String requestUrl = '$baseUrl?barcode=$barcodeToFind';

      final response = await http.get(Uri.parse(requestUrl));

      if (response.statusCode == 200) {
        List<dynamic> body = jsonDecode(response.body);

        if (body.isNotEmpty) {
          return Product.fromJson(body[0]);
        } else {
          return null;
        }
      } else {
        throw Exception('Failed to search product');
      }
    } catch (e) {
      print("Error finding barcode: $e");
      return null;
    }
  }

  Future<Product?> getProductByCode(String codeToFind) async {
    try {
      final String requestUrl = '$baseUrl?sku=$codeToFind';

      final response = await http.get(Uri.parse(requestUrl));

      if (response.statusCode == 200) {
        List<dynamic> body = jsonDecode(response.body);

        if (body.isNotEmpty) {
          return Product.fromJson(body[0]);
        } else {
          return null;
        }
      } else {
        throw Exception('Failed to search product');
      }
    } catch (e) {
      print("Error finding sku: $e");
      return null;
    }
  }
}
