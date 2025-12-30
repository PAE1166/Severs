from flask import Flask, jsonify
from flask_cors import CORS
import pyodbc
import os                       
from dotenv import load_dotenv  

# 3. สั่งให้โหลดค่าจากไฟล์ .env เข้ามาในระบบ
load_dotenv()

app = Flask(__name__)
CORS(app)

server = os.getenv('SERVER')
database = os.getenv('DATABASE')
client_id = os.getenv('CLIENT_ID')
client_secret = os.getenv('CLIENT_SECRET')
tenant_id = os.getenv('TENANT_ID')

# Connection String (ใช้ตัวแปรเหมือนเดิมได้เลย)
conn_str = (
    f"DRIVER={{ODBC Driver 18 for SQL Server}};"
    f"SERVER={server},1433;" 
    f"DATABASE={database};"
    f"Authentication=ActiveDirectoryServicePrincipal;"
    f"UID={client_id};"
    f"PWD={client_secret};"
    f"Encrypt=yes;"
    f"TrustServerCertificate=no;"
)

# ... (ส่วนที่เหลือของโค้ดเหมือนเดิมครับ) ...

# ==========================================
# สร้าง API (ประตูให้ Flutter เข้ามาดึง)
# ==========================================
@app.route('/api/products', methods=['GET'])
def get_products():
    try:
        # 1. เชื่อมต่อฐานข้อมูล
        conn = pyodbc.connect(conn_str)
        cursor = conn.cursor()
        
        # 2. Query ข้อมูล (ผมเอา TOP 5 ออก เพื่อให้โชว์สินค้าทั้งหมด)
        cursor.execute("SELECT * FROM dbo.Products_Price2")
        
        # 3. แปลงข้อมูลจาก Database ให้เป็น JSON (เพื่อให้ Flutter อ่านออก)
        columns = [column[0] for column in cursor.description] # ดึงชื่อหัวตาราง
        results = []
        for row in cursor.fetchall():
            # จับคู่ ชื่อคอลัมน์: ข้อมูล (เช่น 'ProductName': 'หลอดไฟ')
            results.append(dict(zip(columns, row)))
            
        conn.close()
        
        # 4. ส่งกลับไปให้ Flutter
        return jsonify(results)

    except Exception as e:
        print("Error:", e) # ปริ้นท์ error ดูในคอม
        return jsonify({'error': str(e)}), 500

# ==========================================
# สั่งรัน Server
# ==========================================
if __name__ == '__main__':
    # รันที่ port 5000
    app.run(host='0.0.0.0', port=5000, debug=True)