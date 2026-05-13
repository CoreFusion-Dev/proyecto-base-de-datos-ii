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