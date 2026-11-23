-- =====================================================================
-- 03_inventarios_neon.sql  -  Microservicio: Inventarios y Transferencias (Neon)
-- Proyecto Neon: empresa-inventarios
-- Entidades: inventarios (particionada), transferencias, detalle_transferencia
-- =====================================================================

-- ---------- 1. DDL y Particionamiento ----------
CREATE TABLE inventarios (
  id_sede             SMALLINT  NOT NULL,
  id_almacen          INTEGER   NOT NULL,
  id_producto         INTEGER   NOT NULL,
  existencia_actual   INTEGER   NOT NULL DEFAULT 0,
  stock_minimo        INTEGER   NOT NULL DEFAULT 0,
  fecha_actualizacion TIMESTAMP NOT NULL DEFAULT now(),
  CONSTRAINT pk_inventarios PRIMARY KEY (id_sede, id_almacen, id_producto),
  CONSTRAINT ck_inv_existencia CHECK (existencia_actual >= 0),
  CONSTRAINT ck_inv_minimo CHECK (stock_minimo >= 0)
) PARTITION BY LIST (id_sede);

CREATE INDEX ix_inventarios_producto ON inventarios (id_producto);

CREATE TABLE inventarios_norte        PARTITION OF inventarios (id_sede DEFAULT 1) FOR VALUES IN (1);
CREATE TABLE inventarios_sur          PARTITION OF inventarios (id_sede DEFAULT 2) FOR VALUES IN (2);
CREATE TABLE inventarios_occidente    PARTITION OF inventarios (id_sede DEFAULT 3) FOR VALUES IN (3);
CREATE TABLE inventarios_distribucion PARTITION OF inventarios (id_sede DEFAULT 4) FOR VALUES IN (4);

CREATE TABLE transferencias (
  id_transferencia   INTEGER GENERATED ALWAYS AS IDENTITY,
  id_almacen_origen  INTEGER     NOT NULL,
  id_almacen_destino INTEGER     NOT NULL,
  fecha_solicitud    DATE        NOT NULL,
  fecha_despacho     DATE,
  fecha_recepcion    DATE,
  estado             VARCHAR(12) NOT NULL DEFAULT 'SOLICITADA',
  CONSTRAINT pk_transferencias PRIMARY KEY (id_transferencia),
  CONSTRAINT ck_transf_almacenes CHECK (id_almacen_origen <> id_almacen_destino),
  CONSTRAINT ck_transf_estado CHECK (estado IN ('SOLICITADA', 'DESPACHADA', 'RECIBIDA', 'CANCELADA')),
  CONSTRAINT ck_transf_fechas CHECK (
    (fecha_despacho IS NULL OR fecha_despacho >= fecha_solicitud) AND
    (fecha_recepcion IS NULL OR (fecha_despacho IS NOT NULL AND fecha_recepcion >= fecha_despacho))
  ),
  CONSTRAINT ck_transf_estado_fechas CHECK (
    (estado = 'SOLICITADA' AND fecha_despacho IS NULL AND fecha_recepcion IS NULL) OR
    (estado = 'DESPACHADA' AND fecha_despacho IS NOT NULL AND fecha_recepcion IS NULL) OR
    (estado = 'RECIBIDA'   AND fecha_despacho IS NOT NULL AND fecha_recepcion IS NOT NULL) OR
    (estado = 'CANCELADA')
  )
);

CREATE TABLE detalle_transferencia (
  id_transferencia  INTEGER NOT NULL,
  id_producto       INTEGER NOT NULL,
  cantidad_enviada  INTEGER NOT NULL,
  cantidad_recibida INTEGER,
  CONSTRAINT pk_detalle_transferencia PRIMARY KEY (id_transferencia, id_producto),
  CONSTRAINT fk_dt_transferencia FOREIGN KEY (id_transferencia) REFERENCES transferencias (id_transferencia),
  CONSTRAINT ck_dt_enviada CHECK (cantidad_enviada > 0),
  CONSTRAINT ck_dt_recibida CHECK (cantidad_recibida IS NULL OR cantidad_recibida >= 0)
);

-- Vista unificada con fragmento de origen
CREATE VIEW v_inventarios AS
  SELECT 'inventarios_norte'::text        AS fragmento_origen, * FROM inventarios_norte
  UNION ALL
  SELECT 'inventarios_sur'::text,          * FROM inventarios_sur
  UNION ALL
  SELECT 'inventarios_occidente'::text,    * FROM inventarios_occidente
  UNION ALL
  SELECT 'inventarios_distribucion'::text, * FROM inventarios_distribucion;

