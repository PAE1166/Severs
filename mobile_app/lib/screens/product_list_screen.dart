import 'package:flutter/material.dart';
import '../models/product.dart';
import '../services/api_service.dart'; // ตรวจสอบว่าไฟล์นี้มีอยู่จริงตามข้อ 2

class ProductListScreen extends StatefulWidget {
  const ProductListScreen({super.key});

  @override
  State<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends State<ProductListScreen> {
  final ApiService apiService = ApiService(); // ถ้ายังแดง ให้เช็คไฟล์ api_service.dart
  late Future<List<Product>> _productsFuture;

  @override
  void initState() {
    super.initState();
    _productsFuture = apiService.getProducts();
  }

  Future<void> _refreshProducts() async {
    setState(() {
      _productsFuture = apiService.getProducts();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('สต็อกสินค้า OneLake'), // แก้ชื่อ Title หน่อย
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: RefreshIndicator(
        onRefresh: _refreshProducts,
        child: FutureBuilder<List<Product>>(
          future: _productsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text('เกิดข้อผิดพลาด: ${snapshot.error}'));
            }
            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const Center(child: Text('ไม่พบข้อมูลสินค้า'));
            }

            final products = snapshot.data!;
            return ListView.builder(
              itemCount: products.length,
              itemBuilder: (context, index) {
                final item = products[index];
                return Card(
                  margin: const EdgeInsets.all(8),
                  child: ListTile(
                    // 1. แก้ id เป็น sku
                    leading: CircleAvatar(
                      child: Text(item.sku.length > 3 ? item.sku.substring(0, 3) : item.sku, 
                      style: const TextStyle(fontSize: 12)), 
                    ), 
                    // 2. แก้ description เป็น productName
                    title: Text(item.productName), 
                    // 3. แก้ uom เป็น barcode (หรือข้อมูลอื่นที่มี)
                    subtitle: Text('Barcode: ${item.barcode}'), 
                    trailing: Text(
                      '฿${item.unitPrice.toStringAsFixed(2)}',
                      style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}