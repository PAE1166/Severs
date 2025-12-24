import 'package:flutter/material.dart';
// 👇 1. อย่าลืมบรรทัดนี้ครับ (Import หน้าสแกนเข้ามา)
import 'screens/scan_screen.dart'; 

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Neon Scanner',
      theme: ThemeData(
        primarySwatch: Colors.teal,
        useMaterial3: true,
      ),
      // 👇 2. เปลี่ยนตรงนี้จาก ProductListScreen() เป็น ScanScreen()
      home: const ScanScreen(), 
    );
  }
}