import 'package:flutter/material.dart';
import 'package:o3d/o3d.dart'; // พระเอก 3D
import 'package:audioplayers/audioplayers.dart'; // พระเอกเสียง
import 'scan_screen.dart'; // หน้าต่อไป

class IntroScreen extends StatefulWidget {
  const IntroScreen({super.key});

  @override
  State<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen> {
  final O3DController controller = O3DController();
  final AudioPlayer player = AudioPlayer(); // สร้างตัวเล่นเสียง

  @override
  void initState() {
    super.initState();

    // 1. สั่งเล่นเสียงทันทีที่เข้าหน้า
    setupAudio();

    // 2. นับถอยหลัง 5 วินาที แล้วไปหน้า ScanScreen
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const ScanScreen()),
        );
      }
    });
  }

  // ฟังก์ชันตั้งค่าและเล่นเสียง
  Future<void> setupAudio() async {
    // กำหนดให้เล่นเสียงจาก assets/welcome.mp3
    await Future.delayed(const Duration(milliseconds: 3200));
    await player.play(AssetSource('welcome.mp3'));
  }

  @override
  void dispose() {
    player.dispose(); // ปิดตัวเล่นเสียงเมื่อเปลี่ยนหน้า (คืน Ram)
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // ส่วนแสดงผล 3D
          Center(
            child: O3D(
              src: 'assets/aj.glb',
              controller: controller,
              autoPlay: true, // เดินอัตโนมัติ
              autoRotate: false,
              cameraControls: false,
              ar: false,
            ),
          ),

          // ส่วนข้อความด้านล่าง
          Positioned(
            bottom: 80,
            left: 0,
            right: 0,
            child: Column(
              children: [
                const Text(
                  "Wanawat สวัสดีครับ",
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 20),
                const CircularProgressIndicator(color: Colors.orange),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
