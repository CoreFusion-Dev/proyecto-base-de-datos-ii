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
- `fact_vuelos` — tabla de hechos con 26,548,545 registros (2021-2024)
- `dim_tiempo` — 1,461 registros (granularidad diaria, 4 años)
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
16 particiones (4 trimestres × 4 años):
```
2021: fact_vuelos_2021_q1, fact_vuelos_2021_q2, fact_vuelos_2021_q3, fact_vuelos_2021_q4
2022: fact_vuelos_2022_q1, fact_vuelos_2022_q2, fact_vuelos_2022_q3, fact_vuelos_2022_q4
2023: fact_vuelos_2023_q1, fact_vuelos_2023_q2, fact_vuelos_2023_q3, fact_vuelos_2023_q4
2024: fact_vuelos_2024_q1, fact_vuelos_2024_q2, fact_vuelos_2024_q3, fact_vuelos_2024_q4
```

**Justificación:** La granularidad trimestral es adecuada para este volumen (~1.66M registros
por partición en promedio). Una granularidad mensual hubiera generado 48 particiones con
~553K registros cada una — funcional pero con mayor overhead de gestión. La granularidad
anual hubiera generado solo 4 particiones con ~6.6M registros cada una, reduciendo
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

### Índice 3: `idx_fact_aerolinea_fecha` — compuesto sobre `(aerolinea_id, fecha_vuelo)`
**Consulta que lo motiva:**
```sql
SELECT aerolinea_id, COUNT(*) FROM fact_vuelos
WHERE fecha_vuelo BETWEEN '2022-06-01' AND '2022-09-30'
GROUP BY aerolinea_id ORDER BY COUNT(*) DESC;
```
**Resultado:**
```
SIN índice: Execution Time: 377.355 ms  (Parallel Seq Scan)
CON índice: Execution Time: 221.188 ms  (Parallel Index Only Scan)
```
**Mejora cuantitativa: 41.4% de reducción en tiempo de ejecución.**

El índice compuesto permite un Index Only Scan — PostgreSQL resuelve la consulta
leyendo solo el índice sin acceder a la tabla principal (Heap Fetches: 0).

---

## 5. Diferenciación OLTP vs OLAP

### Sistema fuente (OLTP)
El Bureau of Transportation Statistics (BTS) recopila datos de vuelos desde los
sistemas operacionales de cada aerolínea. Estos sistemas fuente operan bajo el
paradigma **OLTP (Online Transaction Processing)**:
- Registran cada vuelo individualmente en tiempo real
- Están optimizados para operaciones de INSERT/UPDATE frecuentes
- Tienen esquemas normalizados para evitar anomalías de actualización
- Procesan miles de transacciones concurrentes por segundo

### Data Warehouse construido (OLAP)
El sistema construido en este proyecto es un componente **OLAP (Online Analytical Processing)**:
- Almacena datos históricos de 4 años (26.5M registros) sin modificaciones
- Está optimizado para consultas analíticas con aggregaciones sobre millones de filas
- Usa esquema dimensional (estrella) que desnormaliza deliberadamente para mejorar el rendimiento de lectura
- El particionamiento y los índices están diseñados para acelerar SELECT, no INSERT

**La distinción clave:** No existe carga transaccional real en este proyecto.
Los datos se cargan en lotes mediante el pipeline ETL (proceso batch), no registro
por registro como en un sistema OLTP. El ETL actúa como puente entre el mundo
OLTP (fuente) y el mundo OLAP (Data Warehouse).

---

## 6. Mejoras cuantitativas obtenidas

| Optimización | Antes | Después | Mejora |
|---|---|---|---|
| Partition Pruning (Q1 2022) | Scan 26.5M filas | Scan 527K filas | 98% menos filas |
| Índice compuesto + fecha | 377 ms | 221 ms | 41% más rápido |
| Tipo de scan con índice compuesto | Seq Scan | Index Only Scan | Sin acceso a heap |

---

## 7. Estrategia de validación con EXPLAIN ANALYZE

### Propósito

