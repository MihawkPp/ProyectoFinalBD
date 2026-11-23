-- =====================================================================
-- 06_reportes_neon.sql  -  Microservicio: Reportes Corporativos (Neon)
-- Proyecto Neon: empresa-reportes
--
-- IMPORTANTE: Antes de ejecutar este script debes:
--   1. Haber creado y poblado los 5 proyectos Neon operativos.
--   2. Reemplazar los placeholders <<...>> con los datos reales
--      de cada proyecto Neon (host, usuario, password).
--
-- Formato de connection string de Neon:
--   postgresql://<USER>:<PASSWORD>@<HOST>/neondb?sslmode=require
--
-- Ejemplo de host: ep-cool-rain-123456.us-east-2.aws.neon.tech
-- =====================================================================

-- ---------- 1. Habilitar extensión postgres_fdw ----------
CREATE EXTENSION IF NOT EXISTS postgres_fdw;

-- ---------- 2. Servidores Foráneos hacia cada Microservicio ----------
-- ╔══════════════════════════════════════════════════════════════════╗
-- ║  REEMPLAZA los <<PLACEHOLDERS>> con tus datos reales de Neon   ║
-- ╚══════════════════════════════════════════════════════════════════╝

DROP SERVER IF EXISTS srv_catalogo CASCADE;
CREATE SERVER srv_catalogo
  FOREIGN DATA WRAPPER postgres_fdw
  OPTIONS (
    host      'ep-curly-bread-bbe54azd-pooler.c-15.us-east-1.aws.neon.tech',
    port      '5432',
    dbname    'neondb',
    sslmode   'require'
  );

DROP SERVER IF EXISTS srv_identidad CASCADE;
CREATE SERVER srv_identidad
  FOREIGN DATA WRAPPER postgres_fdw
  OPTIONS (
    host      'ep-green-tree-bb3tbj8o-pooler.c-15.us-east-1.aws.neon.tech',
    port      '5432',
    dbname    'neondb',
    sslmode   'require'
  );

DROP SERVER IF EXISTS srv_inventarios CASCADE;
CREATE SERVER srv_inventarios
  FOREIGN DATA WRAPPER postgres_fdw
  OPTIONS (
    host      'ep-still-dust-bbwkmya0-pooler.c-15.us-east-1.aws.neon.tech',
    port      '5432',
    dbname    'neondb',
    sslmode   'require'
  );

DROP SERVER IF EXISTS srv_compras CASCADE;
CREATE SERVER srv_compras
  FOREIGN DATA WRAPPER postgres_fdw
  OPTIONS (
    host      'ep-polished-voice-bb3emsqw-pooler.c-15.us-east-1.aws.neon.tech',
    port      '5432',
    dbname    'neondb',
    sslmode   'require'
  );

DROP SERVER IF EXISTS srv_ventas CASCADE;
CREATE SERVER srv_ventas
  FOREIGN DATA WRAPPER postgres_fdw
  OPTIONS (
    host      'ep-lively-grass-bbjw8p4l-pooler.c-15.us-east-1.aws.neon.tech',
    port      '5432',
    dbname    'neondb',
    sslmode   'require'
  );

-- ---------- 3. Mapeo de Usuarios ----------
-- En Neon, tu usuario owner es típicamente "neondb_owner".
-- Reemplaza <<USER_xxx>> y <<PASSWORD_xxx>> con las credenciales
-- del proyecto Neon de cada microservicio.

CREATE USER MAPPING FOR CURRENT_USER SERVER srv_catalogo
  OPTIONS (user 'neondb_owner', password '<<PASSWORD_CATALOGO>>');

CREATE USER MAPPING FOR CURRENT_USER SERVER srv_identidad
  OPTIONS (user 'neondb_owner', password '<<PASSWORD_IDENTIDAD>>');

CREATE USER MAPPING FOR CURRENT_USER SERVER srv_inventarios
  OPTIONS (user 'neondb_owner', password '<<PASSWORD_INVENTARIOS>>');

CREATE USER MAPPING FOR CURRENT_USER SERVER srv_compras
  OPTIONS (user 'neondb_owner', password '<<PASSWORD_COMPRAS>>');

CREATE USER MAPPING FOR CURRENT_USER SERVER srv_ventas
  OPTIONS (user 'neondb_owner', password '<<PASSWORD_VENTAS>>');

