-- ══════════════════════════════════════════════════════
-- DDL SCHEMA - flights_dw OLAP UMG
-- Proyecto Final Base de Datos II
-- Dataset: Airline On-Time Performance (BTS) 2021-2024
-- PostgreSQL 16.4
-- ══════════════════════════════════════════════════════


-- ══════════════════════════════════════════════════════
-- DIMENSIONES
-- ══════════════════════════════════════════════════════

-- Dimensión de Tiempo
CREATE TABLE IF NOT EXISTS dim_tiempo (
    tiempo_id     INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    fecha         DATE NOT NULL,
    dia           INTEGER NOT NULL,
    mes           INTEGER NOT NULL,
    trimestre     INTEGER NOT NULL,
    anio          INTEGER NOT NULL,
    dia_semana    INTEGER NOT NULL,
    nombre_mes    VARCHAR(20) NOT NULL,
    nombre_dia    VARCHAR(20) NOT NULL,
    es_fin_semana BOOLEAN NOT NULL,
    CONSTRAINT uq_dim_tiempo_fecha UNIQUE (fecha)
);

-- Dimensión de Aerolínea
CREATE TABLE IF NOT EXISTS dim_aerolinea (
    aerolinea_id  INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    codigo        VARCHAR(10) NOT NULL,
    nombre        VARCHAR(100) NOT NULL,
    CONSTRAINT uq_dim_aerolinea_codigo UNIQUE (codigo)
);

-- Dimensión de Aeropuerto (Desnormalizada)
CREATE TABLE IF NOT EXISTS dim_aeropuerto (
    aeropuerto_id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    codigo        VARCHAR(10) NOT NULL,
    ciudad        VARCHAR(100),
    estado        VARCHAR(10),
    nombre_estado VARCHAR(100),
    pais          VARCHAR(50) DEFAULT 'USA',
    CONSTRAINT uq_dim_aeropuerto_codigo UNIQUE (codigo)
);

-- Dimensión de Estado de Vuelo
CREATE TABLE IF NOT EXISTS dim_estado_vuelo (
    estado_id     INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    codigo        VARCHAR(20) NOT NULL,
    descripcion   VARCHAR(100) NOT NULL,
    CONSTRAINT uq_dim_estado_codigo UNIQUE (codigo)
);

-- ══════════════════════════════════════════════════════
-- TABLA DE HECHOS (Particionada)
-- ══════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS fact_vuelos (
    vuelo_id              BIGINT GENERATED ALWAYS AS IDENTITY,
    tiempo_id             INTEGER NOT NULL,
    aerolinea_id          INTEGER NOT NULL,
    aeropuerto_origen_id  INTEGER NOT NULL,
    aeropuerto_destino_id INTEGER NOT NULL,
    estado_id             INTEGER NOT NULL,
    fecha_vuelo           DATE NOT NULL,
    retraso_salida        NUMERIC(8,2),
    retraso_llegada       NUMERIC(8,2),
    tiempo_vuelo          NUMERIC(8,2),
    distancia             NUMERIC(10,2),
    cancelado             BOOLEAN DEFAULT FALSE,
    desviado              BOOLEAN DEFAULT FALSE,
    retraso_aerolinea     NUMERIC(8,2),
    retraso_clima         NUMERIC(8,2),
    retraso_nas           NUMERIC(8,2),
    retraso_seguridad     NUMERIC(8,2),
    retraso_aeronave      NUMERIC(8,2),
    CONSTRAINT pk_fact_vuelos PRIMARY KEY (vuelo_id, fecha_vuelo)
) PARTITION BY RANGE (fecha_vuelo);


-- ══════════════════════════════════════════════════════
-- PARTICIONES 2021
-- ══════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS fact_vuelos_2021_q1
    PARTITION OF fact_vuelos
    FOR VALUES FROM ('2021-01-01') TO ('2021-04-01');

CREATE TABLE IF NOT EXISTS fact_vuelos_2021_q2
    PARTITION OF fact_vuelos
    FOR VALUES FROM ('2021-04-01') TO ('2021-07-01');

CREATE TABLE IF NOT EXISTS fact_vuelos_2021_q3
    PARTITION OF fact_vuelos
    FOR VALUES FROM ('2021-07-01') TO ('2021-10-01');

CREATE TABLE IF NOT EXISTS fact_vuelos_2021_q4
    PARTITION OF fact_vuelos
    FOR VALUES FROM ('2021-10-01') TO ('2022-01-01');


