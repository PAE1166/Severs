// test-query.ts
import 'dotenv/config'; // โหลดค่า .env ก่อน
import { db } from './src/db'; // เรียกตัวเชื่อมต่อจากข้อ 1
import { products } from './src/db/schema'; // เรียกตารางสินค้า

async function main() {
  console.log("⏳ กำลังดึงข้อมูลจาก Neon...");
  
  // คำสั่งดึงข้อมูลสินค้าทั้งหมด (เหมือน SELECT * FROM products)
  const allProducts = await db.select().from(products).limit(5);

  console.log("✅ ได้ข้อมูลมาแล้ว:");
  console.log(allProducts);
}

main();