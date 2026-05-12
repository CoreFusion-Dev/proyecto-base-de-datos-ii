import os
import zipfile
import pandas as pd
from pathlib import Path

# ─────────────────────────────────────────
# CONFIGURACIÓN
# ─────────────────────────────────────────
RAW_DIR      = "staging/raw"
STAGING_DIR  = "staging/processed"
os.makedirs(STAGING_DIR, exist_ok=True)

# Columnas del CSV
COLUMNAS_UTILES = [
    "FlightDate",
    "Year", "Quarter", "Month", "DayofMonth", "DayOfWeek",
    "Reporting_Airline", "IATA_CODE_Reporting_Airline",
    "Origin", "OriginCityName", "OriginState", "OriginStateName",
    "Dest",   "DestCityName",   "DestState",   "DestStateName",
    "DepDelay", "ArrDelay", "AirTime", "Distance",
    "Cancelled", "CancellationCode", "Diverted",
    "CarrierDelay", "WeatherDelay", "NASDelay",
    "SecurityDelay", "LateAircraftDelay",
]

# ─────────────────────────────────────────
# LEER TODOS LOS ZIPS
# ─────────────────────────────────────────
def leer_todos_los_zips():
    print(" Leyendo archivos ZIP...")
    frames = []

    zip_files = sorted(Path(RAW_DIR).glob("*.zip"))
    print(f"   Archivos encontrados: {len(zip_files)}")

    for zip_path in zip_files:
        print(f"   → Procesando {zip_path.name}...")
        with zipfile.ZipFile(zip_path, 'r') as z:
            csv_name = [f for f in z.namelist() if f.endswith('.csv')][0]
            df = pd.read_csv(
                z.open(csv_name),
                usecols=COLUMNAS_UTILES,
                dtype={"CancellationCode": str}
            )
            frames.append(df)

    df_total = pd.concat(frames, ignore_index=True)
    print(f"\n Total filas leídas: {len(df_total):,}")
    return df_total


# ─────────────────────────────────────────
# LIMPIEZA DE DATOS
# ─────────────────────────────────────────
def limpiar(df):
    print("\n Limpiando datos...")
    print(f"   Filas antes: {len(df):,}")

    antes = len(df)
    df = df.dropna(subset=["FlightDate"])
    print(f"   - Eliminadas filas sin FlightDate: {antes - len(df):,}")

    df["FlightDate"] = pd.to_datetime(df["FlightDate"])

    cols_retraso = ["DepDelay", "ArrDelay", "AirTime",
                    "CarrierDelay", "WeatherDelay",
                    "NASDelay", "SecurityDelay", "LateAircraftDelay"]
    df[cols_retraso] = df[cols_retraso].fillna(0)

    df["Cancelled"] = df["Cancelled"].fillna(0).astype(bool)
    df["Diverted"]  = df["Diverted"].fillna(0).astype(bool)

    df["CancellationCode"] = df["CancellationCode"].fillna("N/A")

    antes = len(df)
    df = df.dropna(subset=["Distance"])
    print(f"   - Eliminadas filas sin Distance: {antes - len(df):,}")

    antes = len(df)
    df = df.drop_duplicates()
    print(f"   - Duplicados eliminados: {antes - len(df):,}")

    print(f"   Filas después: {len(df):,}")
    return df


# ─────────────────────────────────────────
# CONSTRUCCIÓN DE DIMENSIONES
# ─────────────────────────────────────────
def construir_dim_tiempo(df):
    print("\n Construyendo dim_tiempo...")
    NOMBRES_MES = {1:"Enero",2:"Febrero",3:"Marzo",4:"Abril",
                   5:"Mayo",6:"Junio",7:"Julio",8:"Agosto",
                   9:"Septiembre",10:"Octubre",11:"Noviembre",12:"Diciembre"}
    NOMBRES_DIA = {1:"Lunes",2:"Martes",3:"Miércoles",
                   4:"Jueves",5:"Viernes",6:"Sábado",7:"Domingo"}

    fechas = df[["FlightDate","Year","Quarter","Month",
                 "DayofMonth","DayOfWeek"]].drop_duplicates()

    dim = pd.DataFrame()
    dim["fecha"]       = fechas["FlightDate"].values
    dim["dia"]         = fechas["DayofMonth"].values
    dim["mes"]         = fechas["Month"].values
    dim["trimestre"]   = fechas["Quarter"].values
    dim["anio"]        = fechas["Year"].values
    dim["dia_semana"]  = fechas["DayOfWeek"].values
    dim["nombre_mes"]  = dim["mes"].map(NOMBRES_MES)
    dim["nombre_dia"]  = dim["dia_semana"].map(NOMBRES_DIA)
    dim["es_fin_semana"] = dim["dia_semana"].isin([6, 7])

    dim = dim.drop_duplicates(subset=["fecha"]).reset_index(drop=True)
    dim.insert(0, "tiempo_id", dim.index + 1)

    print(f"   Registros: {len(dim):,}")
    return dim


def construir_dim_aerolinea(df):
    print("\n  Construyendo dim_aerolinea...")
    dim = df[["Reporting_Airline", "IATA_CODE_Reporting_Airline"]]\
            .drop_duplicates()\
            .reset_index(drop=True)
    dim.columns = ["codigo", "nombre"]
    dim.insert(0, "aerolinea_id", dim.index + 1)
    print(f"   Registros: {len(dim):,}")
    return dim

