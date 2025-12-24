# ใช้ Python เวอร์ชันเล็กแต่ครบ
FROM python:3.10-slim

# 1. ติดตั้ง System Dependencies ที่จำเป็นสำหรับ ODBC Driver
RUN apt-get update && apt-get install -y \
    curl \
    gnupg2 \
    unixodbc-dev \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

# 2. ติดตั้ง Microsoft ODBC Driver 18 for SQL Server
RUN curl https://packages.microsoft.com/keys/microsoft.asc | apt-key add - \
    && curl https://packages.microsoft.com/config/debian/11/prod.list > /etc/apt/sources.list.d/mssql-release.list \
    && apt-get update \
    && ACCEPT_EULA=Y apt-get install -y msodbcsql18

# 3. ตั้งค่าโฟลเดอร์ทำงาน
WORKDIR /app

# 4. ก๊อปปี้ไฟล์ทั้งหมดเข้า Docker
COPY . .

# 5. ติดตั้ง Library Python (Flask, pyodbc, etc.)
RUN pip install --no-cache-dir -r requirements.txt
RUN pip install gunicorn

# 6. เปิด Port 5000
EXPOSE 5000

# 7. สั่งรันแอปเมื่อ Container เริ่มทำงาน
CMD ["gunicorn", "-b", "0.0.0.0:5000", "app:app"]