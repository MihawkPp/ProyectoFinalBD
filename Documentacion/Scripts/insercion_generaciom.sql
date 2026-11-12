
-- 1. CATALOGO

INSERT INTO catalogo.sedes (id_sede, nombre, ciudad, direccion, tipo_sede) VALUES
(1, 'Centro de Distribucion', 'Bogota', 'Zona Industrial',     'Distribucion'),
(2, 'Sede Norte',             'Bogota', 'Calle ejemplar 100',  'Venta'),
(3, 'Sede Sur',               'Bogota', 'Avenida ejemplar 50', 'Venta'),
(4, 'Sede Centro',            'Bogota', 'Carrera ejemplar 20', 'Venta');

-- Un almacen por sede. El id del almacen es igual al id de su sede.
INSERT INTO catalogo.almacenes (id_almacen, id_sede, nombre, tipo_almacen) VALUES
(1, 1, 'Bodega central',    'Bodega'),
(2, 2, 'Almacen principal', 'Principal'),
(3, 3, 'Almacen principal', 'Principal'),
(4, 4, 'Almacen principal', 'Principal');

INSERT INTO catalogo.categorias (id_categoria, nombre, descripcion) VALUES
(1, 'Tecnologia', 'Equipos y accesorios tecnologicos'),
(2, 'Papeleria',  'Productos de oficina y estudio'),
(3, 'Hogar',      'Articulos para el hogar'),
(4, 'Deportes',   'Implementos deportivos'),
(5, 'Accesorios', 'Accesorios de uso general');

-- 80 productos
INSERT INTO catalogo.productos (id_producto, sku, nombre, id_categoria, unidad_medida, precio_lista, estado)
SELECT g AS id_producto,
       ('SKU-' || LPAD(g::text, 4, '0')) AS sku,
       ('Producto ' || g) AS nombre,
       ((g % 5) + 1) AS id_categoria,
       'Unidad' AS unidad_medida,
       (10000 + g * 2500) AS precio_lista,
       CASE WHEN g <= 76 THEN 'Activo' ELSE 'Inactivo' END AS estado
FROM generate_series(1, 80) AS g;

INSERT INTO catalogo.proveedores (id_proveedor, identificacion, razon_social, ciudad, correo, telefono)
SELECT g AS id_proveedor,
       ('900' || LPAD(g::text, 6, '0')) AS identificacion,
       ('Proveedor ' || g) AS razon_social,
       CASE WHEN g % 2 = 0 THEN 'Bogota' ELSE 'Medellin' END AS ciudad,
       ('proveedor' || g || '@ejemplo.com') AS correo,
       ('300' || LPAD(g::text, 7, '0')) AS telefono
FROM generate_series(1, 10) AS g;

INSERT INTO catalogo.producto_proveedor (id_producto, id_proveedor, costo_referencia, plazo_entrega_dias)
SELECT p.id_producto AS id_producto,
       (((p.id_producto - 1) % 10) + 1) AS id_proveedor,
       ROUND(p.precio_lista * 0.70, 2) AS costo_referencia,
       (5 + (p.id_producto % 10)) AS plazo_entrega_dias
FROM catalogo.productos p;

INSERT INTO catalogo.clientes (id_cliente, tipo_documento, num_documento, nombre_completo, correo, telefono)
SELECT g AS id_cliente,
       CASE WHEN g % 3 = 0 THEN 'CE' ELSE 'CC' END AS tipo_documento,
       ((1000000 + g)::text) AS num_documento,
       ('Cliente ' || g) AS nombre_completo,
       ('cliente' || g || '@ejemplo.com') AS correo,
       ('310' || LPAD(g::text, 7, '0')) AS telefono
FROM generate_series(1, 100) AS g;


-- 2. IDENTIDAD

