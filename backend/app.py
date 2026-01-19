from flask import Flask, jsonify, request
from flask_cors import CORS
import pyodbc
import os                       
from dotenv import load_dotenv  

load_dotenv()

app = Flask(__name__)
CORS(app)

server = os.getenv('SERVER')
database = os.getenv('DATABASE')
client_id = os.getenv('CLIENT_ID')
client_secret = os.getenv('CLIENT_SECRET')
tenant_id = os.getenv('TENANT_ID')

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


@app.route('/api/products', methods=['GET'])

def get_products():
    conn = None
    try:
        conn = pyodbc.connect(conn_str)
        cursor = conn.cursor()
        
        barcode = request.args.get('barcode')
        sku = request.args.get('sku')

        if barcode:
            sql_query = "SELECT * FROM [dbo].[Products_Price2] WHERE CROSS_REFERENCE = ?"
            cursor.execute(sql_query, barcode)
            
        elif sku:
            sql_query = "SELECT * FROM [dbo].[Products_Price2] WHERE SEGMENT1 = ?"
            cursor.execute(sql_query, sku)
            
        else:
            sql_query = "SELECT TOP 50 * FROM [dbo].[Products_Price2]"
            cursor.execute(sql_query)
        
        columns = [column[0] for column in cursor.description]
        results = []
        for row in cursor.fetchall():
            results.append(dict(zip(columns, row)))
            
        return jsonify(results)

    except Exception as e:
        print("Error:", e)
        return jsonify({'error': str(e)}), 500
        
    finally:
        if conn:
            conn.close()


if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=True)