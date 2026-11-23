-- =====================================================================
-- 08_pruebas_neon.sql  -  Pruebas de Verificacion (§11)
--
-- A diferencia del entorno local, en Neon cada proyecto es independiente
-- y NO se puede usar \c para cambiar de base. Por eso las pruebas estan
-- separadas por PROYECTO. Ejecuta cada bloque en el SQL Editor del
-- proyecto indicado en su encabezado.
-- =====================================================================


-- #####################################################################
-- BLOQUE A  →  Ejecutar en el proyecto  empresa-reportes
-- (conteos, integridad inter-base y anti fan-out, via FDW)
-- #####################################################################

-- A1. Conteo de entidades distribuidas (prueba 5 y 6: fragmentos reunidos)
SELECT 'catalogo.sedes' AS tabla, count(*) AS filas FROM fdw_catalogo.sedes
UNION ALL SELECT 'catalogo.almacenes', count(*) FROM fdw_catalogo.almacenes
UNION ALL SELECT 'catalogo.productos', count(*) FROM fdw_catalogo.productos
UNION ALL SELECT 'catalogo.proveedores', count(*) FROM fdw_catalogo.proveedores
UNION ALL SELECT 'catalogo.clientes', count(*) FROM fdw_catalogo.clientes
UNION ALL SELECT 'identidad.empleados', count(*) FROM fdw_identidad.empleados
UNION ALL SELECT 'inventarios.inventarios', count(*) FROM fdw_inventarios.inventarios
UNION ALL SELECT 'inventarios.transferencias', count(*) FROM fdw_inventarios.transferencias
UNION ALL SELECT 'compras.ordenes_compra', count(*) FROM fdw_compras.ordenes_compra
UNION ALL SELECT 'ventas.pedidos_venta', count(*) FROM fdw_ventas.pedidos_venta
UNION ALL SELECT 'ventas.pagos', count(*) FROM fdw_ventas.pagos
UNION ALL SELECT 'ventas.devoluciones', count(*) FROM fdw_ventas.devoluciones;

-- A2. Integridad logica inter-base (las 4 consultas deben devolver 0 filas)
-- Empleados con sede inexistente
SELECT e.id_empleado, e.id_sede FROM fdw_identidad.empleados e
WHERE NOT EXISTS (SELECT 1 FROM fdw_catalogo.sedes s WHERE s.id_sede = e.id_sede);
-- Ordenes con proveedor o almacen inexistente
SELECT o.id_orden_compra FROM fdw_compras.ordenes_compra o
WHERE NOT EXISTS (SELECT 1 FROM fdw_catalogo.proveedores p WHERE p.id_proveedor = o.id_proveedor)
   OR NOT EXISTS (SELECT 1 FROM fdw_catalogo.almacenes a WHERE a.id_almacen = o.id_almacen_destino);
-- Pedidos con cliente inexistente
SELECT p.id_sede, p.id_pedido FROM fdw_ventas.pedidos_venta p
WHERE NOT EXISTS (SELECT 1 FROM fdw_catalogo.clientes c WHERE c.id_cliente = p.id_cliente);
-- Unicidad global de id_pedido (sin duplicados entre fragmentos)
SELECT id_pedido, count(*) FROM fdw_ventas.pedidos_venta
GROUP BY id_pedido HAVING count(*) > 1;

-- A3. Prueba 10: el reporte corporativo NO infla ventas por fan-out
-- (3a y 3b deben coincidir; 3c muestra el total erroneo del JOIN cartesiano)
SELECT SUM(total_facturado) AS total_en_vista FROM vista_reporte_corporativo;              -- 3a
SELECT SUM(total_registrado) AS total_real                                                 -- 3b
  FROM fdw_ventas.pedidos_venta WHERE estado IN ('CONFIRMADO','DESPACHADO','ENTREGADO');