INSERT INTO identidad.empleados (id_empleado, id_sede, num_documento, nombre_completo, cargo, correo) VALUES
(1,  1, '7900000001', 'Empleado 1',  'Administrador', 'empleado1@ejemplo.com'),
(2,  1, '7900000002', 'Empleado 2',  'Gerencia',      'empleado2@ejemplo.com'),
(3,  1, '7900000003', 'Empleado 3',  'Auditor',       'empleado3@ejemplo.com'),
(4,  1, '7900000004', 'Empleado 4',  'Inventario',    'empleado4@ejemplo.com'),
(5,  1, '7900000005', 'Empleado 5',  'Compras',       'empleado5@ejemplo.com'),
(6,  2, '7900000006', 'Empleado 6',  'Vendedor',      'empleado6@ejemplo.com'),
(7,  2, '7900000007', 'Empleado 7',  'Vendedor',      'empleado7@ejemplo.com'),
(8,  2, '7900000008', 'Empleado 8',  'Vendedor',      'empleado8@ejemplo.com'),
(9,  2, '7900000009', 'Empleado 9',  'Inventario',    'empleado9@ejemplo.com'),
(10, 2, '7900000010', 'Empleado 10', 'Compras',       'empleado10@ejemplo.com'),
(11, 3, '7900000011', 'Empleado 11', 'Vendedor',      'empleado11@ejemplo.com'),
(12, 3, '7900000012', 'Empleado 12', 'Vendedor',      'empleado12@ejemplo.com'),
(13, 3, '7900000013', 'Empleado 13', 'Vendedor',      'empleado13@ejemplo.com'),
(14, 3, '7900000014', 'Empleado 14', 'Inventario',    'empleado14@ejemplo.com'),
(15, 3, '7900000015', 'Empleado 15', 'Compras',       'empleado15@ejemplo.com'),
(16, 4, '7900000016', 'Empleado 16', 'Vendedor',      'empleado16@ejemplo.com'),
(17, 4, '7900000017', 'Empleado 17', 'Vendedor',      'empleado17@ejemplo.com'),
(18, 4, '7900000018', 'Empleado 18', 'Vendedor',      'empleado18@ejemplo.com'),
(19, 4, '7900000019', 'Empleado 19', 'Inventario',    'empleado19@ejemplo.com'),
(20, 4, '7900000020', 'Empleado 20', 'Compras',       'empleado20@ejemplo.com');

INSERT INTO identidad.usuarios (id_usuario, id_empleado, nombre_usuario, password_hash, rol)
SELECT e.id_empleado AS id_usuario,
       e.id_empleado AS id_empleado,
       ('usuario' || e.id_empleado) AS nombre_usuario,
       MD5('pass_' || e.id_empleado) AS password_hash,
       e.cargo AS rol
FROM identidad.empleados e;

INSERT INTO identidad.auditoria_accesos (id_auditoria, id_usuario, fecha_hora, accion, objeto_consultado)
SELECT g AS id_auditoria,
       (((g % 20) + 1)) AS id_usuario,
       (NOW() - (g * INTERVAL '2 hours')) AS fecha_hora,
       CASE g % 3 WHEN 0 THEN 'SELECT' WHEN 1 THEN 'INSERT' ELSE 'UPDATE' END AS accion,
       CASE WHEN g % 2 = 0 THEN 'ventas.pedidos_venta' ELSE 'inventarios.inventarios' END AS objeto_consultado
FROM generate_series(1, 40) AS g;


-- 3. INVENTARIOS
INSERT INTO inventarios.inventarios (id_sede, id_almacen, id_producto, existencia_actual, stock_minimo)
SELECT a.id_sede AS id_sede,
       a.id_almacen AS id_almacen,
       p.id_producto AS id_producto,
       CASE WHEN (p.id_producto + a.id_almacen) % 10 = 0 THEN 0
            WHEN (p.id_producto + a.id_almacen) % 7 = 0 THEN 2
            ELSE 10 + ((p.id_producto * a.id_almacen) % 50) END AS existencia_actual,
       10 AS stock_minimo
