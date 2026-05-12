-- ══════════════════════════════════════════════════════
-- CONSULTAS EXPLAIN ANALYZE
-- Proyecto Final Base de Datos II
-- Dataset: Airline On-Time Performance (BTS) 2021-2024
-- ══════════════════════════════════════════════════════


-- ──────────────────────────────────────────────────────
-- CONSULTA 1: Partition Pruning
-- Demuestra que solo se escanea la partición Q1 2022
-- Buscar en resultado: solo fact_vuelos_2022_q1 escaneada
-- ──────────────────────────────────────────────────────

EXPLAIN ANALYZE
SELECT COUNT(*)
FROM fact_vuelos
WHERE fecha_vuelo BETWEEN '2022-01-01' AND '2022-03-31';


-- ──────────────────────────────────────────────────────
-- CONSULTA 2: Retraso promedio por aerolínea
-- Motiva el índice idx_fact_aerolinea
-- ──────────────────────────────────────────────────────

-- PASO 1: Eliminar índice para medir SIN índice
DROP INDEX IF EXISTS idx_fact_aerolinea;

-- PASO 2: Medir SIN índice
EXPLAIN ANALYZE
SELECT aerolinea_id, AVG(retraso_llegada) AS promedio_retraso
FROM fact_vuelos
GROUP BY aerolinea_id
ORDER BY promedio_retraso DESC;

-- PASO 3: Recrear índice
CREATE INDEX idx_fact_aerolinea ON fact_vuelos (aerolinea_id);

-- PASO 4: Medir CON índice
EXPLAIN ANALYZE
SELECT aerolinea_id, AVG(retraso_llegada) AS promedio_retraso
FROM fact_vuelos
GROUP BY aerolinea_id
ORDER BY promedio_retraso DESC;


-- ──────────────────────────────────────────────────────
-- CONSULTA 3: Vuelos por aerolínea en un trimestre
-- Motiva el índice compuesto idx_fact_aerolinea_fecha
-- ──────────────────────────────────────────────────────

-- PASO 1: Eliminar índice compuesto
DROP INDEX IF EXISTS idx_fact_aerolinea_fecha;

-- PASO 2: Medir SIN índice compuesto
EXPLAIN ANALYZE
SELECT aerolinea_id, COUNT(*) AS total_vuelos
FROM fact_vuelos
WHERE fecha_vuelo BETWEEN '2022-06-01' AND '2022-09-30'
GROUP BY aerolinea_id
ORDER BY total_vuelos DESC;

-- PASO 3: Recrear índice compuesto
CREATE INDEX idx_fact_aerolinea_fecha
    ON fact_vuelos (aerolinea_id, fecha_vuelo);

-- PASO 4: Medir CON índice compuesto
EXPLAIN ANALYZE
SELECT aerolinea_id, COUNT(*) AS total_vuelos
FROM fact_vuelos
WHERE fecha_vuelo BETWEEN '2022-06-01' AND '2022-09-30'
GROUP BY aerolinea_id
ORDER BY total_vuelos DESC;


-- ──────────────────────────────────────────────────────
-- CONSULTA 4: Vuelos cancelados por aeropuerto
-- Consulta analítica del dashboard
-- Demuestra uso combinado de filtro + agrupación
-- ──────────────────────────────────────────────────────

EXPLAIN ANALYZE
SELECT
    aeropuerto_origen_id,
    COUNT(*) AS total_cancelados
FROM fact_vuelos
WHERE cancelado = TRUE
  AND fecha_vuelo BETWEEN '2022-01-01' AND '2022-12-31'
GROUP BY aeropuerto_origen_id
ORDER BY total_cancelados DESC
LIMIT 20;


-- ──────────────────────────────────────────────────────
-- CONSULTA 5: Distribución de registros por partición
-- Demuestra que el particionamiento distribuyó bien los datos
-- ──────────────────────────────────────────────────────

SELECT
    tableoid::regclass AS particion,
    COUNT(*)           AS registros
FROM fact_vuelos
GROUP BY tableoid
ORDER BY particion;
