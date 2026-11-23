-- =====================================================================
-- 05_ventas_neon.sql  -  Microservicio: Ventas y Pagos (Neon)
-- Proyecto Neon: empresa-ventas
-- Entidades: pedidos_venta, detalle_pedido, pagos, devoluciones,
--            detalle_devolucion (5 tablas lógicas, 12 particiones físicas)
-- =====================================================================

-- ---------- 1. DDL y Particionamiento ----------

CREATE SEQUENCE seq_pedido AS BIGINT;

CREATE TABLE pedidos_venta (
  id_sede          SMALLINT      NOT NULL,
  id_pedido        BIGINT        NOT NULL DEFAULT nextval('seq_pedido'),
  id_almacen       INTEGER       NOT NULL,
  id_cliente       INTEGER       NOT NULL,
  id_empleado      INTEGER       NOT NULL,
  fecha_pedido     DATE          NOT NULL,
  estado           VARCHAR(12)   NOT NULL DEFAULT 'PENDIENTE',
  total_registrado NUMERIC(14,2) NOT NULL DEFAULT 0.00,
  CONSTRAINT pk_pedidos_venta PRIMARY KEY (id_sede, id_pedido),
  CONSTRAINT ck_pedidos_estado CHECK (estado IN ('PENDIENTE', 'CONFIRMADO', 'DESPACHADO', 'ENTREGADO', 'ANULADO')),
  CONSTRAINT ck_pedidos_total CHECK (total_registrado >= 0)
) PARTITION BY LIST (id_sede);

ALTER SEQUENCE seq_pedido OWNED BY pedidos_venta.id_pedido;

CREATE INDEX ix_pedidos_cliente ON pedidos_venta (id_cliente);
CREATE INDEX ix_pedidos_fecha   ON pedidos_venta (fecha_pedido);

CREATE TABLE pedidos_norte        PARTITION OF pedidos_venta (id_sede DEFAULT 1) FOR VALUES IN (1);
CREATE TABLE pedidos_sur          PARTITION OF pedidos_venta (id_sede DEFAULT 2) FOR VALUES IN (2);
CREATE TABLE pedidos_occidente    PARTITION OF pedidos_venta (id_sede DEFAULT 3) FOR VALUES IN (3);
CREATE TABLE pedidos_distribucion PARTITION OF pedidos_venta (id_sede DEFAULT 4) FOR VALUES IN (4);

CREATE TABLE detalle_pedido (
  id_sede         SMALLINT      NOT NULL,
  id_pedido       BIGINT        NOT NULL,
  id_producto     INTEGER       NOT NULL,
  cantidad        INTEGER       NOT NULL,
  precio_unitario NUMERIC(14,2) NOT NULL,
  CONSTRAINT pk_detalle_pedido PRIMARY KEY (id_sede, id_pedido, id_producto),
  CONSTRAINT fk_detalle_pedido FOREIGN KEY (id_sede, id_pedido) REFERENCES pedidos_venta (id_sede, id_pedido),
  CONSTRAINT ck_dped_cantidad CHECK (cantidad > 0),
  CONSTRAINT ck_dped_precio   CHECK (precio_unitario >= 0)
) PARTITION BY LIST (id_sede);

CREATE INDEX ix_detalle_pedido_producto ON detalle_pedido (id_producto);

CREATE TABLE detalle_pedido_norte        PARTITION OF detalle_pedido (id_sede DEFAULT 1) FOR VALUES IN (1);
CREATE TABLE detalle_pedido_sur          PARTITION OF detalle_pedido (id_sede DEFAULT 2) FOR VALUES IN (2);
CREATE TABLE detalle_pedido_occidente    PARTITION OF detalle_pedido (id_sede DEFAULT 3) FOR VALUES IN (3);
CREATE TABLE detalle_pedido_distribucion PARTITION OF detalle_pedido (id_sede DEFAULT 4) FOR VALUES IN (4);

CREATE SEQUENCE seq_pago AS BIGINT;