FROM catalogo.almacenes a
CROSS JOIN catalogo.productos p
WHERE NOT (p.id_producto > 70 AND a.id_sede = 2);


-- 4. COMPRAS
INSERT INTO compras.ordenes_compra (id_orden_compra, id_proveedor, id_almacen_destino, id_empleado, fecha_orden, fecha_estimada, estado)
SELECT g AS id_orden_compra,
       (((g - 1) % 10) + 1) AS id_proveedor,
       1 AS id_almacen_destino,
       5 AS id_empleado,
       (CURRENT_DATE - (g * 2) - 15) AS fecha_orden,
       (CURRENT_DATE - (g * 2) - 5) AS fecha_estimada,
       CASE WHEN g % 10 = 0 THEN 'Pendiente'
            WHEN g % 10 = 5 THEN 'En Camino'
            ELSE 'Recibido' END AS estado
FROM generate_series(1, 60) AS g;

INSERT INTO compras.detalle_orden_compra (id_orden_compra, id_producto, cantidad_solicitada, costo_unitario)
SELECT oc.id_orden_compra AS id_orden_compra,
       p.id_producto AS id_producto,
       (10 * (n + 1)) AS cantidad_solicitada,
       ROUND(p.precio_lista * 0.70, 2) AS costo_unitario
FROM compras.ordenes_compra oc
CROSS JOIN generate_series(0, 2) AS n
JOIN catalogo.productos p ON p.id_producto = oc.id_proveedor + 10 * n;

INSERT INTO compras.recepciones_compra (id_recepcion, id_orden_compra, fecha_recepcion, estado)
SELECT oc.id_orden_compra AS id_recepcion,
       oc.id_orden_compra AS id_orden_compra,
       CASE WHEN oc.estado = 'En Camino'           THEN (oc.fecha_orden::date + 4)
            WHEN oc.id_orden_compra % 4 = 0        THEN (oc.fecha_estimada + 3)
            ELSE (oc.fecha_estimada - 2) END AS fecha_recepcion,
       CASE WHEN oc.estado = 'En Camino' THEN 'Parcialmente' ELSE 'Total' END AS estado
FROM compras.ordenes_compra oc
WHERE oc.estado IN ('En Camino', 'Recibido');

INSERT INTO compras.detalle_recepcion (id_recepcion, id_producto, cantidad_recibida)
SELECT r.id_recepcion AS id_recepcion,
       d.id_producto AS id_producto,
       CASE WHEN r.estado = 'Parcialmente' THEN (d.cantidad_solicitada / 2)
            ELSE d.cantidad_solicitada END AS cantidad_recibida
FROM compras.recepciones_compra r
JOIN compras.detalle_orden_compra d ON d.id_orden_compra = r.id_orden_compra;


-- 5. VENTAS
INSERT INTO ventas.pedidos_venta (id_pedido, id_sede, id_almacen, id_cliente, id_empleado, fecha_pedido, estado)
SELECT s.g AS id_pedido,
       s.id_sede AS id_sede,
       s.id_sede AS id_almacen,
       ((s.g % 100) + 1) AS id_cliente,
       (((s.id_sede - 1) * 5) + 1 + (s.g % 3)) AS id_empleado,
       (CURRENT_DATE - (s.g % 118) - 2) AS fecha_pedido,
       CASE WHEN s.g % 13 = 0 THEN 'Cancelado'
            WHEN s.g % 4 = 0  THEN 'Pendiente'
            ELSE 'Completado' END AS estado
FROM (SELECT g, ((g % 3) + 2) AS id_sede FROM generate_series(1, 300) AS g) AS s;

INSERT INTO ventas.detalle_pedido (id_sede, id_pedido, id_producto, cantidad, precio_unitario)
SELECT pv.id_sede AS id_sede,
       pv.id_pedido AS id_pedido,
       p.id_producto AS id_producto,
       ((pv.id_pedido % 5) + 1) AS cantidad,
       p.precio_lista AS precio_unitario