El archivo `sql/queries_analyze.sql` contiene una suite de pruebas de rendimiento que valida:
1. Que el particionamiento funciona correctamente (partition pruning)
2. Que cada índice mejora realmente el rendimiento
3. Que las consultas analíticas típicas se ejecutan eficientemente
4. Que los datos se distribuyeron correctamente entre particiones

### Diseño de las 5 consultas

#### Consulta 1: Partition Pruning
```sql
SELECT COUNT(*) FROM fact_vuelos
WHERE fecha_vuelo BETWEEN '2022-01-01' AND '2022-03-31';
```
**Valida:** Que el optimizador aplica partition pruning correctamente.
- Sin pruning: escanearía 26.5M registros
- Con pruning: escanea ~1.6M registros (1 partición de 16)
- Evidencia esperada en EXPLAIN ANALYZE: `fact_vuelos_2022_q1` es la única tabla mencionada

#### Consulta 2: Impacto de índice simple
Compara 4 pasos:
1. `DROP INDEX idx_fact_aerolinea` — Eliminar el índice
2. `EXPLAIN ANALYZE SELECT ... GROUP BY aerolinea_id` — Medir SIN índice
3. `CREATE INDEX idx_fact_aerolinea ON fact_vuelos (aerolinea_id)` — Recrear
4. `EXPLAIN ANALYZE SELECT ... GROUP BY aerolinea_id` — Medir CON índice

**Valida:** Que el índice es útil para agregaciones por aerolínea.
**Nota:** En agregaciones sin filtro, el optimizador puede preferir Sequential Scan 
porque debe leer todos los registros de todas formas.

#### Consulta 3: Impacto de índice compuesto
Similar a consulta 2, pero con índice compuesto `(aerolinea_id, fecha_vuelo)`.

**Valida:** Que el índice compuesto permite Index Only Scan (sin acceso a tabla principal).
**Mejora esperada:** ~41% más rápido gracias a Index Only Scan.

#### Consulta 4: Consulta analítica realista
```sql
SELECT aeropuerto_origen_id, COUNT(*) 
FROM fact_vuelos
WHERE cancelado = TRUE AND fecha_vuelo BETWEEN '2022-01-01' AND '2022-12-31'
GROUP BY aeropuerto_origen_id
ORDER BY COUNT(*) DESC LIMIT 20;
```
**Valida:** Que las consultas del dashboard (con filtros + agrupación) son rápidas.

#### Consulta 5: Distribución de datos
```sql
SELECT tableoid::regclass, COUNT(*) FROM fact_vuelos GROUP BY tableoid;
```
**Valida:** Que los 26.5M registros se distribuyeron equitativamente entre 16 particiones.
**Resultado esperado:**
- Cada partición debería tener ~1.66M registros
- Si alguna partición está vacía o tiene datos muy desbalanceados, indica un problema en ETL

### Cuándo ejecutar

1. **Después de `etl/load.py` completa** — Para validar que el pipeline funcionó
2. **Después de cambios al schema** — Para medir impacto de nuevos índices
3. **Durante desarrollo** — Para entender cómo el optimizador ejecuta tus consultas
4. **Documentación** — Como evidencia en reports o presentaciones

### Interpretación de resultados

```
EXPLAIN ANALYZE
  Parallel Index Only Scan using idx_fact_aerolinea_fecha
  (cost=0.43..27603.35 rows=659420 width=0)
  (actual time=5.676..245.816 rows=527536 loops=3)
Execution Time: 298.995 ms
```

**Campos clave:**
- **cost=0.43..27603.35**: Estimación de costo del optimizador (no se usa para ejecutar, solo para elegir plan)
- **rows=659420 (estimated) vs actual rows=527536**: Precisión del estimador
- **actual time**: Tiempo real medido
- **loops=3**: Se ejecutó 3 veces en paralelo
- **Execution Time**: Tiempo total incluido overhead

**Banderas de éxito:**
- ✅ Index Only Scan (no Seq Scan)
- ✅ Execution Time cae cuando creas índices
- ✅ Partition pruning escanea pocas particiones
- ✅ Filas estimadas ≈ filas actuales (estimador bien calibrado)