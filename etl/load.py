import os
import time
import pandas as pd
import psycopg2
from psycopg2.extras import execute_values
from dotenv import load_dotenv

load_dotenv()

# ─────────────────────────────────────────
# CONEXIÓN
# ─────────────────────────────────────────
def get_connection():
    return psycopg2.connect(
        host     = os.getenv("DB_HOST", "localhost"),
        port     = os.getenv("DB_PORT", "5432"),
        dbname   = os.getenv("DB_NAME", "flights_dw"),
        user     = os.getenv("DB_USER", "postgres"),
        password = os.getenv("DB_PASSWORD", "")
    )


# ─────────────────────────────────────────
# CREAR ESQUEMA
# ─────────────────────────────────────────
def crear_esquema(conn):
    print("Creando esquema en PostgreSQL...")
    with open("sql/ddl_schema.sql", "r", encoding="utf-8") as f:
        sql = f.read()
    with conn.cursor() as cur:
        cur.execute(sql)
    conn.commit()
    print("Esquema creado correctamente")


# ─────────────────────────────────────────
# CARGA DIMENSIONES
# ─────────────────────────────────────────
def cargar_dimension(conn, df, tabla, columnas_sin_id):
    inicio = time.time()

    rows = [tuple(row) for row in df[columnas_sin_id].itertuples(index=False)]
    cols = ", ".join(columnas_sin_id)
    sql  = f"INSERT INTO {tabla} ({cols}) VALUES %s ON CONFLICT DO NOTHING"

    LOTE = 10_000
    with conn.cursor() as cur:
        for i in range(0, len(rows), LOTE):
            execute_values(cur, sql, rows[i:i+LOTE])
            print(f"   → {min(i+LOTE, len(rows)):,} / {len(rows):,}", end="\r")
    conn.commit()

    elapsed = time.time() - inicio
    return elapsed

