import 'dart:io';
import 'dart:typed_data';
import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:another_brother/printer_info.dart' as brother;
import 'package:another_brother/label_info.dart';
import 'package:permission_handler/permission_handler.dart';

// [Import ApiService และ Product จากไฟล์จริงของคุณ]
import '../services/api_service.dart';
import '../models/product.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: ScanScreen(),
  ));
}

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> with SingleTickerProviderStateMixin {
  
  final GlobalKey _printKey = GlobalKey();

  final MobileScannerController cameraController = MobileScannerController(
    formats: const [BarcodeFormat.all],
    detectionTimeoutMs: 500,
    autoStart: false,
    torchEnabled: false,
    facing: CameraFacing.back,
  );

  final ApiService apiService = ApiService();

  late AnimationController _animationController;
  late Animation<double> _opacityAnimation;

  Product? scannedProduct;
  bool isLoading = false;
  bool isScanning = false;
  String? errorMessage;
  bool _isTorchOn = false;
  bool _showBarcodeOnly = false;

  String? selectedPrinter;
  final List<String> printers = [
    'Brother QL-820NWB (Bluetooth)',
  ];

  // ใช้เลือกระดับความสูง (1-5) แทนการเลือกขนาดกระดาษ
  // 1 = สั้นที่สุด (Compact), 5 = ยาวที่สุด (Loose)
  int _currentHeightLevel = 1;
  
  // รายการระดับความสูง
  final List<Map<String, dynamic>> heightOptions = [
    {'level': 1, 'label': '62mm (ความสูงระดับ 1 - สั้นที่สุด)'},
    {'level': 2, 'label': '62mm (ความสูงระดับ 2 - สั้น)'},
    {'level': 3, 'label': '62mm (ความสูงระดับ 3 - ปานกลาง)'},
    {'level': 4, 'label': '62mm (ความสูงระดับ 4 - ยาว)'},
    {'level': 5, 'label': '62mm (ความสูงระดับ 5 - ยาวมาก)'},
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

    _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    if (Platform.isAndroid) {
      await [
        Permission.bluetooth,
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.location,
        Permission.camera,
      ].request();
    }
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
      Product? product = await apiService.getProductByBarcode(code);
      if (product == null) {
        product = await apiService.getProductByCode(code);
      }

      setState(() {
        scannedProduct = product;
        if (product == null) {
          errorMessage = "ไม่พบสินค้า รหัส: $code";
        }
      });
    } catch (e) {
      setState(() => errorMessage = "เกิดข้อผิดพลาดในการเชื่อมต่อ: $e");
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

  // [ปรับปรุง] กลับไปใช้ Dialog แบบเรียบง่าย
  void _showPrintSettingsDialog() {
    int quantity = 1;
    brother.Orientation selectedOrientation = brother.Orientation.PORTRAIT;
    
    // ใช้ตัวแปร Local
    int tempHeightLevel = _currentHeightLevel;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text('ตั้งค่าการพิมพ์', style: GoogleFonts.kanit(fontWeight: FontWeight.bold)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // --- ส่วนเลือกขนาดความสูง (บนกระดาษ 62mm) ---
                    Row(
                      children: [
                        Icon(Icons.receipt_long, color: Colors.blue[700]),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text('ขนาดป้าย (62mm):', style: GoogleFonts.kanit(fontSize: 16)),
                        ),
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
                        child: DropdownButton<int>(
                          value: tempHeightLevel,
                          isExpanded: true,
                          items: heightOptions.map((option) {
                            return DropdownMenuItem<int>(
                              value: option['level'] as int,
                              child: Text(
                                option['label'] as String,
                                style: GoogleFonts.kanit(fontSize: 14),
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setStateDialog(() => tempHeightLevel = val);
                              this.setState(() => _currentHeightLevel = val);
                            }
                          },
                        ),
                      ),
                    ),
              
                    const SizedBox(height: 15),
                    // --- ส่วนเลือกแนวตั้ง/นอน ---
                    Row(
                      children: [
                        Icon(Icons.rotate_right, color: Colors.blue[700]),
                        const SizedBox(width: 10),
                        Text('แนวการพิมพ์:', style: GoogleFonts.kanit(fontSize: 16)),
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
                        child: DropdownButton<brother.Orientation>(
                          value: selectedOrientation,
                          isExpanded: true,
                          items: [
                            DropdownMenuItem(
                              value: brother.Orientation.PORTRAIT,
                              child: Text('แนวตั้ง (Portrait)', style: GoogleFonts.kanit(fontSize: 16)),
                            ),
                            DropdownMenuItem(
                              value: brother.Orientation.LANDSCAPE,
                              child: Text('แนวนอน (Landscape)', style: GoogleFonts.kanit(fontSize: 16)),
                            ),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setStateDialog(() => selectedOrientation = val);
                            }
                          },
                        ),
                      ),
                    ),
              
                    // --- ส่วนเลือกจำนวน ---
                    const SizedBox(height: 20),
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
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline),
                          onPressed: () {
                            if (quantity > 1) setStateDialog(() => quantity--);
                          },
                        ),
                        Text('$quantity', style: GoogleFonts.kanit(fontSize: 22, fontWeight: FontWeight.bold)),
                        IconButton(
                          icon: const Icon(Icons.add_circle_outline, color: Colors.blue),
                          onPressed: () => setStateDialog(() => quantity++),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('ยกเลิก', style: GoogleFonts.kanit(color: Colors.grey)),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    // กลับไปใช้ฟังก์ชันพิมพ์แบบมาตรฐาน
                    _executePrint(quantity, selectedOrientation);
                  },
                  icon: const Icon(Icons.print),
                  label: Text('พิมพ์', style: GoogleFonts.kanit()),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<Uint8List?> _capturePngFromWidget() async {
    try {
      await Future.delayed(const Duration(milliseconds: 200)); 
      RenderRepaintBoundary boundary = _printKey.currentContext!
          .findRenderObject() as RenderRepaintBoundary;
      
      ui.Image image = await boundary.toImage(pixelRatio: 3.0); 
      ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (e) {
      debugPrint("Error capturing image: $e");
      return null;
    }
  }

  Future<ui.Image> _bytesToImage(Uint8List bytes) async {
    final Completer<ui.Image> completer = Completer();
    ui.decodeImageFromList(bytes, (ui.Image img) {
      completer.complete(img);
    });
    return completer.future;
  }

  // [ปรับปรุง] กลับมาใช้วิธีตั้งค่าแบบดั้งเดิมที่เคยทำงานได้
  Future<void> _executePrint(
    int qty, 
    brother.Orientation orientation, 
  ) async {
    if (scannedProduct == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => Center(
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              CircularProgressIndicator(),
              SizedBox(height: 15),
              Text("กำลังส่งข้อมูลไปยังเครื่องพิมพ์...")
            ],
          ),
        ),
      ),
    );

    try {
      Uint8List? imageBytes = await _capturePngFromWidget();

      if (imageBytes != null) {
        
        var printer = brother.Printer();
        var printInfo = brother.PrinterInfo();

        printInfo.printerModel = brother.Model.QL_820NWB;
        printInfo.port = brother.Port.BLUETOOTH;
        printInfo.orientation = orientation;
        printInfo.numberOfCopies = 1; 
        
        // [สำคัญ] ใช้วิธี ordinalFromID แบบเดิมที่เคยทำงานได้
        // ไม่ต้องมี Logic เช็ค Red/Black หรือขนาดอื่นๆ บังคับ 62mm ไปเลย
        printInfo.labelNameIndex = QL700.ordinalFromID(QL700.W62.getId());
        
        printInfo.isAutoCut = true;
        printInfo.printMode = brother.PrintMode.FIT_TO_PAGE;
        printInfo.align = brother.Align.CENTER;
        printInfo.valign = brother.VAlign.MIDDLE;

        printer.setPrinterInfo(printInfo);

        List<brother.BluetoothPrinter> printers = await printer.getBluetoothPrinters([brother.Model.QL_820NWB.getName()]);

        if (printers.isEmpty) {
           throw Exception("ไม่พบเครื่องพิมพ์ QL-820NWB (Bluetooth)\nกรุณาเปิดเครื่องและ Pair Bluetooth");
        }

        printInfo.macAddress = printers.first.macAddress;
        printer.setPrinterInfo(printInfo);

        ui.Image img = await _bytesToImage(imageBytes);

        for (int i = 0; i < qty; i++) {
           brother.PrinterStatus status = await printer.printImage(img);
           
           if (status.errorCode != brother.ErrorCode.ERROR_NONE) {
             throw Exception("พิมพ์ไม่สำเร็จ (Error: ${status.errorCode})");
           }
        }
        
        Navigator.pop(context); 
        
        ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(
             content: Text('พิมพ์สำเร็จ!'), 
             backgroundColor: Colors.green
           ),
        );
      } else {
        throw Exception("ไม่สามารถจับภาพหน้าจอได้");
      }
    } catch (e) {
      Navigator.pop(context); 
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('เกิดข้อผิดพลาด', style: GoogleFonts.kanit(color: Colors.red, fontWeight: FontWeight.bold)),
          content: Text(e.toString().replaceAll("Exception:", ""), style: GoogleFonts.kanit()),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("ตกลง"),
            )
          ],
        ),
      );
    }
  }

  void _printLabel() {
    if (scannedProduct == null) return;
    _showPrintSettingsDialog();
  }

  String _addCommas(String price) {
    RegExp reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    return price.replaceAllMapped(reg, (Match m) => '${m[1]},');
  }

  @override
  Widget build(BuildContext context) {
    if (isScanning) {
      // ... (Scanner code same as before)
      return Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            MobileScanner(
              controller: cameraController,
              onDetect: _onDetect,
              fit: BoxFit.cover, 
            ),
            Center(
              child: Container(
                width: 280,
                height: 180,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.redAccent, width: 3),
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
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
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text(
          'WG wanawat',
          style: GoogleFonts.kanit(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        centerTitle: true,
        backgroundColor: Colors.blue[800],
        elevation: 0,
      ),
      body: Column(
        children: [
          // ... (Printer Dropdown same as before)
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
                        hint: Text("เลือกเครื่องพิมพ์", style: GoogleFonts.kanit(color: Colors.grey)),
                        isExpanded: true,
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
                      Column(
                        children: [
                          Text(
                            // แสดงระดับความสูงที่เลือก
                            "ขนาดป้าย: 62mm (ความสูงระดับ $_currentHeightLevel)",
                            style: GoogleFonts.kanit(color: Colors.grey[600], fontSize: 12),
                          ),
                          const SizedBox(height: 10),
                          
                          RepaintBoundary(
                            key: _printKey,
                            child: Container(
                              color: Colors.white,
                              // บังคับความกว้างเป็น 62mm เสมอ (คูณ 5 เพื่อความละเอียด)
                              width: 62.0 * 5.0,
                              alignment: Alignment.topCenter, 
                              child: _showBarcodeOnly
                                  ? _buildBarcodeOnlyTag(scannedProduct!, _currentHeightLevel)
                                  : _buildPriceTag(scannedProduct!, _currentHeightLevel),
                            ),
                          ),
                        ],
                      )
                    else
                      _buildPlaceholderFrame(),
                  ],
                ),
              ),
            ),
          ),
          
          // ... (Bottom Buttons same as before)
          Container(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
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
                      style: GoogleFonts.kanit(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[700],
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                    label: Text('ค้นหาสินค้าจากเลขรหัส', style: GoogleFonts.kanit(fontSize: 16)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.grey[800],
                      side: BorderSide(color: Colors.grey[300]!),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                
                if (scannedProduct != null) ...[
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => setState(() => _showBarcodeOnly = false),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: !_showBarcodeOnly ? Colors.blue[100] : Colors.grey[100],
                            foregroundColor: !_showBarcodeOnly ? Colors.blue[800] : Colors.grey[600],
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: Text('แบบป้ายราคา', style: GoogleFonts.kanit(fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => setState(() => _showBarcodeOnly = true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _showBarcodeOnly ? Colors.blue[100] : Colors.grey[100],
                            foregroundColor: _showBarcodeOnly ? Colors.blue[800] : Colors.grey[600],
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: Text('แบบบาร์โค้ด', style: GoogleFonts.kanit(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: scannedProduct != null ? _showPrintSettingsDialog : null,
                          icon: const Icon(Icons.settings_outlined, size: 20),
                          label: Text('ตั้งค่ากระดาษ', style: GoogleFonts.kanit(fontSize: 14)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.grey[700],
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            side: BorderSide(color: Colors.grey[300]!),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: scannedProduct != null ? _printLabel : null,
                          icon: const Icon(Icons.print, size: 20),
                          label: Text('พิมพ์สินค้า', style: GoogleFonts.kanit(fontSize: 14)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green[600],
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ... (_buildPlaceholderFrame, _buildErrorView same)
  Widget _buildPlaceholderFrame() {
    return Container(
      width: double.infinity,
      height: 250,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300, width: 2),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.label_outline, size: 60, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            'รอข้อมูลสินค้า',
            style: GoogleFonts.kanit(fontSize: 20, color: Colors.grey[400], fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text('กรุณาสแกนหรือค้นหาสินค้า', style: GoogleFonts.kanit(color: Colors.grey[400])),
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
          const Icon(Icons.error_outline, color: ui.Color.fromARGB(255, 190, 187, 187)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(errorMessage!, style: GoogleFonts.kanit(color: Colors.black)),
          ),
        ],
      ),
    );
  }

  // [ปรับปรุง] ใช้ layoutWidth ในการคำนวณ UI เหมือนเดิม
  Widget _buildPriceTag(Product item, int heightLevel) {
    
    // ตั้งค่าตามระดับความสูง 1-5 (1=สั้นสุด, 5=ยาวสุด)
    double paddingVal = 0;
    double gapVal = 0;
    double lineHeight = 1.0;

    switch (heightLevel) {
      case 1: // สั้นที่สุด
        paddingVal = 1.0;
        gapVal = 0;
        lineHeight = 0.8;
        break;
      case 2: // สั้น
        paddingVal = 4.0;
        gapVal = 1.0;
        lineHeight = 0.9;
        break;
      case 3: // ปานกลาง (มาตรฐาน)
        paddingVal = 8.0;
        gapVal = 2.0;
        lineHeight = 1.0;
        break;
      case 4: // ยาว
        paddingVal = 12.0;
        gapVal = 4.0;
        lineHeight = 1.1;
        break;
      case 5: // ยาวมาก
        paddingVal = 16.0;
        gapVal = 6.0;
        lineHeight = 1.2;
        break;
      default:
        paddingVal = 8.0;
    }

    // Scale Factor คงที่เพราะใช้ 62mm ตลอด
    double scale = 1.0; 

    final double notMemberPrice = item.cashNotMember;
    final double memberPrice = item.cashMember;
    final normalParts = notMemberPrice.toStringAsFixed(2).split('.');
    final bigPrice = _addCommas(normalParts[0]);
    final decimal = normalParts[1];
    final memberParts = memberPrice.toStringAsFixed(2).split('.');
    final memberBigPrice = _addCommas(memberParts[0]);
    final memberDecimal = memberParts[1];
    final dateStr = item.maxDate;

    return Container(
      width: 62.0 * 5.0, 
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4), 
        boxShadow: const [BoxShadow(blurRadius: 2, color: Colors.black12)], 
        border: Border.all(color: Colors.grey.shade300),
      ),
      padding: EdgeInsets.all(paddingVal),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min, 
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'รหัส: ${item.segment1}',
                style: GoogleFonts.sarabun(
                  fontWeight: FontWeight.bold,
                  fontSize: 14 * scale,
                  height: lineHeight, 
                ),
              ),
            ],
          ),
          SizedBox(height: gapVal * scale),
          Text(
            item.description,
            style: GoogleFonts.sarabun(
              fontSize: 18 * scale,
              color: Colors.black87,
              fontWeight: FontWeight.bold,
              height: lineHeight,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          Divider(height: (4 + gapVal) * scale, thickness: 0.5),
          
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Container(
                    padding: EdgeInsets.only(right: 4 * scale), 
                    decoration: BoxDecoration(
                      border: Border(
                        right: BorderSide(color: Colors.grey.shade300, width: 0.5),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 4 * scale,
                            vertical: 1 * scale,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(2),
                          ),
                          child: Text(
                            'ราคาสมาชิก',
                            style: GoogleFonts.sarabun(
                              color: Colors.black,
                              fontSize: 11 * scale,
                              fontWeight: FontWeight.bold,
                              height: 1.0,
                            ),
                          ),
                        ),
                        SizedBox(height: gapVal * scale), 
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              memberBigPrice,
                              style: GoogleFonts.sarabun(
                                fontSize: 26 * scale,
                                fontWeight: FontWeight.w800,
                                color: Colors.black,
                                height: 0.85, 
                              ),
                            ),
                            Text(
                              '.$memberDecimal',
                              style: GoogleFonts.sarabun(
                                fontSize: 14 * scale,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
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
                    padding: EdgeInsets.only(left: 4 * scale), 
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                         Row(
                           mainAxisAlignment: MainAxisAlignment.end,
                           children: [
                             Text(
                               item.primaryUomCode,
                               style: GoogleFonts.sarabun(
                                 fontSize: 10 * scale,
                                 color: Colors.black,
                                 height: 1.0,
                               ),
                             ),
                             SizedBox(width: 2 * scale),
                             Container(
                               padding: EdgeInsets.symmetric(
                                 horizontal: 4 * scale,
                                 vertical: 1 * scale,
                               ),
                               decoration: BoxDecoration(
                                 color: Colors.grey[200],
                                 borderRadius: BorderRadius.circular(2),
                               ),
                               child: Text(
                                 'ราคาทั่วไป',
                                 style: GoogleFonts.sarabun(
                                   color: Colors.black,
                                   fontSize: 10 * scale,
                                   fontWeight: FontWeight.bold,
                                   height: 1.0,
                                 ),
                               ),
                             ),
                           ],
                         ),
                        SizedBox(height: gapVal * scale),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              bigPrice,
                              style: GoogleFonts.sarabun(
                                fontSize: 32 * scale,
                                fontWeight: FontWeight.w900,
                                color: Colors.black,
                                height: 0.85, 
                              ),
                            ),
                            Text(
                              '.$decimal',
                              style: GoogleFonts.sarabun(
                                fontSize: 16 * scale,
                                fontWeight: FontWeight.w900,
                                color: Colors.black,
                              ),
                            ),
                          ],
                        ),
                        
                        SizedBox(height: (2 + gapVal) * scale),
                        
                        // [ปรับปรุง] Barcode Image -> ใช้รหัส Oracle (segment1)
                        SizedBox(
                          height: 45 * scale, 
                          child: (item.segment1.isNotEmpty) 
                              ? Image.network(
                                  'https://barcode.tec-it.com/barcode.ashx?data=${item.segment1}&code=Code128&translate-esc=on',
                                  fit: BoxFit.fill, 
                                  errorBuilder: (c, e, s) => const SizedBox(),
                                )
                              : const Center(child: Text("-")),
                        ),
                        
                        // [ปรับปรุง] แสดงแค่รหัส 885 (crossReference) อันเดียว
                        Text(
                          item.crossReference,
                          textAlign: TextAlign.right,
                          style: GoogleFonts.sarabun(
                            fontSize: 10 * scale,
                            letterSpacing: 1.0,
                            height: 0.8,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: gapVal * scale),
          const Divider(height: 2, thickness: 0.5), 
          Text(
            'ราคา ณ วันที่: $dateStr',
            style: GoogleFonts.sarabun(
              fontSize: 10 * scale,
              color: Colors.black,
              fontStyle: FontStyle.italic,
              height: 1.0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBarcodeOnlyTag(Product item, int heightLevel) {
    
    // ตั้งค่าตามระดับความสูง 1-5
    double paddingVal = 0;
    double gapVal = 0;
    double lineHeight = 1.0;

    switch (heightLevel) {
      case 1:
        paddingVal = 4.0;
        gapVal = 2.0;
        lineHeight = 0.9;
        break;
      case 2:
        paddingVal = 8.0;
        gapVal = 4.0;
        lineHeight = 1.0;
        break;
      case 3:
        paddingVal = 12.0;
        gapVal = 6.0;
        lineHeight = 1.0;
        break;
      case 4:
        paddingVal = 16.0;
        gapVal = 8.0;
        lineHeight = 1.1;
        break;
      case 5:
        paddingVal = 20.0;
        gapVal = 10.0;
        lineHeight = 1.2;
        break;
      default:
        paddingVal = 12.0;
    }

    double scale = 1.0;

    return Container(
      width: 62.0 * 5.0, 
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        boxShadow: const [BoxShadow(blurRadius: 2, color: Colors.black12)],
        border: Border.all(color: Colors.grey.shade300),
      ),
      padding: EdgeInsets.symmetric(vertical: paddingVal * scale, horizontal: 8.0), 
      child: Column(
        mainAxisSize: MainAxisSize.min, 
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            item.description,
            style: GoogleFonts.sarabun(
              fontSize: 24 * scale,
              color: Colors.black87,
              fontWeight: FontWeight.bold,
              height: lineHeight, 
            ),
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: gapVal * scale), 
          
          // [ปรับปรุง] Barcode Image -> ใช้รหัส Oracle (segment1)
          Container(
            height: 90 * scale, 
            width: double.infinity,
            alignment: Alignment.center,
            child: (item.segment1.isNotEmpty)
                ? Image.network(
                    'https://barcode.tec-it.com/barcode.ashx?data=${item.segment1}&code=Code128&translate-esc=on',
                    fit: BoxFit.fill, 
                    errorBuilder: (c, e, s) => const Icon(
                      Icons.broken_image,
                      color: Colors.grey,
                    ),
                  )
                : const Center(child: Text("-")),
          ),
          SizedBox(height: gapVal * scale),
          
          // [ปรับปรุง] แสดงแค่รหัส 885 (crossReference)
          Text(
            item.crossReference,
            style: GoogleFonts.sarabun(
              fontSize: 22 * scale,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
              height: 0.9,
            ),
          ),
        ],
      ),
    );
  }
}