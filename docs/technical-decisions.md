# Decisiones Técnicas — flights_dw
## Proyecto Final Base de Datos II — Airline On-Time Performance (BTS) 2022-2023

---

## 1. Elección del esquema dimensional

### Decisión: Esquema Estrella

Se eligió el **esquema estrella** sobre el esquema snowflake por las siguientes razones:

- **Simplicidad de consultas:** En un esquema estrella las dimensiones no están normalizadas,
  lo que permite joins directos entre la tabla de hechos y las dimensiones sin joins encadenados.
- **Rendimiento OLAP:** Las consultas analíticas del dashboard requieren aggregaciones sobre
  millones de registros. El esquema estrella minimiza el número de joins necesarios.
- **Alternativa descartada:** El esquema snowflake hubiera normalizado `dim_aeropuerto` separando
  ciudad, estado y país en tablas independientes. Se descartó porque añade complejidad de joins
  sin beneficio real dado que los atributos geográficos no se consultan de forma independiente.

### Tablas del modelo:
- `fact_vuelos` — tabla de hechos con 13,518,244 registros
- `dim_tiempo` — 730 registros (granularidad diaria, 2 años)
- `dim_aerolinea` — 17 registros (aerolíneas únicas)
- `dim_aeropuerto` — 373 registros (aeropuertos origen y destino, role-playing dimension)
- `dim_estado_vuelo` — 4 registros (ON_TIME, DELAYED, CANCELLED, DIVERTED)

**Nota sobre role-playing dimension:** `dim_aeropuerto` se usa dos veces en `fact_vuelos`
(como `aeropuerto_origen_id` y `aeropuerto_destino_id`). Esto es un patrón estándar del
modelado dimensional llamado role-playing dimension.

---

## 2. Estrategia de particionamiento

### Decisión: Particionamiento trimestral por `fecha_vuelo`

Se particionó la tabla de hechos por rango trimestral sobre `fecha_vuelo`, generando
8 particiones (4 por año × 2 años):
```
fact_vuelos_2022_q1: 2022-01-01 → 2022-04-01
fact_vuelos_2022_q2: 2022-04-01 → 2022-07-01
fact_vuelos_2022_q3: 2022-07-01 → 2022-10-01
fact_vuelos_2022_q4: 2022-10-01 → 2023-01-01
fact_vuelos_2023_q1: 2023-01-01 → 2023-04-01
fact_vuelos_2023_q2: 2023-04-01 → 2023-07-01
fact_vuelos_2023_q3: 2023-07-01 → 2023-10-01
fact_vuelos_2023_q4: 2023-10-01 → 2024-01-01
```

**Justificación:** La granularidad trimestral es adecuada para este volumen (~1.7M registros
por partición en promedio). Una granularidad mensual hubiera generado 24 particiones con
~565K registros cada una — funcional pero con mayor overhead de gestión. La granularidad
anual hubiera generado solo 2 particiones con ~6.7M registros cada una, reduciendo
la efectividad del pruning.

---

## 3. Evidencia de Partition Pruning

### Consulta ejecutada:
```sql
EXPLAIN ANALYZE
SELECT COUNT(*)
FROM fact_vuelos
WHERE fecha_vuelo BETWEEN '2022-01-01' AND '2022-03-31';
```

### Resultado del EXPLAIN ANALYZE:
```
Parallel Index Only Scan using fact_vuelos_2022_q1_fecha_vuelo_idx
  on fact_vuelos_2022_q1
  (cost=0.43..27603.35 rows=659420 width=0)
  (actual time=5.676..245.816 rows=527536 loops=3)
Index Cond: ((fecha_vuelo >= '2022-01-01') AND (fecha_vuelo <= '2022-03-31'))
Execution Time: 298.995 ms
```

**Evidencia:** PostgreSQL escaneó únicamente `fact_vuelos_2022_q1` e ignoró
las 7 particiones restantes. El optimizador aplicó partition pruning correctamente
al detectar que el filtro de fecha solo abarca el primer trimestre de 2022.

---

## 4. Índices y su justificación

### Índice 1: `idx_fact_fecha` — simple sobre `fecha_vuelo`
**Consulta que lo motiva:**
```sql
SELECT COUNT(*) FROM fact_vuelos
WHERE fecha_vuelo BETWEEN '2022-01-01' AND '2022-03-31';
```
**Justificación:** Filtros temporales son los más frecuentes en el dashboard.
Este índice trabaja en conjunto con el particionamiento para acelerar el pruning.

---

### Índice 2: `idx_fact_aerolinea` — simple sobre `aerolinea_id`
**Consulta que lo motiva:**
```sql
SELECT aerolinea_id, AVG(retraso_llegada)
FROM fact_vuelos GROUP BY aerolinea_id;
```
**Resultado:**
```
SIN índice: Execution Time: 1987.684 ms
CON índice: Execution Time: 2021.147 ms
```
**Análisis:** Para aggregaciones sobre toda la tabla, el optimizador prefiere
Sequential Scan sobre Index Scan porque debe leer todos los registros de todas
formas. El índice es más útil en consultas con filtros específicos de aerolínea
combinados con otros criterios.

---