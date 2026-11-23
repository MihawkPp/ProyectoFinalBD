-- =====================================================================
-- 04_compras_neon.sql  -  Microservicio: Compras y Abastecimiento (Neon)
-- Proyecto Neon: empresa-compras
-- Entidades: ordenes_compra, detalle_orden_compra, recepciones_compra,
--            detalle_recepcion (4 tablas)
-- =====================================================================

-- ---------- 1. DDL y Restricciones ----------
CREATE TABLE ordenes_compra (
  id_orden_compra    INTEGER GENERATED ALWAYS AS IDENTITY,
  id_proveedor       INTEGER     NOT NULL,
  id_almacen_destino INTEGER     NOT NULL,
  id_empleado        INTEGER     NOT NULL,
  fecha_orden        DATE        NOT NULL,
  fecha_estimada     DATE        NOT NULL,
  estado             VARCHAR(10) NOT NULL DEFAULT 'EMITIDA',
  CONSTRAINT pk_ordenes_compra PRIMARY KEY (id_orden_compra),
  CONSTRAINT ck_oc_fechas CHECK (fecha_estimada >= fecha_orden),
  CONSTRAINT ck_oc_estado CHECK (estado IN ('EMITIDA', 'PARCIAL', 'RECIBIDA', 'CANCELADA'))
);

CREATE TABLE detalle_orden_compra (
  id_orden_compra     INTEGER       NOT NULL,
  id_producto         INTEGER       NOT NULL,
  cantidad_solicitada INTEGER       NOT NULL,
  costo_unitario      NUMERIC(14,2) NOT NULL,
  CONSTRAINT pk_detalle_orden_compra PRIMARY KEY (id_orden_compra, id_producto),
  CONSTRAINT fk_doc_orden FOREIGN KEY (id_orden_compra) REFERENCES ordenes_compra (id_orden_compra),
  CONSTRAINT ck_doc_cantidad CHECK (cantidad_solicitada > 0),
  CONSTRAINT ck_doc_costo CHECK (costo_unitario >= 0)
);

CREATE TABLE recepciones_compra (
  id_recepcion    INTEGER GENERATED ALWAYS AS IDENTITY,
  id_orden_compra INTEGER     NOT NULL,
  fecha_recepcion DATE        NOT NULL,
  estado          VARCHAR(10) NOT NULL,
  CONSTRAINT pk_recepciones_compra PRIMARY KEY (id_recepcion),
  CONSTRAINT fk_recepcion_orden FOREIGN KEY (id_orden_compra) REFERENCES ordenes_compra (id_orden_compra),
  CONSTRAINT ck_recepcion_estado CHECK (estado IN ('PARCIAL', 'COMPLETA'))
);

CREATE INDEX ix_recepciones_orden ON recepciones_compra (id_orden_compra);

CREATE TABLE detalle_recepcion (
  id_recepcion      INTEGER NOT NULL,
  id_producto       INTEGER NOT NULL,
  cantidad_recibida INTEGER NOT NULL,
  CONSTRAINT pk_detalle_recepcion PRIMARY KEY (id_recepcion, id_producto),
  CONSTRAINT fk_dr_recepcion FOREIGN KEY (id_recepcion) REFERENCES recepciones_compra (id_recepcion),
  CONSTRAINT ck_dr_cantidad CHECK (cantidad_recibida > 0)
);

-- Vista local de compras pendientes de recepcion
CREATE OR REPLACE VIEW vista_compras_pendientes AS
WITH recepciones_acum AS (
  SELECT
    r.id_orden_compra,
    dr.id_producto,
    SUM(dr.cantidad_recibida) AS total_recibido
  FROM recepciones_compra r
  JOIN detalle_recepcion dr ON dr.id_recepcion = r.id_recepcion
  GROUP BY r.id_orden_compra, dr.id_producto
)
SELECT
  oc.id_orden_compra,
  oc.id_proveedor,
  oc.id_almacen_destino,
  oc.fecha_orden,
  oc.fecha_estimada,
  oc.estado AS estado_orden,
  doc.id_producto,
  doc.cantidad_solicitada,
  COALESCE(ra.total_recibido, 0) AS cantidad_recibida,
  (doc.cantidad_solicitada - COALESCE(ra.total_recibido, 0)) AS cantidad_pendiente
