import sql from 'mssql';

async function testSystem() {
    console.log('\n🔄 กำลังทดสอบเชื่อมต่อ OneLake...');

    // ลองแบบ 1: ใช้ SQL Authentication ธรรมดา
    const config: sql.config = {
        server: "uykm2uvnub3etmt3ln6wqgcrua-yl6r3jrm3eqerhvd4imuzb7ifu.datawarehouse.fabric.microsoft.com",
        database: "ProductStore",
        user: "tanakrit.k@rmutsvmail.com",
        password: "Sunshy134678@",
        options: {
            encrypt: true,
            trustServerCertificate: false,
            enableArithAbort: true
        },
        connectionTimeout: 30000,
        requestTimeout: 30000,
        port: 1433
    };

    try {
        console.log(`📡 Server: ${config.server}`);
        console.log(`📂 Database: ${config.database}`);
        
        // 1. เชื่อมต่อ
        const pool = await sql.connect(config);
        console.log('✅ เชื่อมต่อสำเร็จ! (Connected)');

        // 2. ดึงข้อมูล
        const result = await pool.request().query(`
            SELECT TOP 5 Barcode, ProductName, NormalPrice 
            FROM dbo.products
        `);

        console.log('\n✨ ผลลัพธ์:');
        console.table(result.recordset);
        
        await pool.close();
        console.log('👋 ปิดการเชื่อมต่อแล้ว');
        
    } catch (err: any) {
        console.error('\n❌ เชื่อมต่อไม่สำเร็จ:');
        console.error('Error Code:', err.code);
        console.error('Error Message:', err.message);
        console.error('Full Error:', err);

        // 💡 แนะนำแก้ไข
        console.log('\n⚠️ วิธีแก้ปัญหา:');
        
        if (err.code === 'ESOCKET' || err.message?.includes('socket')) {
            console.log('1. เปลี่ยนใช้ Hotspot มือถือแทนเน็ตมหาลัย');
        }
        
        if (err.message?.includes('Login failed')) {
            console.log('2. ตรวจสอบ Username/Password อีกครั้ง');
            console.log('3. ลองเข้า Portal Azure เพื่อยืนยัน credential');
        }
        
        if (err.message?.includes('Cannot open database')) {
            console.log('4. ตรวจสอบชื่อ Database ว่าถูกต้อง');
        }
        
        console.log('5. ตรวจสอบว่า Fabric Workspace เปิดอยู่');
        console.log('6. ลอง Refresh Token ใน Azure Portal');
    }
}

testSystem();