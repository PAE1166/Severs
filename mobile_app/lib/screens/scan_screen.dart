import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/product.dart';
import '../services/api_service.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final MobileScannerController cameraController = MobileScannerController();
  final ApiService apiService = ApiService();

  Product? scannedProduct;
  bool isLoading = false;
  String? errorMessage;

  // ฟังก์ชันเมื่อสแกนเจอ
  void _onDetect(BarcodeCapture capture) async {
    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isNotEmpty && !isLoading) {
      final String? code = barcodes.first.rawValue;
      if (code != null) {
        // หยุดกล้องชั่วคราวตอนโหลดข้อมูล
        cameraController.stop();
        await _fetchProduct(code);
      }
    }
  }

  Future<void> _fetchProduct(String code) async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final product = await apiService.getProductByBarcode(code);
      setState(() {
        scannedProduct = product;
        if (product == null) errorMessage = "ไม่พบสินค้า รหัส: $code";
      });
    } finally {
      setState(() => isLoading = false);
    }
  }

  // รีเซ็ตเพื่อสแกนใหม่
  void _resetScan() {
    setState(() {
      scannedProduct = null;
      errorMessage = null;
    });
    cameraController.start();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('สแกนราคาสินค้า'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _resetScan),
        ],
      ),
      body: Column(
        children: [
          // 1. ส่วนกล้อง
          if (scannedProduct == null)
            Expanded(
              flex: 1,
              child: Stack(
                children: [
                  MobileScanner(
                    controller: cameraController,
                    onDetect: _onDetect,
                  ),
                  Center(
                    child: Container(
                      width: 250,
                      height: 150,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.red, width: 2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  if (isLoading)
                    const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    ),
                ],
              ),
            ),

          // 2. ส่วนแสดงป้ายราคา
          Expanded(
            flex: scannedProduct == null ? 0 : 2,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  if (errorMessage != null)
                    Text(
                      errorMessage!,
                      style: const TextStyle(color: Colors.red, fontSize: 18),
                    ),

                  if (scannedProduct != null)
                    _buildPriceTag(scannedProduct!),

                  const SizedBox(height: 20),
                  if (scannedProduct != null)
                    ElevatedButton.icon(
                      onPressed: _resetScan,
                      icon: const Icon(Icons.camera_alt),
                      label: const Text('สแกนสินค้าชิ้นต่อไป'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 30,
                          vertical: 15,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 🏷️ WIDGET ป้ายราคา (ปรับให้ตรงกับ Model ใหม่)
  Widget _buildPriceTag(Product item) {
    // ราคาทั่วไป (ไม่สมาชิก)
    final normalParts = item.cashNotMember.toStringAsFixed(2).split('.');
    final bigPrice = normalParts[0];
    final decimal = normalParts[1];

    // ราคาสมาชิก
    final memberParts = item.cashMember.toStringAsFixed(2).split('.');
    
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [BoxShadow(blurRadius: 10, color: Colors.black12)],
        border: Border.all(color: Colors.grey.shade300),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // --- HEADER ---
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'รหัส: ${item.segment1}',
                style: GoogleFonts.sarabun(fontWeight: FontWeight.bold),
              ),
              Text(
                'ONE LAKE',
                style: GoogleFonts.sarabun(
                  color: Colors.red.shade800,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          
          Text(
            item.description,
            style: GoogleFonts.sarabun(fontSize: 16, color: Colors.black87),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const Divider(height: 30),

          // --- BODY ---
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // LEFT SECTION (ราคาสมาชิก)
              Expanded(
                child: Container(
                  padding: const EdgeInsets.only(right: 15),
                  decoration: BoxDecoration(
                    border: Border(
                      right: BorderSide(
                        color: Colors.grey.shade300,
                        style: BorderStyle.solid,
                      ),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'ราคาสมาชิก',
                          style: GoogleFonts.sarabun(
                            color: Colors.red.shade800,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 5),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            memberParts[0],
                            style: GoogleFonts.sarabun(
                              fontSize: 32,
                              fontWeight: FontWeight.w800,
                              color: Colors.red.shade800,
                              height: 1,
                            ),
                          ),
                          Text(
                            '.${memberParts[1]}',
                            style: GoogleFonts.sarabun(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.red.shade800,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // RIGHT SECTION (ราคาปกติ)
              Expanded(
                child: Container(
                  padding: const EdgeInsets.only(left: 15),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'ราคาทั่วไป',
                              style: GoogleFonts.sarabun(
                                color: Colors.black54,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Text(
                            item.primaryUomCode,
                            style: GoogleFonts.sarabun(
                              fontSize: 10,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      // ราคาตัวใหญ่
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            bigPrice,
                            style: GoogleFonts.sarabun(
                              fontSize: 42,
                              fontWeight: FontWeight.w900,
                              color: Colors.black,
                              height: 1,
                            ),
                          ),
                          Text(
                            '.$decimal',
                            style: GoogleFonts.sarabun(
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              color: Colors.black,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      
                      // บาร์โค้ด
                      Container(
                        height: 50,
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: item.crossReference.isNotEmpty
                            ? Image.network(
                                'https://barcode.tec-it.com/barcode.ashx?data=${item.crossReference}&code=Code128&translate-esc=on',
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stackTrace) =>
                                    const Center(
                                      child: Icon(Icons.broken_image, size: 30, color: Colors.grey),
                                    ),
                              )
                            : const Center(child: Text("ไม่มีบาร์โค้ด")),
                      ),

                      // ตัวเลขบาร์โค้ด
                      Text(
                        item.crossReference,
                        style: GoogleFonts.sarabun(
                          fontSize: 12,
                          letterSpacing: 2,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}