-- ══════════════════════════════════════════════════════
-- PARTICIONES 2022
-- ══════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS fact_vuelos_2022_q1
    PARTITION OF fact_vuelos
    FOR VALUES FROM ('2022-01-01') TO ('2022-04-01');

CREATE TABLE IF NOT EXISTS fact_vuelos_2022_q2
    PARTITION OF fact_vuelos
    FOR VALUES FROM ('2022-04-01') TO ('2022-07-01');

CREATE TABLE IF NOT EXISTS fact_vuelos_2022_q3
    PARTITION OF fact_vuelos
    FOR VALUES FROM ('2022-07-01') TO ('2022-10-01');

CREATE TABLE IF NOT EXISTS fact_vuelos_2022_q4
    PARTITION OF fact_vuelos
    FOR VALUES FROM ('2022-10-01') TO ('2023-01-01');


-- ══════════════════════════════════════════════════════
-- PARTICIONES 2023
-- ══════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS fact_vuelos_2023_q1
    PARTITION OF fact_vuelos
    FOR VALUES FROM ('2023-01-01') TO ('2023-04-01');

CREATE TABLE IF NOT EXISTS fact_vuelos_2023_q2
    PARTITION OF fact_vuelos
    FOR VALUES FROM ('2023-04-01') TO ('2023-07-01');

CREATE TABLE IF NOT EXISTS fact_vuelos_2023_q3
    PARTITION OF fact_vuelos
    FOR VALUES FROM ('2023-07-01') TO ('2023-10-01');

CREATE TABLE IF NOT EXISTS fact_vuelos_2023_q4
    PARTITION OF fact_vuelos
    FOR VALUES FROM ('2023-10-01') TO ('2024-01-01');


-- ══════════════════════════════════════════════════════
-- PARTICIONES 2024
-- ══════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS fact_vuelos_2024_q1
    PARTITION OF fact_vuelos
    FOR VALUES FROM ('2024-01-01') TO ('2024-04-01');

CREATE TABLE IF NOT EXISTS fact_vuelos_2024_q2
    PARTITION OF fact_vuelos
    FOR VALUES FROM ('2024-04-01') TO ('2024-07-01');

CREATE TABLE IF NOT EXISTS fact_vuelos_2024_q3
    PARTITION OF fact_vuelos
    FOR VALUES FROM ('2024-07-01') TO ('2024-10-01');

CREATE TABLE IF NOT EXISTS fact_vuelos_2024_q4
    PARTITION OF fact_vuelos
    FOR VALUES FROM ('2024-10-01') TO ('2025-01-01');


-- ══════════════════════════════════════════════════════
-- FOREIGN KEYS
-- ══════════════════════════════════════════════════════

ALTER TABLE fact_vuelos
    ADD CONSTRAINT fk_fact_tiempo
        FOREIGN KEY (tiempo_id) REFERENCES dim_tiempo(tiempo_id);

ALTER TABLE fact_vuelos
    ADD CONSTRAINT fk_fact_aerolinea
        FOREIGN KEY (aerolinea_id) REFERENCES dim_aerolinea(aerolinea_id);

ALTER TABLE fact_vuelos
    ADD CONSTRAINT fk_fact_origen
        FOREIGN KEY (aeropuerto_origen_id) REFERENCES dim_aeropuerto(aeropuerto_id);

ALTER TABLE fact_vuelos
    ADD CONSTRAINT fk_fact_destino
        FOREIGN KEY (aeropuerto_destino_id) REFERENCES dim_aeropuerto(aeropuerto_id);

ALTER TABLE fact_vuelos
    ADD CONSTRAINT fk_fact_estado
        FOREIGN KEY (estado_id) REFERENCES dim_estado_vuelo(estado_id);



-- ══════════════════════════════════════════════════════
-- ÍNDICES
-- ══════════════════════════════════════════════════════

-- Índice 1: filtros por fecha (partition pruning)
CREATE INDEX IF NOT EXISTS idx_fact_fecha
    ON fact_vuelos (fecha_vuelo);

-- Índice 2: filtros por aerolínea
CREATE INDEX IF NOT EXISTS idx_fact_aerolinea
    ON fact_vuelos (aerolinea_id);

-- Índice 3: compuesto aerolínea + fecha
CREATE INDEX IF NOT EXISTS idx_fact_aerolinea_fecha
    ON fact_vuelos (aerolinea_id, fecha_vuelo);


