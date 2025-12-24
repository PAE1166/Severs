// src/db/index.ts
import { neon } from '@neondatabase/serverless';
import { drizzle } from 'drizzle-orm/neon-http';
import * as schema from './schema'; // ดึง schema ที่เราเพิ่งสร้างมาใช้

// เชื่อมต่อด้วย URL จาก .env
const sql = neon(process.env.DATABASE_URL!);

// สร้างตัวแปร db หลักสำหรับใช้งาน
export const db = drizzle(sql, { schema });