FROM ventas.pedidos_venta pv
CROSS JOIN generate_series(0, 2) AS n
JOIN catalogo.productos p ON p.id_producto = ((pv.id_pedido % 58) + 1 + n)
WHERE n < 2 OR pv.id_pedido % 2 = 0;

UPDATE ventas.pedidos_venta pv
SET total_registrado = (SELECT SUM(d.cantidad * d.precio_unitario)
                        FROM ventas.detalle_pedido d
                        WHERE d.id_sede = pv.id_sede
                          AND d.id_pedido = pv.id_pedido);

INSERT INTO ventas.pagos (id_pago, id_sede, id_pedido, fecha_pago, valor, medio_pago, estado)
SELECT pv.id_pedido AS id_pago,
       pv.id_sede AS id_sede,
       pv.id_pedido AS id_pedido,
       (pv.fecha_pedido::date + 1) AS fecha_pago,
       CASE WHEN pv.id_pedido % 3 = 0 THEN ROUND(pv.total_registrado * 0.60, 2)
            ELSE pv.total_registrado END AS valor,
       CASE pv.id_pedido % 3 WHEN 0 THEN 'Transferencia'
                             WHEN 1 THEN 'Efectivo'
                             ELSE 'Tarjeta Credito' END AS medio_pago,
       'Confirmado' AS estado
FROM ventas.pedidos_venta pv
WHERE pv.estado = 'Completado';

INSERT INTO ventas.pagos (id_pago, id_sede, id_pedido, fecha_pago, valor, medio_pago, estado)
SELECT (pv.id_pedido + 1000) AS id_pago,
       pv.id_sede AS id_sede,
       pv.id_pedido AS id_pedido,
       (pv.fecha_pedido::date + 2) AS fecha_pago,
       (pv.total_registrado - ROUND(pv.total_registrado * 0.60, 2)) AS valor,
       'Transferencia' AS medio_pago,
       'Confirmado' AS estado
FROM ventas.pedidos_venta pv
WHERE pv.estado = 'Completado' AND pv.id_pedido % 3 = 0;

INSERT INTO ventas.pagos (id_pago, id_sede, id_pedido, fecha_pago, valor, medio_pago, estado)
SELECT pv.id_pedido AS id_pago,
       pv.id_sede AS id_sede,
       pv.id_pedido AS id_pedido,
       (pv.fecha_pedido::date + 1) AS fecha_pago,
       ROUND(pv.total_registrado * 0.40, 2) AS valor,
       'Efectivo' AS medio_pago,
       'Confirmado' AS estado
FROM ventas.pedidos_venta pv
WHERE pv.estado = 'Pendiente' AND pv.id_pedido % 8 = 0;


-- 6. TRANSFERENCIAS
INSERT INTO inventarios.transferencias (id_transferencia, id_almacen_origen, id_almacen_destino, fecha_solicitud, fecha_despacho, fecha_recepcion, estado)
SELECT t.g AS id_transferencia,
       1 AS id_almacen_origen,
       t.id_almacen_destino AS id_almacen_destino,
       (CURRENT_DATE - (t.g * 3)) AS fecha_solicitud,
       CASE WHEN t.estado IN ('En Transito', 'Completado') THEN (CURRENT_DATE - (t.g * 3) + 1) END AS fecha_despacho,
       CASE WHEN t.estado = 'Completado'                   THEN (CURRENT_DATE - (t.g * 3) + 3) END AS fecha_recepcion,
       t.estado AS estado
FROM (SELECT g,
             (((g % 3) + 2)) AS id_almacen_destino,
             CASE WHEN g % 5 = 0 THEN 'En Transito'
                  WHEN g % 7 = 0 THEN 'Solicitado'
                  ELSE 'Completado' END AS estado
      FROM generate_series(1, 25) AS g) AS t;

