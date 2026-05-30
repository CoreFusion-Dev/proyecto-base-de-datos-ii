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


-- ──────────────────────────────────────────────────────
-- CONSULTAS DE NEGOCIO
-- Responden las 10 preguntas definidas en docs/technical-decisions.md
-- ──────────────────────────────────────────────────────

-- 1) Aerolíneas con mayor retraso promedio de llegada por trimestre
SELECT
    t.anio,
    t.trimestre,
    a.codigo AS aerolinea,
    ROUND(AVG(f.retraso_llegada)::numeric, 2) AS retraso_promedio_llegada,
    COUNT(*) AS total_vuelos
FROM fact_vuelos f
JOIN dim_tiempo t ON f.tiempo_id = t.tiempo_id
JOIN dim_aerolinea a ON f.aerolinea_id = a.aerolinea_id
GROUP BY t.anio, t.trimestre, a.codigo
ORDER BY t.anio, t.trimestre, retraso_promedio_llegada DESC, total_vuelos DESC;


-- 2) Aeropuertos con mayor cantidad de vuelos cancelados en un año específico
-- Ajusta el año en el filtro si necesitas otro período
SELECT
    t.anio,
    a.codigo AS aeropuerto_origen,
    a.ciudad,
    a.estado,
    COUNT(*) AS vuelos_cancelados
FROM fact_vuelos f
JOIN dim_tiempo t ON f.tiempo_id = t.tiempo_id
JOIN dim_aeropuerto a ON f.aeropuerto_origen_id = a.aeropuerto_id
WHERE f.cancelado = TRUE
  AND t.anio = 2024
GROUP BY t.anio, a.codigo, a.ciudad, a.estado
ORDER BY vuelos_cancelados DESC, a.codigo
LIMIT 20;


-- 3) Meses con mayor proporción de vuelos con retraso superior a 15 minutos
SELECT
    t.mes,
    t.nombre_mes,
    COUNT(*) AS total_vuelos,
    SUM(CASE WHEN f.retraso_llegada > 15 THEN 1 ELSE 0 END) AS vuelos_con_retraso,
    ROUND(
        100.0 * SUM(CASE WHEN f.retraso_llegada > 15 THEN 1 ELSE 0 END) / COUNT(*),
        2
    ) AS porcentaje_vuelos_con_retraso
FROM fact_vuelos f
JOIN dim_tiempo t ON f.tiempo_id = t.tiempo_id
GROUP BY t.mes, t.nombre_mes
ORDER BY porcentaje_vuelos_con_retraso DESC, t.mes;


-- 4) Rutas origen-destino con peor puntualidad de forma recurrente
SELECT
    a_origen.codigo AS aeropuerto_origen,
    a_origen.ciudad AS ciudad_origen,
    a_destino.codigo AS aeropuerto_destino,
    a_destino.ciudad AS ciudad_destino,
    COUNT(*) AS total_vuelos,
    ROUND(AVG(f.retraso_llegada)::numeric, 2) AS retraso_promedio_llegada,
    ROUND(AVG(f.retraso_salida)::numeric, 2) AS retraso_promedio_salida
FROM fact_vuelos f
JOIN dim_aeropuerto a_origen ON f.aeropuerto_origen_id = a_origen.aeropuerto_id
JOIN dim_aeropuerto a_destino ON f.aeropuerto_destino_id = a_destino.aeropuerto_id
GROUP BY a_origen.codigo, a_origen.ciudad, a_destino.codigo, a_destino.ciudad
HAVING COUNT(*) >= 1000
ORDER BY retraso_promedio_llegada DESC, total_vuelos DESC
LIMIT 20;


-- 5) Aerolíneas con mejor desempeño puntual en temporada alta
-- Supuesto: temporada alta = junio, julio y agosto
SELECT
    a.codigo AS aerolinea,
    COUNT(*) AS total_vuelos,
    ROUND(AVG(f.retraso_llegada)::numeric, 2) AS retraso_promedio_llegada,
    ROUND(
        100.0 * SUM(CASE WHEN f.cancelado THEN 1 ELSE 0 END) / COUNT(*),
        2
    ) AS tasa_cancelacion
FROM fact_vuelos f
JOIN dim_tiempo t ON f.tiempo_id = t.tiempo_id
JOIN dim_aerolinea a ON f.aerolinea_id = a.aerolinea_id
WHERE t.mes IN (6, 7, 8)
GROUP BY a.codigo
ORDER BY retraso_promedio_llegada ASC, tasa_cancelacion ASC, total_vuelos DESC;


-- 6) Comparación de tasa de cancelación entre aeropuertos de origen y destino
SELECT
    rol,
    codigo_aeropuerto,
    ciudad,
    estado,
    total_vuelos,
    vuelos_cancelados,
    ROUND(100.0 * vuelos_cancelados / total_vuelos, 2) AS tasa_cancelacion
