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
        password = os.getenv("DB_PASSWORD", "5267")
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



def cargar_fact_copy(conn):
    inicio = time.time()

    # Obtener mapeos de IDs reales desde PostgreSQL
    with conn.cursor() as cur:
        cur.execute("SELECT tiempo_id, fecha FROM dim_tiempo")
        tiempo_map = {str(r[1]): r[0] for r in cur.fetchall()}

        cur.execute("SELECT aerolinea_id, codigo FROM dim_aerolinea")
        aerolinea_map = {r[1]: r[0] for r in cur.fetchall()}

        cur.execute("SELECT aeropuerto_id, codigo FROM dim_aeropuerto")
        aeropuerto_map = {r[1]: r[0] for r in cur.fetchall()}

        cur.execute("SELECT estado_id, codigo FROM dim_estado_vuelo")
        estado_map = {r[1]: r[0] for r in cur.fetchall()}

    # Leer fact del staging
    df = pd.read_parquet("staging/processed/fact_vuelos.parquet")
    
    # Renombrar columnas en inglés a español
    df = df.rename(columns={
    "Cancelled": "cancelado",
    "Diverted":  "desviado"
    })
    
    # Convertir fecha_vuelo a string para el mapeo
    df["fecha_vuelo"] = pd.to_datetime(df["fecha_vuelo"]).dt.date

    # Remapear IDs usando los valores reales de PostgreSQL
    df["tiempo_id"]             = df["fecha_vuelo"].map(lambda x: tiempo_map.get(str(x)))
    df["aerolinea_id"]          = df["aerolinea_id"].map(
        lambda x: list(aerolinea_map.values())[x-1] if x <= len(aerolinea_map) else x
    )
    df["aeropuerto_origen_id"]  = df["aeropuerto_origen_id"].map(
        lambda x: list(aeropuerto_map.values())[x-1] if x <= len(aeropuerto_map) else x
    )
    df["aeropuerto_destino_id"] = df["aeropuerto_destino_id"].map(
        lambda x: list(aeropuerto_map.values())[x-1] if x <= len(aeropuerto_map) else x
    )
    df["estado_id"] = df["estado_id"].map(
        lambda x: list(estado_map.values())[x-1] if x <= len(estado_map) else x
    )

    # Columnas a cargar
    columnas = [
        "tiempo_id", "aerolinea_id", "aeropuerto_origen_id",
        "aeropuerto_destino_id", "estado_id", "fecha_vuelo",
        "retraso_salida", "retraso_llegada", "tiempo_vuelo", "distancia",
        "cancelado", "desviado", "retraso_aerolinea", "retraso_clima",
        "retraso_nas", "retraso_seguridad", "retraso_aeronave"
    ]

    # Guardar CSV temporal
    csv_temp = "staging/processed/fact_temp.csv"
    print("   → Generando CSV temporal...")
    df[columnas].to_csv(csv_temp, index=False, header=False)

    # Ejecutar COPY
    with conn.cursor() as cur:
        with open(csv_temp, "r", encoding="utf-8") as f:
            cur.copy_expert(
                f"COPY fact_vuelos ({', '.join(columnas)}) FROM STDIN WITH CSV NULL ''",
                f
            )
    conn.commit()

    elapsed = time.time() - inicio
    return elapsed


# ─────────────────────────────────────────
# MAIN
# ─────────────────────────────────────────
def load():
    print("=== CARGA A POSTGRESQL ===\n")
    conn = get_connection()
    print("Conexión exitosa a PostgreSQL\n")

    crear_esquema(conn)

    tiempos = {}

    # Cargar dimensiones
    df_tiempo = pd.read_parquet("staging/processed/dim_tiempo.parquet")
    tiempos["dim_tiempo"] = cargar_dimension(conn, df_tiempo, "dim_tiempo", [
        "fecha", "dia", "mes", "trimestre",
        "anio", "dia_semana", "nombre_mes", "nombre_dia", "es_fin_semana"
    ])

    df_aerolinea = pd.read_parquet("staging/processed/dim_aerolinea.parquet")
    tiempos["dim_aerolinea"] = cargar_dimension(conn, df_aerolinea, "dim_aerolinea", [
        "codigo", "nombre"
    ])

    df_aeropuerto = pd.read_parquet("staging/processed/dim_aeropuerto.parquet")
    tiempos["dim_aeropuerto"] = cargar_dimension(conn, df_aeropuerto, "dim_aeropuerto", [
        "codigo", "ciudad", "estado", "nombre_estado", "pais"
    ])

    df_estado = pd.read_parquet("staging/processed/dim_estado_vuelo.parquet")
    tiempos["dim_estado_vuelo"] = cargar_dimension(conn, df_estado, "dim_estado_vuelo", [
        "codigo", "descripcion"
    ])

    tiempos["fact_vuelos"] = cargar_fact_copy(conn)

    conn.close()

    print("\n══════════════════════════════")
    print("CARGA COMPLETA")
    print("══════════════════════════════")
    for tabla, t in tiempos.items():
        print(f"   {tabla}: {t:.1f}s")
    print(f"   TOTAL: {sum(tiempos.values()):.1f}s")


if __name__ == "__main__":
    load()