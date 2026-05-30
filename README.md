# Proyecto Final - Base de Datos II
**ETL Pipeline: Airline On-Time Performance Data Warehouse**

Pipeline ETL completo para construir un Data Warehouse con datos de desempeño puntual de aerolíneas (2021-2024) desde la API del Bureau of Transportation Statistics (BTS).

**Volumen de datos:**
- **26.5 millones de registros** de vuelos
- **4 años** de historial (2021-2024)
- **16 particiones trimestrales** para query optimization
- **3 índices** para accelerar consultas analíticas

---

## 📋 Requisitos Previos

Antes de comenzar, asegúrate de tener instalado:

- **Python 3.8+** ([Descargar](https://www.python.org/downloads/))
  - Verificar: `python --version`
- **PostgreSQL 12+** ([Descargar](https://www.postgresql.org/download/))
  - Verificar: `psql --version`
- **Git** ([Descargar](https://git-scm.com/))

## 🚀 Instalación

### Paso 1: Clonar o descargar el repositorio

```bash
git clone https://github.com/KevinCax/proyecto-bdii.git
cd proyecto-bdii
```

### Paso 2: Crear un entorno virtual

```bash
# En Windows
python -m venv venv
venv\Scripts\activate

# En macOS/Linux
python3 -m venv venv
source venv/bin/activate
```

### Paso 3: Instalar dependencias

```bash
pip install -r requirements.txt
```

### Paso 4: Configurar la base de datos PostgreSQL

1. **Crear una nueva base de datos:**

```bash
psql -U postgres
```

Dentro de psql:
```sql
CREATE DATABASE flights_dw;
\q
```

2. **Crear archivo `.env` en la raíz del proyecto:**

Copia el siguiente contenido en un archivo llamado `.env`:

```env
# Configuración de PostgreSQL
DB_HOST=localhost
DB_PORT=5432
DB_NAME=flights_dw
DB_USER=postgres
DB_PASSWORD=<tu-contraseña-postgres>
```

**Reemplaza `<tu-contraseña-postgres>` con la contraseña de tu usuario PostgreSQL.**

> ⚠️ **Importante:** El archivo `.env` está incluido en `.gitignore` para evitar exponer credenciales.

### Paso 5: Validar la conexión a la BD

```bash
python -c "from etl.load import get_connection; conn = get_connection(); print('✅ Conexión exitosa'); conn.close()"
```

Si ves `✅ Conexión exitosa`, estás listo para continuar.

---

## 📊 Estructura del Proyecto

```
proyecto-bdii/
├── etl/
│   ├── extract.py       # Descarga datos de BTS API (2021-2024)
│   ├── transform.py     # Limpia y transforma datos
│   └── load.py          # Carga en PostgreSQL (DDL + Inserción)
├── sql/
│   ├── ddl_schema.sql   # Esquema: Dimensiones + Tabla de Hechos
│   └── queries_analyze.sql # Queries de análisis
├── staging/
│   ├── raw/             # Archivos ZIP descargados
│   └── processed/       # CSVs transformados
├── explorar.py          # Script para explorar datos antes de cargar
├── requirements.txt     # Dependencias Python
├── .env                 # Configuración local (no versionado)
└── README.md            # Este archivo
```

---

## ▶️ Cómo Ejecutar el Pipeline

### Opción A: Ejecutar el pipeline completo (recomendado)

```bash
# 1. Extraer datos (descarga archivos ZIP)
python etl/extract.py

# 2. Transformar datos (procesa y limpia)
python etl/transform.py

# 3. Cargar en PostgreSQL (crea esquema + inserta datos)
python etl/load.py
```

**Tiempo estimado:** 15-30 minutos (depende de conexión a internet)

### Opción B: Ejecutar paso a paso

```bash
# Solo extraer
python etl/extract.py

# Solo transformar
python etl/transform.py

# Solo cargar
python etl/load.py
```

### Explorar datos antes de cargar

Para inspeccionar el contenido de los archivos descargados sin cargar nada:

```bash
python explorar.py
```

---

## 📈 Análisis y Consultas

### Archivo: `queries_analyze.sql`

Este archivo contiene **5 consultas de rendimiento** que demuestran cómo PostgreSQL optimiza las operaciones del Data Warehouse. Cada consulta usa `EXPLAIN ANALYZE` para medir tiempo de ejecución real.

#### 📋 Consultas incluidas:

1. **Partition Pruning** — Demuestra que solo escanea la partición necesaria
   - Ejecuta: `WHERE fecha_vuelo BETWEEN '2022-01-01' AND '2022-03-31'`
   - Resultado esperado: Solo `fact_vuelos_2022_q1` es escaneada (96% menos filas)

2. **Índice simple** — Compara rendimiento CON y SIN índice `idx_fact_aerolinea`
   - DROP → Medir SIN índice → CREATE → Medir CON índice
   - Propósito: Agregar retrasos promedio por aerolínea

3. **Índice compuesto** — Compara rendimiento CON y SIN índice `idx_fact_aerolinea_fecha`
   - DROP → Medir → CREATE → Medir
   - Propósito: Vuelos por aerolínea en un trimestre específico
   - Mejora esperada: ~41% más rápido con índice compuesto

4. **Consulta analítica** — Vuelos cancelados por aeropuerto en 2022
   - Demuestra consulta real del dashboard
   - Incluye filtros + agrupación + ORDER BY

5. **Distribución de particiones** — Cuenta registros por partición
   - Valida que los 26.5M registros se distribuyeron correctamente

#### ▶️ Cómo ejecutar:

**Opción 1: Ejecutar todo el archivo**
```bash
psql -U postgres -d flights_dw -f sql/queries_analyze.sql
```

**Opción 2: Ejecutar interactivamente desde psql**
```bash
psql -U postgres -d flights_dw
flights_dw=# \i sql/queries_analyze.sql
```

**Opción 3: Ver el contenido antes de ejecutar**
```bash
cat sql/queries_analyze.sql
```

#### 📊 Interpretar los resultados:

Busca líneas como estas en la salida:
```
Execution Time: 298.995 ms
Parallel Index Only Scan using fact_vuelos_2022_q1_fecha_vuelo_idx
Rows: 527536 (vs 26.5M sin partition pruning)
```

**Lo que significa:**
- **Execution Time**: Tiempo real de ejecución en tu máquina
- **Index Only Scan**: PostgreSQL resolvió la consulta leyendo solo el índice (más rápido)
- **Parallel**: Se usó paralelismo (consulta se dividió entre múltiples núcleos)
- **Rows**: Registros que PostgreSQL tuvo que examinar

#### ⚠️ Importante:

> Las consultas 2 y 3 **DROPEAN y RECREAN índices**. Ejecutarlas en producción puede causar bloqueos.
> Para uso en desarrollo: ejecuta completo. Para validación puntual: comenta los DROP y copia solo la consulta que necesites.

---

## 🔍 Troubleshooting

### Error: "FATAL: password authentication failed for user 'postgres'"

**Causa:** Contraseña incorrecta o usuario inexistente.

**Solución:**
1. Verifica tu `.env` tiene la contraseña correcta
2. Prueba conectar manualmente: `psql -U postgres -W `
3. Si olvidaste la contraseña, resetéala en PostgreSQL

### Error: "Database flights_dw does not exist"

**Causa:** Base de datos no creada.

**Solución:**
```bash
psql -U postgres -c "CREATE DATABASE flights_dw;"
```

### Error: "ModuleNotFoundError: No module named 'psycopg2'"

**Causa:** Dependencias no instaladas.

**Solución:**
```bash
pip install -r requirements.txt
```

### Error: "No such file or directory: 'staging/raw/...'"

**Causa:** El script `extract.py` no se ejecutó o falló.

**Solución:**
```bash
python etl/extract.py
```

### El script de extract es muy lento

**Causa:** Descargas desde BTS API pueden tardar.

**Solución:** Es normal. Descarga ~200-300 MB. Si se detiene, ejecuta de nuevo (retoma desde donde paró).

### Error de conexión a la BD durante el load

**Verificación rápida:**
```bash
# ¿Está PostgreSQL ejecutándose?
pg_isready -h localhost -p 5432

# ¿Existe la base de datos?
psql -U postgres -l | grep flights_dw

# ¿Las variables de .env son correctas?
cat .env
```

---

## 📦 Dependencias

Las dependencias están documentadas en `requirements.txt`:

- **pandas**: Procesamiento de datos
- **psycopg2**: Conector PostgreSQL
- **requests**: Descargas HTTP
- **tqdm**: Barra de progreso
- **python-dotenv**: Gestión de variables de entorno

---

## 🎯 Validación de Reproducibilidad

Pasos para verificar que el proyecto es completamente reproducible en una máquina limpia:

```bash
# 1. Clonar
git clone https://github.com/KevinCax/proyecto-bdii.git
cd proyecto-bdii

# 2. Crear entorno
python -m venv venv
source venv/bin/activate  # o venv\Scripts\activate en Windows

# 3. Instalar dependencias
pip install -r requirements.txt

# 4. Configurar .env (ver Paso 4 arriba)
# Crear .env con credenciales correctas

# 5. Crear BD
psql -U postgres -c "CREATE DATABASE flights_dw;"

# 6. Ejecutar pipeline
python etl/extract.py
python etl/transform.py
python etl/load.py

# ✅ Si todo ejecuta sin errores, el proyecto es reproducible
```

---

## 📝 Notas

- **Primera ejecución:** El `extract.py` descarga ~200-300 MB de datos. Es normal que tarde 10-20 minutos.
- **Reutilizar datos:** Si ya descargaste, puedes comentar el `extract.py` y saltar al `transform.py`.
- **Base de datos limpia:** Ejecutar `load.py` crea las tablas automáticamente (con DROP IF EXISTS).

---

## ✅ Autores
Kevin Denilson Cax Coc

Rafael Estuardo Galindo Ramirez

René Alexander Machic Morales

Rudy Neftali Estrada Catalán


## Copyright © Todos los derechos reservados
