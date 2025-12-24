import 'dotenv/config';
import { defineConfig } from 'drizzle-kit';

export default defineConfig({
  schema: './src/db/schema.ts', // ชี้ไปที่ไฟล์ Schema ของเรา
  out: './drizzle',             // โฟลเดอร์ที่จะเก็บไฟล์ Migration
  dialect: 'postgresql',
  dbCredentials: {
    url: process.env.DATABASE_URL!,
  },
});