FROM (
    SELECT
        'Origen' AS rol,
        a.codigo AS codigo_aeropuerto,
        a.ciudad,
        a.estado,
        COUNT(*) AS total_vuelos,
        SUM(CASE WHEN f.cancelado THEN 1 ELSE 0 END) AS vuelos_cancelados
    FROM fact_vuelos f
    JOIN dim_aeropuerto a ON f.aeropuerto_origen_id = a.aeropuerto_id
    GROUP BY a.codigo, a.ciudad, a.estado

    UNION ALL

    SELECT
        'Destino' AS rol,
        a.codigo AS codigo_aeropuerto,
        a.ciudad,
        a.estado,
        COUNT(*) AS total_vuelos,
        SUM(CASE WHEN f.cancelado THEN 1 ELSE 0 END) AS vuelos_cancelados
    FROM fact_vuelos f
    JOIN dim_aeropuerto a ON f.aeropuerto_destino_id = a.aeropuerto_id
    GROUP BY a.codigo, a.ciudad, a.estado
) x
ORDER BY rol, tasa_cancelacion DESC, total_vuelos DESC;


-- 7) Porcentaje de vuelos desviados por trimestre y aerolíneas más asociadas
WITH resumen AS (
    SELECT
        t.anio,
        t.trimestre,
        a.codigo AS aerolinea,
        COUNT(*) AS total_vuelos,
        SUM(CASE WHEN f.desviado THEN 1 ELSE 0 END) AS vuelos_desviados,
        ROUND(
            100.0 * SUM(CASE WHEN f.desviado THEN 1 ELSE 0 END) / COUNT(*),
            2
        ) AS porcentaje_desviados
    FROM fact_vuelos f
    JOIN dim_tiempo t ON f.tiempo_id = t.tiempo_id
    JOIN dim_aerolinea a ON f.aerolinea_id = a.aerolinea_id
    GROUP BY t.anio, t.trimestre, a.codigo
)
SELECT
    anio,
    trimestre,
    aerolinea,
    total_vuelos,
    vuelos_desviados,
    porcentaje_desviados
FROM (
    SELECT
        resumen.*,
        ROW_NUMBER() OVER (
            PARTITION BY anio, trimestre
            ORDER BY porcentaje_desviados DESC, total_vuelos DESC
        ) AS rn
    FROM resumen
) ranked
WHERE rn <= 5
ORDER BY anio, trimestre, porcentaje_desviados DESC, total_vuelos DESC;


-- 8) Días de la semana con peor puntualidad promedio para salidas y llegadas
SELECT
    t.dia_semana,
    t.nombre_dia,
    COUNT(*) AS total_vuelos,
    ROUND(AVG(f.retraso_salida)::numeric, 2) AS retraso_promedio_salida,
    ROUND(AVG(f.retraso_llegada)::numeric, 2) AS retraso_promedio_llegada
FROM fact_vuelos f
JOIN dim_tiempo t ON f.tiempo_id = t.tiempo_id
GROUP BY t.dia_semana, t.nombre_dia
ORDER BY retraso_promedio_llegada DESC, retraso_promedio_salida DESC;


-- 9) Aeropuertos con mayor tiempo promedio de vuelo y posible correlación con retrasos
SELECT
    a.codigo AS aeropuerto_origen,
    a.ciudad,
    a.estado,
    COUNT(*) AS total_vuelos,
    ROUND(AVG(f.tiempo_vuelo)::numeric, 2) AS tiempo_promedio_vuelo,
    ROUND(AVG(f.retraso_llegada)::numeric, 2) AS retraso_promedio_llegada,
    ROUND(corr(f.tiempo_vuelo, f.retraso_llegada)::numeric, 3) AS correlacion_tiempo_retraso
FROM fact_vuelos f
JOIN dim_aeropuerto a ON f.aeropuerto_origen_id = a.aeropuerto_id
GROUP BY a.codigo, a.ciudad, a.estado
HAVING COUNT(*) >= 1000
ORDER BY tiempo_promedio_vuelo DESC, retraso_promedio_llegada DESC
LIMIT 20;


-- 10) Combinación de aerolínea, aeropuerto y trimestre con mejor equilibrio entre volumen y puntualidad
WITH resumen AS (
    SELECT
        t.anio,
        t.trimestre,
        a.codigo AS aerolinea,
        ao.codigo AS aeropuerto_origen,
        COUNT(*) AS total_vuelos,
        ROUND(AVG(f.retraso_llegada)::numeric, 2) AS retraso_promedio_llegada,
        ROUND(
            100.0 * SUM(CASE WHEN f.cancelado THEN 1 ELSE 0 END) / COUNT(*),
            2
        ) AS tasa_cancelacion
    FROM fact_vuelos f
    JOIN dim_tiempo t ON f.tiempo_id = t.tiempo_id
    JOIN dim_aerolinea a ON f.aerolinea_id = a.aerolinea_id
    JOIN dim_aeropuerto ao ON f.aeropuerto_origen_id = ao.aeropuerto_id
    GROUP BY t.anio, t.trimestre, a.codigo, ao.codigo
    HAVING COUNT(*) >= 500
)
SELECT
    anio,
    trimestre,
    aerolinea,
    aeropuerto_origen,
    total_vuelos,
    retraso_promedio_llegada,
    tasa_cancelacion,
    ROUND(
        total_vuelos::numeric / (1 + retraso_promedio_llegada + tasa_cancelacion),
        2
    ) AS score_equilibrio
FROM resumen
ORDER BY score_equilibrio DESC, total_vuelos DESC
LIMIT 20;
