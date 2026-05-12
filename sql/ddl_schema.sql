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
