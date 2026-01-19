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

class _ScanScreenState extends State<ScanScreen>
    with SingleTickerProviderStateMixin {
  // ปรับปรุง Controller
  final MobileScannerController cameraController = MobileScannerController(
    // 1. กำหนดรูปแบบเป็น all เพื่อรองรับทุกแบบ (QR, Code128, EAN, etc.)
    formats: const [BarcodeFormat.all],

    // 2. [สำคัญ] เพิ่มความละเอียดกล้อง เพื่อให้อ่านบาร์โค้ดที่ละเอียดหรือยาวได้ดีขึ้น
    // การใช้ความละเอียดสูงช่วยแก้ปัญหาอ่านบาร์โค้ดไม่ติด หรืออ่านยาก
    cameraResolution: const Size(1280, 720),

    // ลด timeout ลงเล็กน้อยเพื่อให้สแกนต่อเนื่องได้ไวขึ้น (ปรับตามความเหมาะสม)
    detectionTimeoutMs: 500,
    autoStart: false,

    // ตั้งค่า Torch (ไฟแฟลช) เริ่มต้นเป็นปิด
    torchEnabled: false,
  );

  final ApiService apiService = ApiService();

  late AnimationController _animationController;
  late Animation<double> _opacityAnimation;

  Product? scannedProduct;
  bool isLoading = false;
  bool isScanning = false;
  String? errorMessage;

  // ตัวแปรสำหรับสถานะไฟแฟลช
  bool _isTorchOn = false;

  bool _showBarcodeOnly = false;

  String? selectedPrinter;
  final List<String> printers = [
    'Printer A (Office)',
    'Printer B (Warehouse)',
    'Printer C (Lobby)',
  ];

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);

    _opacityAnimation = Tween<double>(
      begin: 0.2,
      end: 1.0,
    ).animate(_animationController);
  }

  @override
  void dispose() {
    cameraController.dispose();
    _searchController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _startScan() {
    setState(() {
      isScanning = true;
      errorMessage = null;
      // รีเซ็ตสถานะไฟแฟลชเมื่อเริ่มสแกนใหม่
      _isTorchOn = false;
    });
    cameraController.start();
  }

  void _stopScan() {
    setState(() => isScanning = false);
    cameraController.stop();
  }

  void _toggleTorch() {
    cameraController.toggleTorch();
    setState(() {
      _isTorchOn = !_isTorchOn;
    });
  }

  void _onDetect(BarcodeCapture capture) async {
    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isNotEmpty && !isLoading) {
      final String? code = barcodes.first.rawValue;
      if (code != null) {
        // เพิ่มการ Clean ข้อมูลเล็กน้อยเผื่อมีช่องว่างหัวท้าย
        String cleanCode = code.trim();
        if (cleanCode.isNotEmpty) {
          _stopScan();
          await _fetchProduct(cleanCode);
        }
      }
    }
  }

  Future<void> _fetchProduct(String code) async {
    setState(() {
      isLoading = true;
      errorMessage = null;
      _showBarcodeOnly = false;
    });

    try {
      final product = await apiService.getProductByBarcode(code);
      setState(() {
        scannedProduct = product;
        if (product == null) {
          errorMessage = "ไม่พบสินค้า รหัส: $code";
        }
      });
    } catch (e) {
      setState(() => errorMessage = "เกิดข้อผิดพลาดในการเชื่อมต่อ");
    } finally {
      setState(() => isLoading = false);
    }
  }

  void _showManualSearchDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('ค้นหาจากรหัส', style: GoogleFonts.kanit()),
        content: TextField(
          controller: _searchController,
          decoration: const InputDecoration(
            hintText: 'กรอกรหัสบาร์โค้ด หรือ SKU',
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.text,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ยกเลิก'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              if (_searchController.text.isNotEmpty) {
                _fetchProduct(_searchController.text.trim().toUpperCase());
              }
            },
            child: const Text('ค้นหา'),
          ),
        ],
      ),
    );
  }

  // ฟังก์ชันสำหรับแสดง Dialog ตั้งค่าการพิมพ์ (ขนาดกระดาษ, จำนวน)
  void _showPrintSettingsDialog() {
    // ค่าเริ่มต้น
    double selectedWidth = 58.0; // ขนาดมาตรฐาน
    int quantity = 1;
    // รายการขนาดกระดาษที่รองรับ (35-80 มม.)
    final List<double> paperSizes = [35, 40, 50, 58, 80];

    showDialog(
      context: context,
      builder: (context) {
        // ใช้ StatefulBuilder เพื่อให้ Dialog อัปเดตค่าได้เมื่อกดปุ่ม +/- หรือเปลี่ยน Dropdown
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Text(
                'ตั้งค่าการพิมพ์',
                style: GoogleFonts.kanit(fontWeight: FontWeight.bold),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ส่วนเลือกขนาดกระดาษ
                  Row(
                    children: [
                      Icon(Icons.receipt_long, color: Colors.blue[700]),
                      const SizedBox(width: 10),
                      Text('ขนาดกระดาษ:',
                          style: GoogleFonts.kanit(fontSize: 16)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<double>(
                        value: selectedWidth,
                        isExpanded: true,
                        items: paperSizes.map((size) {
                          return DropdownMenuItem(
                            value: size,
                            child: Text(
                              '${size.toInt()} มม.',
                              style: GoogleFonts.kanit(fontSize: 16),
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setStateDialog(() => selectedWidth = val);
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ส่วนเลือกจำนวน
                  Row(
                    children: [
                      Icon(Icons.copy, color: Colors.blue[700]),
                      const SizedBox(width: 10),
                      Text('จำนวน:', style: GoogleFonts.kanit(fontSize: 16)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.remove),
                          onPressed: () {
                            if (quantity > 1) {
                              setStateDialog(() => quantity--);
                            }
                          },
                        ),
                      ),
                      Container(
                        width: 60,
                        alignment: Alignment.center,
                        child: Text(
                          '$quantity',
                          style: GoogleFonts.kanit(
                              fontSize: 22, fontWeight: FontWeight.bold),
                        ),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.add, color: Colors.blue),
                          onPressed: () {
                            setStateDialog(() => quantity++);
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'ยกเลิก',
                    style: GoogleFonts.kanit(color: Colors.grey),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    // สั่งพิมพ์จริงโดยส่งค่าที่เลือกไปด้วย
                    _executePrint(selectedWidth, quantity);
                  },
                  icon: const Icon(Icons.print),
                  label: Text('พิมพ์', style: GoogleFonts.kanit()),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[800],
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ฟังก์ชันสั่งพิมพ์จริง (Mockup)
  void _executePrint(double width, int qty) {
    String modeText = _showBarcodeOnly ? "แบบบาร์โค้ด" : "แบบป้ายราคา";
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'กำลังพิมพ์ $modeText\nไปที่: $selectedPrinter\nขนาด: ${width.toInt()} มม. | จำนวน: $qty ใบ',
          style: GoogleFonts.kanit(),
        ),
        backgroundColor: Colors.green[700],
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _printLabel() {
    if (scannedProduct == null) return;
    if (selectedPrinter == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรุณาเลือกเครื่องพิมพ์ก่อน')),
      );
      return;
    }

    // เรียกหน้าต่างตั้งค่าก่อนพิมพ์แทนการพิมพ์ทันที
    _showPrintSettingsDialog();
  }

  String _addCommas(String price) {
    RegExp reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    return price.replaceAllMapped(reg, (Match m) => '${m[1]},');
  }

  @override
  Widget build(BuildContext context) {
    if (isScanning) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            MobileScanner(
              controller: cameraController,
              onDetect: _onDetect,
              // ลบ scanWindow ออกเพื่อให้สแกนได้เต็มหน้าจอ ไม่จำกัดแค่ในกรอบ
              // scanWindow: scanWindow,
            ),

            // กรอบ UI (Visual Guide) - ยังคงแสดงเพื่อให้ผู้ใช้รู้ตำแหน่งโฟกัสกลางจอ
            Center(
              child: Container(
                width: 280,
                height: 180,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.redAccent, width: 3),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 10,
                    ),
                  ],
                ),
              ),
            ),

            // เส้นเลเซอร์สแกน
            Center(
              child: FadeTransition(
                opacity: _opacityAnimation,
                child: Container(
                  width: 260,
                  height: 2,
                  decoration: BoxDecoration(
                    color: Colors.red,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.red.withOpacity(0.8),
                        blurRadius: 8,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // ปุ่มปิด
            Positioned(
              top: 50,
              left: 20,
              child: CircleAvatar(
                backgroundColor: Colors.black54,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: _stopScan,
                ),
              ),
            ),

            // เพิ่มปุ่มเปิด/ปิดไฟแฟลช
            Positioned(
              top: 50,
              right: 20,
              child: CircleAvatar(
                backgroundColor: Colors.black54,
                child: IconButton(
                  icon: Icon(
                    _isTorchOn ? Icons.flash_on : Icons.flash_off,
                    color: _isTorchOn ? Colors.yellow : Colors.white,
                  ),
                  onPressed: _toggleTorch,
                ),
              ),
            ),

            const Positioned(
              bottom: 80,
              left: 0,
              right: 0,
              child: Text(
                "จัดบาร์โค้ดให้อยู่ในกรอบ",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            ),
          ],
        ),
      );
    }

    // ส่วนแสดงผลหลัก
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text(
          'WG wanawat',
          style: GoogleFonts.kanit(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.blue[800],
        elevation: 0,
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  offset: const Offset(0, 4),
                  blurRadius: 4,
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.print, color: Colors.blue[800], size: 24),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: selectedPrinter,
                        hint: Text(
                          "เลือกเครื่องพิมพ์",
                          style: GoogleFonts.kanit(color: Colors.grey),
                        ),
                        isExpanded: true,
                        icon: const Icon(
                          Icons.arrow_drop_down_circle_outlined,
                          color: Colors.grey,
                        ),
                        style: GoogleFonts.kanit(
                          color: Colors.black87,
                          fontSize: 16,
                        ),
                        items: printers.map((String printer) {
                          return DropdownMenuItem<String>(
                            value: printer,
                            child: Text(printer),
                          );
                        }).toList(),
                        onChanged: (String? newValue) {
                          setState(() {
                            selectedPrinter = newValue;
                          });
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (isLoading)
                      const CircularProgressIndicator()
                    else if (errorMessage != null)
                      _buildErrorView()
                    else if (scannedProduct != null)
                      _showBarcodeOnly
                          ? _buildBarcodeOnlyTag(scannedProduct!)
                          : _buildPriceTag(scannedProduct!)
                    else
                      _buildPlaceholderFrame(),
                  ],
                ),
              ),
            ),
          ),

          Container(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(30),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  offset: const Offset(0, -5),
                  blurRadius: 20,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: _startScan,
                    icon: const Icon(Icons.qr_code_scanner),
                    label: Text(
                      'สแกนสินค้า',
                      style: GoogleFonts.kanit(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[700],
                      foregroundColor: Colors.white,
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed: _showManualSearchDialog,
                    icon: const Icon(Icons.keyboard),
                    label: Text(
                      'ค้นหาสินค้าจากเลขรหัส',
                      style: GoogleFonts.kanit(fontSize: 16),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.grey[800],
                      side: BorderSide(color: Colors.grey[300]!),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                if (scannedProduct != null) ...[
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () =>
                              setState(() => _showBarcodeOnly = false),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: !_showBarcodeOnly
                                ? Colors.blue[100]
                                : Colors.grey[100],
                            foregroundColor: !_showBarcodeOnly
                                ? Colors.blue[800]
                                : Colors.grey[600],
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(
                                color: !_showBarcodeOnly
                                    ? Colors.blue.withOpacity(0.5)
                                    : Colors.transparent,
                              ),
                            ),
                          ),
                          child: Text(
                            'แบบป้ายราคา',
                            style: GoogleFonts.kanit(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () =>
                              setState(() => _showBarcodeOnly = true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _showBarcodeOnly
                                ? Colors.blue[100]
                                : Colors.grey[100],
                            foregroundColor: _showBarcodeOnly
                                ? Colors.blue[800]
                                : Colors.grey[600],
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(
                                color: _showBarcodeOnly
                                    ? Colors.blue.withOpacity(0.5)
                                    : Colors.transparent,
                              ),
                            ),
                          ),
                          child: Text(
                            'แบบบาร์โค้ด',
                            style: GoogleFonts.kanit(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],

                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        // ปุ่มตั้งค่ากระดาษเดิม สามารถกดเพื่อเปิดเมนูตั้งค่าได้เหมือนกัน
                        onPressed: scannedProduct != null
                            ? _showPrintSettingsDialog
                            : null,
                        icon: const Icon(Icons.settings_outlined, size: 20),
                        label: Text(
                          'ตั้งค่ากระดาษ',
                          style: GoogleFonts.kanit(fontSize: 14),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.grey[700],
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          side: BorderSide(color: Colors.grey[300]!),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: scannedProduct != null ? _printLabel : null,
                        icon: const Icon(Icons.print, size: 20),
                        label: Text(
                          'พิมพ์สินค้า',
                          style: GoogleFonts.kanit(fontSize: 14),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green[600],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          disabledBackgroundColor: Colors.grey[200],
                          disabledForegroundColor: Colors.grey[400],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholderFrame() {
    return Container(
      width: double.infinity,
      height: 250,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.grey.shade300,
          width: 2,
          style: BorderStyle.solid,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.label_outline, size: 60, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            'รอข้อมูลสินค้า',
            style: GoogleFonts.kanit(
              fontSize: 20,
              color: Colors.grey[400],
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'กรุณาสแกนหรือค้นหาสินค้า',
            style: GoogleFonts.kanit(color: Colors.grey[400]),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.red[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red[100]!),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.red),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              errorMessage!,
              style: GoogleFonts.kanit(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriceTag(Product item) {
    final double notMemberPrice = item.cashNotMember;
    final double memberPrice = item.cashMember;

    // แยกส่วนทศนิยม
    final normalParts = notMemberPrice.toStringAsFixed(2).split('.');
    // ใช้ฟังก์ชัน _addCommas ใส่ลูกน้ำให้ตัวเลขหลัก (เช่น 1000 -> 1,000)
    final bigPrice = _addCommas(normalParts[0]);
    final decimal = normalParts[1];

    // ทำเช่นเดียวกันกับราคาสมาชิก
    final memberParts = memberPrice.toStringAsFixed(2).split('.');
    final memberBigPrice = _addCommas(memberParts[0]);
    final memberDecimal = memberParts[1];

    final dateStr = item.maxDate;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [BoxShadow(blurRadius: 15, color: Colors.black12)],
        border: Border.all(color: Colors.grey.shade300),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'รหัส: ${item.segment1}',
                style: GoogleFonts.sarabun(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            item.description,
            style: GoogleFonts.sarabun(
              fontSize: 18,
              color: Colors.black87,
              fontWeight: FontWeight.bold,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const Divider(height: 30),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    border: Border(
                      right: BorderSide(color: Colors.grey.shade300),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'ราคาสมาชิก',
                          style: GoogleFonts.sarabun(
                            color: Colors.red.shade800,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            memberBigPrice, // แสดงราคาแบบมีคอมมา
                            style: GoogleFonts.sarabun(
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              color: Colors.red.shade800,
                              height: 1,
                            ),
                          ),
                          Text(
                            '.$memberDecimal',
                            style: GoogleFonts.sarabun(
                              fontSize: 14,
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
              Expanded(
                child: Container(
                  padding: const EdgeInsets.only(left: 12),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
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
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            bigPrice, // แสดงราคาแบบมีคอมมา
                            style: GoogleFonts.sarabun(
                              fontSize: 32,
                              fontWeight: FontWeight.w900,
                              color: Colors.black,
                              height: 1,
                            ),
                          ),
                          Text(
                            '.$decimal',
                            style: GoogleFonts.sarabun(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: Colors.black,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 40,
                        child:
                            (item.crossReference.isNotEmpty)
                            ? Image.network(
                                'https://barcode.tec-it.com/barcode.ashx?data=${item.crossReference}&code=Code128&translate-esc=on',
                                fit: BoxFit.contain,
                                errorBuilder: (c, e, s) => const Icon(
                                  Icons.broken_image,
                                  color: Colors.grey,
                                ),
                              )
                            : const Center(child: Text("-")),
                      ),
                      Text(
                        item.crossReference,
                        style: GoogleFonts.sarabun(
                          fontSize: 10,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          const Divider(),
          Text(
            'ราคา ณ วันที่: $dateStr',
            style: GoogleFonts.sarabun(
              fontSize: 10,
              color: Colors.grey.shade600,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBarcodeOnlyTag(Product item) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [BoxShadow(blurRadius: 15, color: Colors.black12)],
        border: Border.all(color: Colors.grey.shade300),
      ),
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            item.description,
            style: GoogleFonts.sarabun(
              fontSize: 24,
              color: Colors.black87,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 30),

          Container(
            height: 120,
            width: double.infinity,
            alignment: Alignment.center,
            child:
                (item.crossReference.isNotEmpty)
                ? Image.network(
                    'https://barcode.tec-it.com/barcode.ashx?data=${item.crossReference}&code=Code128&translate-esc=on',
                    fit: BoxFit.contain,
                    errorBuilder: (c, e, s) => const Icon(
                      Icons.broken_image,
                      size: 50,
                      color: Colors.grey,
                    ),
                  )
                : const Center(child: Text("-")),
          ),
          const SizedBox(height: 10),

          Text(
            item.crossReference,
            style: GoogleFonts.sarabun(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              letterSpacing: 3,
            ),
          ),
        ],
      ),
    );
  }
}