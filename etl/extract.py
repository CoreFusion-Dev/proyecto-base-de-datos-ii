import os
import time
import random
import requests
import zipfile
from tqdm import tqdm

# ─────────────────────────────────────────
# CONFIGURACIÓN
# ─────────────────────────────────────────
OUTPUT_DIR = "staging/raw"
os.makedirs(OUTPUT_DIR, exist_ok=True)

YEARS  = [2021, 2022, 2023]
MONTHS = list(range(1, 13))

BASE_URL = (
    "https://transtats.bts.gov/PREZIP/"
    "On_Time_Reporting_Carrier_On_Time_Performance_1987_present_{year}_{month}.zip"
)

# Simular un navegador real para evitar bloqueos del servidor
HEADERS = {
    "User-Agent": (
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
        "AppleWebKit/537.36 (KHTML, like Gecko) "
        "Chrome/124.0.0.0 Safari/537.36"
    ),
    "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
    "Accept-Language": "en-US,en;q=0.5",
    "Connection": "keep-alive",
}

MAX_REINTENTOS = 3
PAUSA_MIN = 3   # segundos mínimo entre descargas
PAUSA_MAX = 3   # segundos máximo entre descargas


# ─────────────────────────────────────────
# VALIDAR ZIP
# ─────────────────────────────────────────
def is_zip_valid(file_path: str) -> bool:
    if not os.path.exists(file_path):
        return False
    try:
        with zipfile.ZipFile(file_path, 'r') as zf:
            return zf.testzip() is None
    except BaseException:
        return False


# ─────────────────────────────────────────
# DESCARGAR CON REINTENTOS
# ─────────────────────────────────────────
def download_file(url: str, dest_path: str) -> bool:
    for intento in range(1, MAX_REINTENTOS + 1):
        try:
            if intento > 1:
                espera = random.uniform(10, 20)
                print(f"  Reintento {intento}/{MAX_REINTENTOS} en {espera:.0f}s...")
                time.sleep(espera)

            response = requests.get(
                url, stream=True, timeout=180, headers=HEADERS
            )

            if response.status_code != 200:
                print(f"   Error HTTP {response.status_code}")
                continue

            total = int(response.headers.get("content-length", 0))
            with open(dest_path, "wb") as f, tqdm(
                desc=os.path.basename(dest_path),
                total=total,
                unit="B",
                unit_scale=True,
            ) as bar:
                for chunk in response.iter_content(chunk_size=16384):
                    f.write(chunk)
                    bar.update(len(chunk))

            if is_zip_valid(dest_path):
                return True
            else:
                print(f"  ZIP inválido, reintentando...")
                if os.path.exists(dest_path):
                    os.remove(dest_path)

        except Exception as e:
            print(f" Error: {e}")
            if os.path.exists(dest_path):
                os.remove(dest_path)

    return False


# ─────────────────────────────────────────
# EXTRACCIÓN PRINCIPAL
# ─────────────────────────────────────────
def extract():
    print("=== EXTRACCIÓN: Airline On-Time Performance ===\n")
    descargados = 0
    fallidos    = []
    total_esperado = len(YEARS) * len(MONTHS)

    for year in YEARS:
        for month in MONTHS:
            filename  = f"flights_{year}_{month:02d}.zip"
            dest_path = os.path.join(OUTPUT_DIR, filename)

            # Ya existe y es válido
            if is_zip_valid(dest_path):
                print(f"   Archivo ya existe: {filename}")
                descargados += 1
                continue

            # Existe pero está corrupto
            if os.path.exists(dest_path):
                print(f"   Archivo corrupto, eliminando: {filename}")
                os.remove(dest_path)

            url = BASE_URL.format(year=year, month=month)
            print(f"  Descargando {filename}...")

            success = download_file(url, dest_path)

            if success:
                descargados += 1
                print(f" Guardado: {filename}")
            else:
                fallidos.append(filename)
                print(f" Falló: {filename}")

            # Pausa aleatoria entre descargas para no saturar el servidor
            pausa = random.uniform(PAUSA_MIN, PAUSA_MAX)
            time.sleep(pausa)

    print(f"\n══════════════════════════════════════")
    print(f" Archivos válidos:  {descargados}/{total_esperado}")
    if fallidos:
        print(f" Archivos fallidos: {len(fallidos)}")
        for f in fallidos:
            print(f"   - {f}")
    print(f"══════════════════════════════════════")


if __name__ == "__main__":
    extract()