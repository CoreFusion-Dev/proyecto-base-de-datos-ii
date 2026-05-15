import os
import requests
import zipfile
from tqdm import tqdm

# ─────────────────────────────────────────
# CONFIGURACIÓN
# ─────────────────────────────────────────
OUTPUT_DIR = "staging/raw"
os.makedirs(OUTPUT_DIR, exist_ok=True)

YEARS = [2021, 2022, 2023, 2024]
MONTHS = list(range(1, 13))

BASE_URL = "https://transtats.bts.gov/PREZIP/On_Time_Reporting_Carrier_On_Time_Performance_1987_present_{year}_{month}.zip"

def is_zip_valid(file_path: str) -> bool:
    """Verifica si el archivo existe y es un ZIP válido."""
    if not os.path.exists(file_path):
        return False
    try:
        with zipfile.ZipFile(file_path, 'r') as zf:
            result = zf.testzip()
            return result is None
    except BaseException:
        return False

def download_file(url: str, dest_path: str):
    try:
        response = requests.get(url, stream=True, timeout=120)
        if response.status_code != 200:
            print(f"  Error {response.status_code}: {url}")
            return False

        total = int(response.headers.get("content-length", 0))
        with open(dest_path, "wb") as f, tqdm(
            desc=os.path.basename(dest_path),
            total=total,
            unit="B",
            unit_scale=True,
        ) as bar:
            for chunk in response.iter_content(chunk_size=8192):
                f.write(chunk)
                bar.update(len(chunk))
        
        if not is_zip_valid(dest_path):
            print(f"  El archivo descargado {os.path.basename(dest_path)} está corrupto.")
            os.remove(dest_path)
            return False
            
        return True
    except Exception as e:
        print(f"  Error durante la descarga: {e}")
        if os.path.exists(dest_path):
            os.remove(dest_path)
        return False

def extract():
    print("=== EXTRACCIÓN: Airline On-Time Performance ===\n")
    descargados = 0
    total_esperado = len(YEARS) * len(MONTHS)

    for year in YEARS:
        for month in MONTHS:
            filename = f"flights_{year}_{month:02d}.zip"
            dest_path = os.path.join(OUTPUT_DIR, filename)

            # Verificación de integridad del archivo
            if is_zip_valid(dest_path):
                print(f" Ya existe y es válido: {filename}")
                descargados += 1
                continue
            elif os.path.exists(dest_path):
                # Cuando el archivo existe pero no es válido, se elimina y se vuelve a descargar
                print(f" Detectado archivo corrupto {filename}. Redescargando...")
                os.remove(dest_path)

            url = BASE_URL.format(year=year, month=month)
            print(f"  → Descargando {filename}...")
            success = download_file(url, dest_path)
            if success:
                descargados += 1
                print(f"  Guardado: {dest_path}")
            else:
                print(f"  Falló: {filename}")

    print(f"\n Extracción completa. Archivos válidos: {descargados}/{total_esperado}")

if __name__ == "__main__":
    extract()