-- ---------- 4. Importar Esquemas Foráneos ----------
DROP SCHEMA IF EXISTS fdw_catalogo CASCADE;
CREATE SCHEMA fdw_catalogo;
IMPORT FOREIGN SCHEMA public FROM SERVER srv_catalogo INTO fdw_catalogo;

DROP SCHEMA IF EXISTS fdw_identidad CASCADE;
CREATE SCHEMA fdw_identidad;
IMPORT FOREIGN SCHEMA public FROM SERVER srv_identidad INTO fdw_identidad;

DROP SCHEMA IF EXISTS fdw_inventarios CASCADE;
CREATE SCHEMA fdw_inventarios;
IMPORT FOREIGN SCHEMA public FROM SERVER srv_inventarios INTO fdw_inventarios;

DROP SCHEMA IF EXISTS fdw_compras CASCADE;
CREATE SCHEMA fdw_compras;
IMPORT FOREIGN SCHEMA public FROM SERVER srv_compras INTO fdw_compras;

DROP SCHEMA IF EXISTS fdw_ventas CASCADE;
CREATE SCHEMA fdw_ventas;
IMPORT FOREIGN SCHEMA public FROM SERVER srv_ventas INTO fdw_ventas;

-- ---------- 5. Las 10 Vistas Analíticas Corporativas (V1 a V10) ----------

-- V1: Vista Inventario por Sede y Almacen
CREATE OR REPLACE VIEW vista_inventario_por_sede AS
SELECT
  s.id_sede,
  s.nombre AS sede_nombre,
  a.id_almacen,
  a.nombre AS almacen_nombre,
  p.id_producto,
  p.sku,
  p.nombre AS producto_nombre,
  c.nombre AS categoria_nombre,
  i.existencia_actual,
  i.stock_minimo,
  p.precio_lista,
  ROUND(i.existencia_actual * p.precio_lista, 2) AS valor_inventario
FROM fdw_inventarios.inventarios i
JOIN fdw_catalogo.sedes s ON s.id_sede = i.id_sede
JOIN fdw_catalogo.almacenes a ON a.id_almacen = i.id_almacen
JOIN fdw_catalogo.productos p ON p.id_producto = i.id_producto
JOIN fdw_catalogo.categorias c ON c.id_categoria = p.id_categoria;

-- V2: Vista Alertas de Reabastecimiento
CREATE OR REPLACE VIEW vista_alertas_reabastecimiento AS
SELECT
  id_sede,
  sede_nombre,
  id_almacen,
  almacen_nombre,
  id_producto,
  sku,
  producto_nombre,
  categoria_nombre,
  existencia_actual,
  stock_minimo,
  (stock_minimo - existencia_actual) AS unidades_faltantes,
  CASE
    WHEN existencia_actual = 0 THEN 'AGOTADO'
    ELSE 'CRITICO'
  END AS nivel_alerta
FROM vista_inventario_por_sede
WHERE existencia_actual = 0 OR existencia_actual < stock_minimo;

-- V3: Vista Productos sin Inventario
CREATE OR REPLACE VIEW vista_productos_sin_inventario AS
SELECT
  s.id_sede,
  s.nombre AS sede_nombre,
  p.id_producto,
  p.sku,
  p.nombre AS producto_nombre,
  c.nombre AS categoria_nombre
FROM fdw_catalogo.productos p
CROSS JOIN fdw_catalogo.sedes s
JOIN fdw_catalogo.categorias c ON c.id_categoria = p.id_categoria
WHERE p.estado = 'ACTIVO'
  AND NOT EXISTS (
    SELECT 1
    FROM fdw_inventarios.inventarios i
    WHERE i.id_sede = s.id_sede
      AND i.id_producto = p.id_producto
  );

-- V4: Vista Ventas Mensuales por Sede
CREATE OR REPLACE VIEW vista_ventas_mensuales_por_sede AS
SELECT
  s.id_sede,
  s.nombre AS sede_nombre,
  EXTRACT(YEAR FROM pv.fecha_pedido)::int AS anio,
  EXTRACT(MONTH FROM pv.fecha_pedido)::int AS mes,
  TO_CHAR(pv.fecha_pedido, 'YYYY-MM') AS periodo,
  COUNT(DISTINCT pv.id_pedido) AS total_pedidos,
  SUM(dp.cantidad) AS unidades_vendidas,
  ROUND(SUM(dp.cantidad * dp.precio_unitario), 2) AS total_vendido
