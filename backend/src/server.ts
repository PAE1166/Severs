// src/server.ts
import 'dotenv/config';
import express from 'express';
import cors from 'cors';
import { db } from './db';
import { products } from './db/schema';
import { eq } from 'drizzle-orm'; // อย่าลืม import eq เพิ่มข้างบนสุด

const app = express();
app.use(cors()); // อนุญาตให้ทุกแอปเชื่อมต่อได้ (สำหรับการทดสอบ)

// สร้างเส้นทาง (Route) ชื่อ /products
app.get('/products', async (req, res) => {
  try {
    console.log("📲 มีแอปติดต่อขอข้อมูลเข้ามา...");
    const allProducts = await db.select().from(products);
    res.json(allProducts); // ส่งข้อมูลกลับไปเป็น JSON
  } catch (error) {
    console.error(error);
    res.status(500).json({ error: 'ดึงข้อมูลไม่สำเร็จ' });
  }
});

app.get('/products/:barcode', async (req, res) => {
  const barcode = req.params.barcode;
  console.log(`🔎 กำลังค้นหาสินค้า: ${barcode}`);

  try {
    // สมมติว่าค้นหาจาก column 'id' หรือ 'cross_ref' (Barcode)
    // ตรงนี้ผมใช้ ID เพื่อทดสอบง่ายๆ แต่นายท่านเป้เปลี่ยนเป็น cross_ref ได้
    const product = await db.select().from(products)
      .where(eq(products.cross_ref, barcode)) // หรือ eq(products.cross_ref, barcode)
      .limit(1);

    if (product.length > 0) {
      res.json(product[0]); // เจอสินค้า ส่งกลับไปตัวเดียว
    } else {
      res.status(404).json({ error: 'ไม่พบสินค้า' });
    }
  } catch (error) {
    console.error(error);
    res.status(500).json({ error: 'Server Error' });
  }
});

// เปิด Server รอรับลูกค้าที่ Port 3000
const PORT = 3000;
app.listen(PORT, '0.0.0.0', () => {
  console.log(`✅ API Server พร้อมทำงานแล้วที่ http://localhost:${PORT}`);
});