INSERT INTO inventarios.detalle_transferencia (id_transferencia, id_producto, cantidad_enviada, cantidad_recibida)
SELECT t.id_transferencia AS id_transferencia,
       ((t.id_transferencia * 3) + n) AS id_producto,
       10 AS cantidad_enviada,
       CASE WHEN t.estado <> 'Completado'       THEN NULL
            WHEN t.id_transferencia % 4 = 0     THEN 8
            ELSE 10 END AS cantidad_recibida
FROM inventarios.transferencias t
CROSS JOIN generate_series(1, 2) AS n;


-- 7. DEVOLUCIONES
INSERT INTO ventas.devoluciones (id_devolucion, id_sede, id_pedido, fecha_solicitud, motivo, estado)
SELECT pv.id_pedido AS id_devolucion,
       pv.id_sede AS id_sede,
       pv.id_pedido AS id_pedido,
       (pv.fecha_pedido::date + 5) AS fecha_solicitud,
       CASE WHEN pv.id_pedido % 2 = 0 THEN 'Producto defectuoso' ELSE 'Cambio de opinion' END AS motivo,
       CASE pv.id_pedido % 3 WHEN 0 THEN 'Solicitado' WHEN 1 THEN 'Aprobado' ELSE 'Procesado' END AS estado
FROM ventas.pedidos_venta pv
WHERE pv.estado = 'Completado'
  AND pv.fecha_pedido <= CURRENT_DATE - 10
ORDER BY pv.id_pedido
LIMIT 20;

INSERT INTO ventas.detalle_devolucion (id_devolucion, id_producto, cantidad, condicion_producto)
SELECT d.id_devolucion AS id_devolucion,
       dp.id_producto AS id_producto,
       1 AS cantidad,
       CASE WHEN d.id_devolucion % 2 = 0 THEN 'Defectuoso' ELSE 'Nuevo' END AS condicion_producto
FROM ventas.devoluciones d
JOIN ventas.detalle_pedido dp
  ON dp.id_sede = d.id_sede AND dp.id_pedido = d.id_pedido
WHERE dp.id_producto = (SELECT MIN(x.id_producto)
                        FROM ventas.detalle_pedido x
                        WHERE x.id_sede = d.id_sede AND x.id_pedido = d.id_pedido);



-- 8. AJUSTAR LAS SECUENCIAS
SELECT setval(pg_get_serial_sequence('catalogo.almacenes', 'id_almacen'),          (SELECT MAX(id_almacen) FROM catalogo.almacenes));
SELECT setval(pg_get_serial_sequence('catalogo.categorias', 'id_categoria'),       (SELECT MAX(id_categoria) FROM catalogo.categorias));
SELECT setval(pg_get_serial_sequence('catalogo.productos', 'id_producto'),         (SELECT MAX(id_producto) FROM catalogo.productos));
SELECT setval(pg_get_serial_sequence('catalogo.proveedores', 'id_proveedor'),      (SELECT MAX(id_proveedor) FROM catalogo.proveedores));
SELECT setval(pg_get_serial_sequence('catalogo.clientes', 'id_cliente'),           (SELECT MAX(id_cliente) FROM catalogo.clientes));
SELECT setval(pg_get_serial_sequence('identidad.empleados', 'id_empleado'),        (SELECT MAX(id_empleado) FROM identidad.empleados));
SELECT setval(pg_get_serial_sequence('identidad.usuarios', 'id_usuario'),          (SELECT MAX(id_usuario) FROM identidad.usuarios));
SELECT setval(pg_get_serial_sequence('identidad.auditoria_accesos', 'id_auditoria'), (SELECT MAX(id_auditoria) FROM identidad.auditoria_accesos));
SELECT setval(pg_get_serial_sequence('compras.ordenes_compra', 'id_orden_compra'), (SELECT MAX(id_orden_compra) FROM compras.ordenes_compra));
SELECT setval(pg_get_serial_sequence('compras.recepciones_compra', 'id_recepcion'), (SELECT MAX(id_recepcion) FROM compras.recepciones_compra));
SELECT setval(pg_get_serial_sequence('inventarios.transferencias', 'id_transferencia'), (SELECT MAX(id_transferencia) FROM inventarios.transferencias));
SELECT setval(pg_get_serial_sequence('ventas.pedidos_venta', 'id_pedido'),         (SELECT MAX(id_pedido) FROM ventas.pedidos_venta));
SELECT setval(pg_get_serial_sequence('ventas.pagos', 'id_pago'),                   (SELECT MAX(id_pago) FROM ventas.pagos));
SELECT setval(pg_get_serial_sequence('ventas.devoluciones', 'id_devolucion'),      (SELECT MAX(id_devolucion) FROM ventas.devoluciones));