FROM fdw_ventas.pedidos_venta pv
JOIN fdw_catalogo.sedes s ON s.id_sede = pv.id_sede
JOIN fdw_ventas.detalle_pedido dp ON dp.id_sede = pv.id_sede AND dp.id_pedido = pv.id_pedido
WHERE pv.estado IN ('CONFIRMADO', 'DESPACHADO', 'ENTREGADO')
GROUP BY s.id_sede, s.nombre, EXTRACT(YEAR FROM pv.fecha_pedido), EXTRACT(MONTH FROM pv.fecha_pedido), TO_CHAR(pv.fecha_pedido, 'YYYY-MM');

-- V5: Vista Pedidos Pendientes
CREATE OR REPLACE VIEW vista_pedidos_pendientes AS
SELECT
  pv.id_sede,
  s.nombre AS sede_nombre,
  pv.id_pedido,
  pv.id_almacen,
  a.nombre AS almacen_nombre,
  pv.id_cliente,
  c.nombre_completo AS cliente_nombre,
  pv.id_empleado,
  e.nombre_completo AS vendedor_nombre,
  pv.fecha_pedido,
  pv.estado,
  pv.total_registrado
FROM fdw_ventas.pedidos_venta pv
JOIN fdw_catalogo.sedes s ON s.id_sede = pv.id_sede
JOIN fdw_catalogo.almacenes a ON a.id_almacen = pv.id_almacen
JOIN fdw_catalogo.clientes c ON c.id_cliente = pv.id_cliente
JOIN fdw_identidad.empleados e ON e.id_empleado = pv.id_empleado
WHERE pv.estado IN ('PENDIENTE', 'CONFIRMADO');