-- Vista local de transferencias en transito
CREATE OR REPLACE VIEW vista_transferencias_en_transito AS
SELECT
  t.id_transferencia,
  t.id_almacen_origen,
  t.id_almacen_destino,
  t.fecha_solicitud,
  t.fecha_despacho,
  dt.id_producto,
  dt.cantidad_enviada,
  (DATE '2026-10-31' - t.fecha_despacho) AS dias_en_transito
FROM transferencias t
JOIN detalle_transferencia dt ON dt.id_transferencia = t.id_transferencia
WHERE t.estado = 'DESPACHADA'
  AND t.fecha_recepcion IS NULL;

-- ---------- 2. Carga de Datos de Prueba ----------
SELECT setseed(0.42);

INSERT INTO inventarios (id_sede, id_almacen, id_producto, existencia_actual, stock_minimo, fecha_actualizacion)
SELECT
  sede_almacen.id_sede,
  sede_almacen.id_almacen,
  p.id_producto,
  CASE
    WHEN (p.id_producto + sede_almacen.id_almacen) % 11 = 0 THEN 0
    WHEN (p.id_producto + sede_almacen.id_almacen) % 7 = 0  THEN 3
    ELSE 15 + ((p.id_producto * sede_almacen.id_almacen * 3) % 85)
  END AS existencia_actual,
  10 AS stock_minimo,
  TIMESTAMP '2026-10-31 10:00:00' - ((p.id_producto + sede_almacen.id_almacen) * INTERVAL '2 hours')
FROM (
  VALUES (1::smallint, 1), (2::smallint, 2), (3::smallint, 3),
         (4::smallint, 4), (4::smallint, 5), (4::smallint, 6)
) AS sede_almacen(id_sede, id_almacen)
CROSS JOIN generate_series(1, 80) AS p(id_producto)
WHERE NOT (p.id_producto > 72 AND sede_almacen.id_sede = 2);

-- 25 transferencias
INSERT INTO transferencias (id_almacen_origen, id_almacen_destino, fecha_solicitud, fecha_despacho, fecha_recepcion, estado)
SELECT
  4 AS id_almacen_origen,
  dest.id_almacen AS id_almacen_destino,
  DATE '2026-09-01' + (g * 2) AS fecha_solicitud,
  CASE
    WHEN st.estado IN ('DESPACHADA', 'RECIBIDA') THEN DATE '2026-09-01' + (g * 2) + 1
    ELSE NULL
  END AS fecha_despacho,
  CASE
    WHEN st.estado = 'RECIBIDA' THEN DATE '2026-09-01' + (g * 2) + 3
    ELSE NULL
  END AS fecha_recepcion,
  st.estado
FROM generate_series(1, 25) AS g
CROSS JOIN LATERAL (SELECT ((g % 3) + 1) AS id_almacen) AS dest
CROSS JOIN LATERAL (
  SELECT CASE
    WHEN g % 6 = 0 THEN 'SOLICITADA'
    WHEN g % 5 = 0 THEN 'DESPACHADA'
    WHEN g % 8 = 0 THEN 'CANCELADA'
    ELSE 'RECIBIDA'
  END AS estado
) AS st;

INSERT INTO detalle_transferencia (id_transferencia, id_producto, cantidad_enviada, cantidad_recibida)
SELECT
  t.id_transferencia,
  (((t.id_transferencia * 3) + n) % 80) + 1 AS id_producto,
  20 AS cantidad_enviada,
  CASE
    WHEN t.estado <> 'RECIBIDA' THEN NULL
    WHEN t.id_transferencia % 4 = 0 THEN 18
    ELSE 20
  END AS cantidad_recibida
FROM transferencias t
CROSS JOIN generate_series(1, 2) AS n;


-- ---------- 3. Permisos en empresa_inventarios ----------
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO r_administrador;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO r_administrador;
GRANT CREATE ON SCHEMA public TO r_administrador;

-- Gerencia: consulta sin modificar (§8.2)
GRANT SELECT ON ALL TABLES IN SCHEMA public TO r_gerencia;

-- Responsable de inventario: gestion de transferencias y acceso por particion
GRANT SELECT, INSERT, UPDATE ON transferencias, detalle_transferencia, vista_transferencias_en_transito TO r_inventario;

-- Aislamiento por particion de sede
GRANT SELECT, INSERT, UPDATE ON inventarios_norte        TO u_inv_norte;
GRANT SELECT, INSERT, UPDATE ON inventarios_sur          TO u_inv_sur;
GRANT SELECT, INSERT, UPDATE ON inventarios_occidente    TO u_inv_occidente;
GRANT SELECT, INSERT, UPDATE ON inventarios_distribucion TO u_inv_distribucion;

-- Auditor: consulta completa
GRANT SELECT ON ALL TABLES IN SCHEMA public TO r_auditor;