-- 9. VERIFICACION
SELECT 'Sedes' AS tabla, COUNT(*) AS filas FROM catalogo.sedes
UNION ALL SELECT 'Almacenes',      COUNT(*) FROM catalogo.almacenes
UNION ALL SELECT 'Categorias',     COUNT(*) FROM catalogo.categorias
UNION ALL SELECT 'Productos',      COUNT(*) FROM catalogo.productos
UNION ALL SELECT 'Proveedores',    COUNT(*) FROM catalogo.proveedores
UNION ALL SELECT 'Clientes',       COUNT(*) FROM catalogo.clientes
UNION ALL SELECT 'Empleados',      COUNT(*) FROM identidad.empleados
UNION ALL SELECT 'Inventarios',    COUNT(*) FROM inventarios.inventarios
UNION ALL SELECT 'Pedidos',        COUNT(*) FROM ventas.pedidos_venta
UNION ALL SELECT 'Detalle pedido', COUNT(*) FROM ventas.detalle_pedido
UNION ALL SELECT 'Pagos',          COUNT(*) FROM ventas.pagos
UNION ALL SELECT 'Ordenes compra', COUNT(*) FROM compras.ordenes_compra
UNION ALL SELECT 'Recepciones',    COUNT(*) FROM compras.recepciones_compra
UNION ALL SELECT 'Transferencias', COUNT(*) FROM inventarios.transferencias
UNION ALL SELECT 'Devoluciones',   COUNT(*) FROM ventas.devoluciones;

-- pedidos con saldo por pagar 
SELECT pv.id_pedido, pv.estado, pv.total_registrado,
       COALESCE(SUM(p.valor), 0) AS pagado,
       pv.total_registrado - COALESCE(SUM(p.valor), 0) AS saldo
FROM ventas.pedidos_venta pv
LEFT JOIN ventas.pagos p
       ON p.id_sede = pv.id_sede AND p.id_pedido = pv.id_pedido AND p.estado = 'Confirmado'
WHERE pv.estado <> 'Cancelado'
GROUP BY pv.id_pedido, pv.estado, pv.total_registrado
HAVING pv.total_registrado > COALESCE(SUM(p.valor), 0)
ORDER BY pv.id_pedido
LIMIT 15;

-- productos por debajo del stock minimo.
SELECT id_sede, id_almacen, id_producto, existencia_actual, stock_minimo
FROM inventarios.inventarios
WHERE existencia_actual < stock_minimo
ORDER BY id_sede, id_producto
LIMIT 15;

-- transferencias aun en transito.
SELECT id_transferencia, id_almacen_origen, id_almacen_destino, fecha_despacho
FROM inventarios.transferencias
WHERE estado = 'En Transito';

-- clientes que compraron en mas de una sede.
SELECT id_cliente, COUNT(DISTINCT id_sede) AS sedes
FROM ventas.pedidos_venta
WHERE estado <> 'Cancelado'
GROUP BY id_cliente
HAVING COUNT(DISTINCT id_sede) >= 2
ORDER BY id_cliente
LIMIT 15;