CREATE TABLE pagos (
  id_pago    BIGINT        NOT NULL DEFAULT nextval('seq_pago'),
  id_sede    SMALLINT      NOT NULL,
  id_pedido  BIGINT        NOT NULL,
  fecha_pago DATE          NOT NULL,
  valor      NUMERIC(14,2) NOT NULL,
  medio_pago VARCHAR(15)   NOT NULL,
  estado     VARCHAR(10)   NOT NULL DEFAULT 'PENDIENTE',
  CONSTRAINT pk_pagos        PRIMARY KEY (id_sede, id_pago),
  CONSTRAINT fk_pagos_pedido FOREIGN KEY (id_sede, id_pedido) REFERENCES pedidos_venta (id_sede, id_pedido),
  CONSTRAINT ck_pagos_valor  CHECK (valor > 0),
  CONSTRAINT ck_pagos_medio  CHECK (medio_pago IN ('EFECTIVO','TARJETA','TRANSFERENCIA','PSE')),
  CONSTRAINT ck_pagos_estado CHECK (estado IN ('PENDIENTE','CONFIRMADO','RECHAZADO'))
) PARTITION BY LIST (id_sede);

ALTER SEQUENCE seq_pago OWNED BY pagos.id_pago;
CREATE INDEX ix_pagos_pedido ON pagos (id_sede, id_pedido);

CREATE TABLE pagos_norte        PARTITION OF pagos (id_sede DEFAULT 1) FOR VALUES IN (1);
CREATE TABLE pagos_sur          PARTITION OF pagos (id_sede DEFAULT 2) FOR VALUES IN (2);
CREATE TABLE pagos_occidente    PARTITION OF pagos (id_sede DEFAULT 3) FOR VALUES IN (3);
CREATE TABLE pagos_distribucion PARTITION OF pagos (id_sede DEFAULT 4) FOR VALUES IN (4);

CREATE TABLE devoluciones (
  id_devolucion   INTEGER GENERATED ALWAYS AS IDENTITY,
  id_sede         SMALLINT     NOT NULL,
  id_pedido       BIGINT       NOT NULL,
  fecha_solicitud DATE         NOT NULL,
  motivo          VARCHAR(255) NOT NULL,
  estado          VARCHAR(10)  NOT NULL DEFAULT 'SOLICITADA',
  CONSTRAINT pk_devoluciones        PRIMARY KEY (id_devolucion),
  CONSTRAINT fk_devoluciones_pedido FOREIGN KEY (id_sede, id_pedido) REFERENCES pedidos_venta (id_sede, id_pedido),
  CONSTRAINT ck_dev_motivo CHECK (length(btrim(motivo)) > 0),
  CONSTRAINT ck_dev_estado CHECK (estado IN ('SOLICITADA','APROBADA','RECHAZADA'))
);

CREATE INDEX ix_devoluciones_pedido ON devoluciones (id_sede, id_pedido);

CREATE TABLE detalle_devolucion (
  id_devolucion      INTEGER     NOT NULL,
  id_producto        INTEGER     NOT NULL,
  cantidad           INTEGER     NOT NULL,
  condicion_producto VARCHAR(15) NOT NULL,
  CONSTRAINT pk_detalle_devolucion PRIMARY KEY (id_devolucion, id_producto),
  CONSTRAINT fk_dd_devolucion FOREIGN KEY (id_devolucion) REFERENCES devoluciones (id_devolucion),
  CONSTRAINT ck_dd_cantidad   CHECK (cantidad > 0),
  CONSTRAINT ck_dd_condicion  CHECK (condicion_producto IN ('NUEVO','AVERIADO','INCOMPLETO'))
);

-- ---------- Vistas unificadas del servicio de Ventas ----------
CREATE VIEW v_pedidos_venta AS
  SELECT 'pedidos_norte'::text        AS fragmento_origen, * FROM pedidos_norte
  UNION ALL
  SELECT 'pedidos_sur'::text,          * FROM pedidos_sur
  UNION ALL
  SELECT 'pedidos_occidente'::text,    * FROM pedidos_occidente
  UNION ALL
  SELECT 'pedidos_distribucion'::text, * FROM pedidos_distribucion;

CREATE VIEW v_detalle_pedido AS
  SELECT 'detalle_pedido_norte'::text        AS fragmento_origen, * FROM detalle_pedido_norte
  UNION ALL
  SELECT 'detalle_pedido_sur'::text,          * FROM detalle_pedido_sur
  UNION ALL
  SELECT 'detalle_pedido_occidente'::text,    * FROM detalle_pedido_occidente
  UNION ALL
  SELECT 'detalle_pedido_distribucion'::text, * FROM detalle_pedido_distribucion;

CREATE VIEW v_pagos AS
  SELECT 'pagos_norte'::text        AS fragmento_origen, * FROM pagos_norte
  UNION ALL
  SELECT 'pagos_sur'::text,          * FROM pagos_sur
  UNION ALL
  SELECT 'pagos_occidente'::text,    * FROM pagos_occidente
  UNION ALL
  SELECT 'pagos_distribucion'::text, * FROM pagos_distribucion;