FROM ordenes_compra oc
JOIN detalle_orden_compra doc ON doc.id_orden_compra = oc.id_orden_compra
LEFT JOIN recepciones_acum ra ON ra.id_orden_compra = oc.id_orden_compra AND ra.id_producto = doc.id_producto
WHERE oc.estado IN ('EMITIDA', 'PARCIAL')
  AND (doc.cantidad_solicitada - COALESCE(ra.total_recibido, 0)) > 0;

-- ---------- 2. Carga de Datos de Prueba ----------
SELECT setseed(0.42);

INSERT INTO ordenes_compra (id_proveedor, id_almacen_destino, id_empleado, fecha_orden, fecha_estimada, estado)
SELECT
  (((g - 1) % 10) + 1) AS id_proveedor,
  CASE (g % 4) WHEN 0 THEN 4 WHEN 1 THEN 1 WHEN 2 THEN 2 ELSE 3 END AS id_almacen_destino,
  3 AS id_empleado,
  DATE '2026-05-01' + ((g * 3) % 160) AS fecha_orden,
  DATE '2026-05-01' + ((g * 3) % 160) + 8 AS fecha_estimada,
  CASE
    WHEN g % 12 = 0 THEN 'EMITIDA'
    WHEN g % 12 = 5 THEN 'PARCIAL'
    WHEN g % 12 = 9 THEN 'CANCELADA'
    ELSE 'RECIBIDA'
  END AS estado
FROM generate_series(1, 60) AS g;

INSERT INTO detalle_orden_compra (id_orden_compra, id_producto, cantidad_solicitada, costo_unitario)
SELECT
  oc.id_orden_compra,
  (((oc.id_orden_compra * 2) + n) % 80) + 1 AS id_producto,
  (15 * (n + 1)) AS cantidad_solicitada,
  ROUND((15000 + ((((oc.id_orden_compra * 2) + n) % 80) + 1) * 2300) * 0.65, 2) AS costo_unitario
FROM ordenes_compra oc
CROSS JOIN generate_series(0, 1) AS n;

INSERT INTO recepciones_compra (id_orden_compra, fecha_recepcion, estado)
SELECT
  oc.id_orden_compra,
  CASE
    WHEN oc.id_orden_compra % 5 = 0 THEN oc.fecha_estimada + 3
    ELSE oc.fecha_estimada - 1
  END AS fecha_recepcion,
  CASE WHEN oc.estado = 'PARCIAL' THEN 'PARCIAL' ELSE 'COMPLETA' END AS estado
FROM ordenes_compra oc
WHERE oc.estado IN ('PARCIAL', 'RECIBIDA');

INSERT INTO detalle_recepcion (id_recepcion, id_producto, cantidad_recibida)
SELECT
  r.id_recepcion,
  doc.id_producto,
  CASE
    WHEN r.estado = 'PARCIAL' THEN (doc.cantidad_solicitada / 2)
    ELSE doc.cantidad_solicitada
  END AS cantidad_recibida
FROM recepciones_compra r
JOIN detalle_orden_compra doc ON doc.id_orden_compra = r.id_orden_compra;


-- ---------- 3. Permisos en empresa_compras ----------
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO r_administrador;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO r_administrador;
GRANT CREATE ON SCHEMA public TO r_administrador;

-- Gerencia: consulta sin modificar (§8.2)
GRANT SELECT ON ALL TABLES IN SCHEMA public TO r_gerencia;
GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA public TO r_compras;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO r_auditor;