SELECT SUM(pv.total_registrado) AS total_inflado_erroneo                                   -- 3c
FROM fdw_ventas.pedidos_venta pv
JOIN fdw_ventas.detalle_pedido dp ON dp.id_sede = pv.id_sede AND dp.id_pedido = pv.id_pedido
JOIN fdw_ventas.pagos p ON p.id_sede = pv.id_sede AND p.id_pedido = pv.id_pedido
WHERE pv.estado IN ('CONFIRMADO','DESPACHADO','ENTREGADO') AND p.estado = 'CONFIRMADO';

-- A4. Prueba 9b: gerencia puede leer el reporte, pero NO el password_hash
SET ROLE u_gerente;
SELECT sede_nombre, total_facturado FROM vista_reporte_corporativo ORDER BY id_sede;  -- PERMITIDO
SELECT password_hash FROM fdw_identidad.usuarios;  -- DENEGADO: ERROR permission denied
RESET ROLE;


-- #####################################################################
-- BLOQUE B  →  Ejecutar en el proyecto  empresa-catalogo
-- (pruebas 1, 2 y 4: UNIQUE y FK local)
-- #####################################################################

-- Prueba 1: crear producto valido y consultarlo (esperado: 1 fila)
INSERT INTO productos (sku, nombre, id_categoria, unidad_medida, precio_lista)
VALUES ('SKU-TEST', 'Producto de prueba', 1, 'UND', 10000);
SELECT id_producto, sku, nombre, estado FROM productos WHERE sku = 'SKU-TEST';

-- Prueba 2: SKU duplicado (esperado: ERROR uq_productos_sku)
INSERT INTO productos (sku, nombre, id_categoria, unidad_medida, precio_lista)
VALUES ('SKU-TEST', 'Duplicado', 1, 'UND', 10000);

-- Prueba 4: FK local con categoria inexistente (esperado: ERROR fk_productos_categoria)
INSERT INTO productos (sku, nombre, id_categoria, unidad_medida, precio_lista)
VALUES ('SKU-FK', 'Sin categoria', 9999, 'UND', 10000);

-- Limpieza
DELETE FROM productos WHERE sku = 'SKU-TEST';


-- #####################################################################
-- BLOQUE C  →  Ejecutar en el proyecto  empresa-inventarios
-- (pruebas 3, 5 y 6: CHECK, fragmentos y vista consolidada)
-- #####################################################################

-- Prueba 3: existencia negativa (esperado: ERROR ck_inv_existencia)
INSERT INTO inventarios (id_sede, id_almacen, id_producto, existencia_actual, stock_minimo)
VALUES (1, 1, 999, -5, 10);

-- Prueba 5: los fragmentos Norte y Sur contienen registros distintos
SELECT 'norte' AS fragmento, id_sede, id_almacen, id_producto, existencia_actual
FROM inventarios_norte ORDER BY id_producto LIMIT 3;
SELECT 'sur' AS fragmento, id_sede, id_almacen, id_producto, existencia_actual
FROM inventarios_sur ORDER BY id_producto LIMIT 3;
-- Filas compartidas entre fragmentos (esperado: 0)
SELECT count(*) AS filas_repetidas
FROM inventarios_norte n JOIN inventarios_sur s USING (id_almacen, id_producto);

-- Prueba 6: la vista consolidada reune los 4 fragmentos (esperado: 4 filas; total = tabla)
SELECT fragmento_origen, count(*) AS filas FROM v_inventarios
GROUP BY fragmento_origen ORDER BY fragmento_origen;
SELECT (SELECT count(*) FROM v_inventarios) AS total_vista,
       (SELECT count(*) FROM inventarios)  AS total_tabla;


-- #####################################################################
-- BLOQUE D  →  Ejecutar en el proyecto  empresa-ventas
-- (prueba 9a: aislamiento de vendedor por sede)
-- #####################################################################

SET ROLE u_vend_norte;
-- PERMITIDO: leer pedidos de su propia sede
SELECT count(*) AS pedidos_norte FROM pedidos_norte;
-- DENEGADO: insertar en la particion de otra sede (ERROR permission denied)
INSERT INTO pedidos_sur (id_almacen, id_cliente, id_empleado, fecha_pedido)
VALUES (2, 1, 9, DATE '2026-10-31');
RESET ROLE;