CREATE OR REPLACE VIEW vista_pedidos_pendientes WITH (security_invoker = true) AS
SELECT
  id_sede,
  id_pedido,
  id_almacen,
  id_cliente,
  id_empleado,
  fecha_pedido,
  estado,
  total_registrado
FROM pedidos_venta
WHERE estado IN ('PENDIENTE', 'CONFIRMADO');

CREATE OR REPLACE VIEW vista_saldos_pendientes WITH (security_invoker = true) AS
WITH pagos_conf AS (
  SELECT id_sede, id_pedido, SUM(valor) AS total_pagado
  FROM pagos
  WHERE estado = 'CONFIRMADO'
  GROUP BY id_sede, id_pedido
)
SELECT
  pv.id_sede,
  pv.id_pedido,
  pv.fecha_pedido,
  pv.estado AS estado_pedido,
  pv.total_registrado,
  COALESCE(pc.total_pagado, 0.00) AS total_pagado,
  ROUND((pv.total_registrado - COALESCE(pc.total_pagado, 0.00))::numeric, 2) AS saldo_pendiente
FROM pedidos_venta pv
LEFT JOIN pagos_conf pc ON pc.id_sede = pv.id_sede AND pc.id_pedido = pv.id_pedido
WHERE pv.estado NOT IN ('ANULADO')
  AND (pv.total_registrado - COALESCE(pc.total_pagado, 0.00)) > 0;

-- ---------- 2. Carga de Datos de Prueba ----------
SELECT setseed(0.42);

INSERT INTO pedidos_venta (id_sede, id_almacen, id_cliente, id_empleado, fecha_pedido, estado, total_registrado)
SELECT
  sede.id_sede,
  CASE sede.id_sede
    WHEN 1 THEN 1
    WHEN 2 THEN 2
    WHEN 3 THEN 3
    ELSE (CASE WHEN ((g - 1) / 4) % 2 = 0 THEN 4 ELSE 5 END)
  END AS id_almacen,
  ((g * 7 + (g - 1) / 100) % 100) + 1 AS id_cliente,
  ((sede.id_sede - 1) * 5) + (CASE WHEN ((g - 1) / 4) % 2 = 0 THEN 4 ELSE 5 END) AS id_empleado,
  DATE '2026-05-02' + ((g * 2) % 175) AS fecha_pedido,
  CASE
    WHEN g % 17 = 0 THEN 'ANULADO'
    WHEN g % 7 = 0  THEN 'PENDIENTE'
    WHEN g % 5 = 0  THEN 'DESPACHADO'
    WHEN ((g - 1) / 4) % 4 = 0 THEN 'CONFIRMADO'
    ELSE 'ENTREGADO'
  END AS estado,
  0.00
FROM generate_series(1, 320) AS g
CROSS JOIN LATERAL (SELECT (((g - 1) % 4) + 1)::smallint AS id_sede) AS sede;

INSERT INTO detalle_pedido (id_sede, id_pedido, id_producto, cantidad, precio_unitario)
SELECT
  pv.id_sede,
  pv.id_pedido,
  p.id_producto,
  (((pv.id_pedido + n) % 5) + 1) AS cantidad,
  ROUND((15000 + (p.id_producto * 2300))::numeric, 2) AS precio_unitario
FROM pedidos_venta pv
CROSS JOIN generate_series(0, 2) AS n
CROSS JOIN LATERAL (
  SELECT (((pv.id_pedido * 3) + n) % 80) + 1 AS id_producto
) p
WHERE n = 0 OR (pv.id_pedido % 2 = 0 AND n = 1) OR (pv.id_pedido % 3 = 0 AND n = 2);

UPDATE pedidos_venta pv
SET total_registrado = sub.total
FROM (
  SELECT id_sede, id_pedido, SUM(cantidad * precio_unitario) AS total
  FROM detalle_pedido
  GROUP BY id_sede, id_pedido
) sub
WHERE pv.id_sede = sub.id_sede AND pv.id_pedido = sub.id_pedido;

INSERT INTO pagos (id_sede, id_pedido, fecha_pago, valor, medio_pago, estado)
SELECT
  pv.id_sede,
  pv.id_pedido,
  pv.fecha_pedido + 1,
  CASE
    WHEN pv.id_pedido % 5 = 0 THEN ROUND(pv.total_registrado * 0.50, 2)
    ELSE pv.total_registrado
  END AS valor,
  CASE (pv.id_pedido % 4)
    WHEN 0 THEN 'TRANSFERENCIA'
    WHEN 1 THEN 'TARJETA'
    WHEN 2 THEN 'EFECTIVO'
    ELSE 'PSE'
  END AS medio_pago,
  'CONFIRMADO' AS estado