-- V6: Vista Saldos Pendientes
CREATE OR REPLACE VIEW vista_saldos_pendientes AS
WITH pagos_conf AS (
  SELECT id_sede, id_pedido, SUM(valor) AS total_pagado
  FROM fdw_ventas.pagos
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
FROM fdw_ventas.pedidos_venta pv
LEFT JOIN pagos_conf pc ON pc.id_sede = pv.id_sede AND pc.id_pedido = pv.id_pedido
WHERE pv.estado NOT IN ('ANULADO')
  AND (pv.total_registrado - COALESCE(pc.total_pagado, 0.00)) > 0;

-- V7: Vista Compras Pendientes
CREATE OR REPLACE VIEW vista_compras_pendientes AS
WITH recepciones_acum AS (
  SELECT
    r.id_orden_compra,
    dr.id_producto,
    SUM(dr.cantidad_recibida) AS total_recibido
  FROM fdw_compras.recepciones_compra r
  JOIN fdw_compras.detalle_recepcion dr ON dr.id_recepcion = r.id_recepcion
  GROUP BY r.id_orden_compra, dr.id_producto
)
SELECT
  oc.id_orden_compra,
  oc.id_proveedor,
  pr.razon_social AS proveedor_nombre,
  oc.id_almacen_destino,
  a.nombre AS almacen_destino,
  oc.fecha_orden,
  oc.fecha_estimada,
  oc.estado AS estado_orden,
  doc.id_producto,
  p.nombre AS producto_nombre,
  doc.cantidad_solicitada,
  COALESCE(ra.total_recibido, 0) AS cantidad_recibida,
  (doc.cantidad_solicitada - COALESCE(ra.total_recibido, 0)) AS cantidad_pendiente
FROM fdw_compras.ordenes_compra oc
JOIN fdw_compras.detalle_orden_compra doc ON doc.id_orden_compra = oc.id_orden_compra
JOIN fdw_catalogo.proveedores pr ON pr.id_proveedor = oc.id_proveedor
JOIN fdw_catalogo.almacenes a ON a.id_almacen = oc.id_almacen_destino
JOIN fdw_catalogo.productos p ON p.id_producto = doc.id_producto
LEFT JOIN recepciones_acum ra ON ra.id_orden_compra = oc.id_orden_compra AND ra.id_producto = doc.id_producto
WHERE oc.estado IN ('EMITIDA', 'PARCIAL')
  AND (doc.cantidad_solicitada - COALESCE(ra.total_recibido, 0)) > 0;

-- V8: Vista Transferencias en Transito
CREATE OR REPLACE VIEW vista_transferencias_en_transito AS
SELECT
  t.id_transferencia,
  t.id_almacen_origen,
  ao.nombre AS almacen_origen,
  so.nombre AS sede_origen,
  t.id_almacen_destino,
  ad.nombre AS almacen_destino,
  sd.nombre AS sede_destino,
  t.fecha_solicitud,
  t.fecha_despacho,
  dt.id_producto,
  p.sku,
  p.nombre AS producto_nombre,
  dt.cantidad_enviada,
  (DATE '2026-10-31' - t.fecha_despacho) AS dias_en_transito
FROM fdw_inventarios.transferencias t
JOIN fdw_inventarios.detalle_transferencia dt ON dt.id_transferencia = t.id_transferencia
JOIN fdw_catalogo.almacenes ao ON ao.id_almacen = t.id_almacen_origen
JOIN fdw_catalogo.sedes so ON so.id_sede = ao.id_sede
JOIN fdw_catalogo.almacenes ad ON ad.id_almacen = t.id_almacen_destino
JOIN fdw_catalogo.sedes sd ON sd.id_sede = ad.id_sede
JOIN fdw_catalogo.productos p ON p.id_producto = dt.id_producto
WHERE t.estado = 'DESPACHADA'
  AND t.fecha_recepcion IS NULL;

-- V9: Vista Devoluciones por Producto
CREATE OR REPLACE VIEW vista_devoluciones_por_producto AS
SELECT
  p.id_producto,
  p.sku,
  p.nombre AS producto_nombre,
  c.nombre AS categoria_nombre,
  COUNT(DISTINCT d.id_devolucion) AS total_casos,
  SUM(dd.cantidad) AS unidades_devueltas,
  COUNT(*) FILTER (WHERE dd.condicion_producto = 'AVERIADO') AS casos_averiado,
  COUNT(*) FILTER (WHERE dd.condicion_producto = 'NUEVO') AS casos_nuevo
FROM fdw_ventas.devoluciones d
JOIN fdw_ventas.detalle_devolucion dd ON dd.id_devolucion = d.id_devolucion
JOIN fdw_catalogo.productos p ON p.id_producto = dd.id_producto
JOIN fdw_catalogo.categorias c ON c.id_categoria = p.id_categoria
GROUP BY p.id_producto, p.sku, p.nombre, c.nombre;

-- V10: Vista Reporte Corporativo
CREATE OR REPLACE VIEW vista_reporte_corporativo AS
WITH inv_sede AS (
  SELECT
    id_sede,
    COUNT(DISTINCT i.id_producto) FILTER (WHERE p.estado = 'ACTIVO') AS productos_activos,
    SUM(i.existencia_actual) AS stock_total_unidades
  FROM fdw_inventarios.inventarios i
  JOIN fdw_catalogo.productos p ON p.id_producto = i.id_producto
  GROUP BY i.id_sede
),
ven_sede AS (
  SELECT
    id_sede,
    COUNT(DISTINCT id_pedido) AS pedidos_confirmados,
    COALESCE(SUM(total_registrado), 0.00) AS total_facturado
  FROM fdw_ventas.pedidos_venta
  WHERE estado IN ('CONFIRMADO', 'DESPACHADO', 'ENTREGADO')
  GROUP BY id_sede
),
ped_pend AS (
  SELECT
    id_sede,
    COUNT(*) AS pedidos_pendientes
  FROM fdw_ventas.pedidos_venta
  WHERE estado IN ('PENDIENTE', 'CONFIRMADO')
  GROUP BY id_sede
),
com_sede AS (
  SELECT
    a.id_sede,
    COUNT(DISTINCT oc.id_orden_compra) AS total_compras
  FROM fdw_compras.ordenes_compra oc
  JOIN fdw_catalogo.almacenes a ON a.id_almacen = oc.id_almacen_destino
  GROUP BY a.id_sede
),
tra_sede AS (
  SELECT
    a.id_sede,
    COUNT(DISTINCT t.id_transferencia) AS total_transferencias
  FROM fdw_inventarios.transferencias t
  JOIN fdw_catalogo.almacenes a ON a.id_almacen = t.id_almacen_origen
  GROUP BY a.id_sede
),
pag_sede AS (
  SELECT
    id_sede,
    COUNT(*) AS total_pagos_recibidos,
    COALESCE(SUM(valor), 0.00) AS total_recaudado
  FROM fdw_ventas.pagos
  WHERE estado = 'CONFIRMADO'
  GROUP BY id_sede
),
dev_sede AS (
  SELECT
    id_sede,
    COUNT(*) AS casos_devolucion
  FROM fdw_ventas.devoluciones
  GROUP BY id_sede
)
SELECT
  s.id_sede,
  s.nombre AS sede_nombre,
  s.ciudad,
  s.tipo_sede,
  COALESCE(inv.productos_activos, 0) AS productos_activos,
  COALESCE(inv.stock_total_unidades, 0) AS stock_total_unidades,
  COALESCE(ven.pedidos_confirmados, 0) AS pedidos_confirmados,
  COALESCE(ven.total_facturado, 0.00) AS total_facturado,
  COALESCE(ped.pedidos_pendientes, 0) AS pedidos_pendientes,
  COALESCE(com.total_compras, 0) AS total_compras,
  COALESCE(tra.total_transferencias, 0) AS total_transferencias,
  COALESCE(pag.total_recaudado, 0.00) AS total_recaudado,
  ROUND((COALESCE(ven.total_facturado, 0.00) - COALESCE(pag.total_recaudado, 0.00))::numeric, 2) AS cartera_pendiente,
  COALESCE(dev.casos_devolucion, 0) AS casos_devolucion
FROM fdw_catalogo.sedes s
LEFT JOIN inv_sede inv ON inv.id_sede = s.id_sede
LEFT JOIN ven_sede ven ON ven.id_sede = s.id_sede
LEFT JOIN ped_pend ped ON ped.id_sede = s.id_sede
LEFT JOIN com_sede com ON com.id_sede = s.id_sede
LEFT JOIN tra_sede tra ON tra.id_sede = s.id_sede
LEFT JOIN pag_sede pag ON pag.id_sede = s.id_sede
LEFT JOIN dev_sede dev ON dev.id_sede = s.id_sede;

-- ---------- Comentarios de procedencia ----------
COMMENT ON VIEW vista_inventario_por_sede IS 'Fuentes: inventarios + catalogo (sedes, almacenes, productos, categorias)';
COMMENT ON VIEW vista_alertas_reabastecimiento IS 'Fuentes: vista_inventario_por_sede';
COMMENT ON VIEW vista_productos_sin_inventario IS 'Fuentes: catalogo (productos, sedes, categorias) + inventarios';
COMMENT ON VIEW vista_ventas_mensuales_por_sede IS 'Fuentes: ventas (pedidos_venta, detalle_pedido) + catalogo (sedes)';
COMMENT ON VIEW vista_pedidos_pendientes IS 'Fuentes: ventas + catalogo (sedes, almacenes, clientes) + identidad (empleados)';
COMMENT ON VIEW vista_saldos_pendientes IS 'Fuentes: ventas (pedidos_venta, pagos)';
COMMENT ON VIEW vista_compras_pendientes IS 'Fuentes: compras + catalogo (proveedores, almacenes, productos)';
COMMENT ON VIEW vista_transferencias_en_transito IS 'Fuentes: inventarios (transferencias) + catalogo (almacenes, sedes, productos)';
COMMENT ON VIEW vista_devoluciones_por_producto IS 'Fuentes: ventas (devoluciones) + catalogo (productos, categorias)';
COMMENT ON VIEW vista_reporte_corporativo IS 'Fuentes: catalogo + inventarios + ventas + compras';


-- ---------- 6. Permisos en empresa_reportes ----------
GRANT USAGE ON SCHEMA public, fdw_catalogo, fdw_identidad, fdw_inventarios, fdw_compras, fdw_ventas
  TO r_gerencia, r_auditor, r_administrador;
GRANT CREATE ON SCHEMA public TO r_administrador;

-- Tablas foráneas y vistas: lectura para roles de consulta
GRANT SELECT ON ALL TABLES IN SCHEMA public, fdw_catalogo, fdw_inventarios, fdw_compras, fdw_ventas
  TO r_gerencia, r_auditor, r_administrador;

-- En fdw_identidad: consulta de empleados y accesos; se excluye password_hash
GRANT SELECT ON fdw_identidad.empleados, fdw_identidad.auditoria_accesos TO r_gerencia, r_auditor;
GRANT SELECT (id_usuario, id_empleado, nombre_usuario, rol, estado, fecha_creacion)
  ON fdw_identidad.usuarios TO r_gerencia, r_auditor;
