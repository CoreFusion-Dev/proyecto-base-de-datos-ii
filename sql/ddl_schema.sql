-- ══════════════════════════════════════════════════════
-- DDL SCHEMA - flights_dw
-- Proyecto Final Base de Datos II
-- Dataset: Airline On-Time Performance (BTS) 2021-2024
-- PostgreSQL 16.4
-- ══════════════════════════════════════════════════════


-- ══════════════════════════════════════════════════════
-- DIMENSIONES
-- ══════════════════════════════════════════════════════

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


-- Tabla dimensional de tiempo para registros de arelolinea
CREATE TABLE IF NOT EXISTS dim_aerolinea (
    aerolinea_id  INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    codigo        VARCHAR(10) NOT NULL,
    nombre        VARCHAR(100) NOT NULL,
    CONSTRAINT uq_dim_aerolinea_codigo UNIQUE (codigo)
);

-- Tabla dimensional de aeropuestos destructurada
CREATE TABLE IF NOT EXISTS dim_aeropuerto (
    aeropuerto_id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    codigo        VARCHAR(10) NOT NULL,
    ciudad        VARCHAR(100),
    estado        VARCHAR(10),
    nombre_estado VARCHAR(100),
    pais          VARCHAR(50) DEFAULT 'USA',
    CONSTRAINT uq_dim_aeropuerto_codigo UNIQUE (codigo)
);

-- Tabla dimensional de estados de vuelos desnormalizada
CREATE TABLE IF NOT EXISTS dim_estado_vuelo (
    estado_id    INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    codigo       VARCHAR(20) NOT NULL,
    descripcion  VARCHAR(100) NOT NULL,
    CONSTRAINT uq_dim_estado_codigo UNIQUE (codigo)
);


-- ══════════════════════════════════════════════════════
-- TABLA DE HECHOS PADRE (particionada por trimestre)
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
    retraso_aeronave      NUMERIC(8,2)
) PARTITION BY RANGE (fecha_vuelo);