FROM pedidos_venta pv
WHERE pv.estado IN ('CONFIRMADO', 'DESPACHADO', 'ENTREGADO');

-- Segundo pago para pedidos con pago parcial (genera pagos múltiples, requisito §4.8)
INSERT INTO pagos (id_sede, id_pedido, fecha_pago, valor, medio_pago, estado)
SELECT
  pv.id_sede,
  pv.id_pedido,
  pv.fecha_pedido + 3,
  ROUND(pv.total_registrado * 0.30, 2) AS valor,
  'PSE' AS medio_pago,
  'CONFIRMADO' AS estado
FROM pedidos_venta pv
WHERE pv.estado IN ('CONFIRMADO', 'DESPACHADO', 'ENTREGADO') AND pv.id_pedido % 5 = 0;

INSERT INTO pagos (id_sede, id_pedido, fecha_pago, valor, medio_pago, estado)
SELECT
  pv.id_sede,
  pv.id_pedido,
  pv.fecha_pedido + 1,
  pv.total_registrado,
  'TARJETA' AS medio_pago,
  'RECHAZADO' AS estado
FROM pedidos_venta pv
WHERE pv.estado = 'PENDIENTE' AND pv.id_pedido % 5 = 0;

INSERT INTO devoluciones (id_sede, id_pedido, fecha_solicitud, motivo, estado)
SELECT
  pv.id_sede,
  pv.id_pedido,
  pv.fecha_pedido + 5,
  CASE WHEN pv.id_pedido % 2 = 0 THEN 'Producto averiado en transporte' ELSE 'No corresponde a especificaciones' END AS motivo,
  CASE (pv.id_pedido % 3)
    WHEN 0 THEN 'SOLICITADA'
    WHEN 1 THEN 'APROBADA'
    ELSE 'RECHAZADA'
  END AS estado
FROM (
  SELECT id_sede, id_pedido, fecha_pedido
  FROM pedidos_venta
  WHERE estado = 'ENTREGADO'
  ORDER BY id_pedido
  LIMIT 20
) pv;

INSERT INTO detalle_devolucion (id_devolucion, id_producto, cantidad, condicion_producto)
SELECT
  d.id_devolucion,
  dp.id_producto,
  1 AS cantidad,
  CASE WHEN d.id_devolucion % 2 = 0 THEN 'AVERIADO' ELSE 'NUEVO' END AS condicion_producto
FROM devoluciones d
JOIN LATERAL (
  SELECT id_producto
  FROM detalle_pedido dp
  WHERE dp.id_sede = d.id_sede AND dp.id_pedido = d.id_pedido
  LIMIT 1
) dp ON true;


-- ---------- 3. Permisos en empresa_ventas ----------
-- Administrador: control total
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO r_administrador;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO r_administrador;
GRANT CREATE ON SCHEMA public TO r_administrador;

-- Gerencia y Auditor: lectura de todo, incluidas las vistas de gestion.
-- Como las vistas son security_invoker, solo estos roles (que tienen SELECT
-- sobre las tablas padre) pueden leerlas a nivel corporativo.
GRANT SELECT ON ALL TABLES IN SCHEMA public TO r_gerencia, r_auditor;

-- Vendedor: secuencias para crear pedidos/pagos y devoluciones (no particionadas).
-- NO recibe acceso a las tablas padre ni a las vistas corporativas: asi queda
-- confinado a su sede y no puede ver pedidos de otras (corrige la fuga §8.5).
GRANT USAGE ON SEQUENCE seq_pedido, seq_pago TO r_vendedor;
GRANT SELECT, INSERT, UPDATE ON devoluciones, detalle_devolucion TO r_vendedor;

-- Aislamiento estricto por fragmento de sede: cada vendedor solo su particion
GRANT SELECT, INSERT, UPDATE ON pedidos_norte,        detalle_pedido_norte,        pagos_norte        TO u_vend_norte;
GRANT SELECT, INSERT, UPDATE ON pedidos_sur,          detalle_pedido_sur,          pagos_sur          TO u_vend_sur;
GRANT SELECT, INSERT, UPDATE ON pedidos_occidente,    detalle_pedido_occidente,    pagos_occidente    TO u_vend_occidente;
GRANT SELECT, INSERT, UPDATE ON pedidos_distribucion, detalle_pedido_distribucion, pagos_distribucion TO u_vend_distribucion;
