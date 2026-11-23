-- =====================================================================
-- 10_verificacion_reportes_neon.sql  -  Verificacion final
-- Proyecto Neon: empresa-reportes
-- Ejecuta cada chequeo de a uno para ver su resultado.
-- =====================================================================

-- CHK 1: FDW conecta a los 5 microservicios (conteos esperados)
--   catalogo: sedes=4, almacenes=6, productos=80, proveedores=10, clientes=100
--   identidad: empleados=20  | inventarios=... | compras: ordenes=60
--   ventas: pedidos=320, devoluciones=20
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
UNION ALL SELECT 'ventas.devoluciones', count(*) FROM fdw_ventas.devoluciones
ORDER BY tabla;

-- CHK 2: las 10 vistas obligatorias existen
SELECT viewname FROM pg_views
WHERE schemaname = 'public' AND viewname LIKE 'vista_%'
ORDER BY viewname;

-- CHK 3: cada vista corre sin error y devuelve filas (conteo por vista)
SELECT 'vista_inventario_por_sede' AS vista, count(*) FROM vista_inventario_por_sede
UNION ALL SELECT 'vista_alertas_reabastecimiento', count(*) FROM vista_alertas_reabastecimiento
UNION ALL SELECT 'vista_productos_sin_inventario', count(*) FROM vista_productos_sin_inventario
UNION ALL SELECT 'vista_ventas_mensuales_por_sede', count(*) FROM vista_ventas_mensuales_por_sede
UNION ALL SELECT 'vista_pedidos_pendientes', count(*) FROM vista_pedidos_pendientes
UNION ALL SELECT 'vista_saldos_pendientes', count(*) FROM vista_saldos_pendientes
UNION ALL SELECT 'vista_compras_pendientes', count(*) FROM vista_compras_pendientes
UNION ALL SELECT 'vista_transferencias_en_transito', count(*) FROM vista_transferencias_en_transito
UNION ALL SELECT 'vista_devoluciones_por_producto', count(*) FROM vista_devoluciones_por_producto
UNION ALL SELECT 'vista_reporte_corporativo', count(*) FROM vista_reporte_corporativo
ORDER BY vista;

-- CHK 4: pagos multiples (el fix). Debe haber pedidos con 2 pagos confirmados.
SELECT count(*) AS pedidos_con_pagos_multiples
FROM (
  SELECT id_sede, id_pedido
  FROM fdw_ventas.pagos
  WHERE estado = 'CONFIRMADO'
  GROUP BY id_sede, id_pedido
  HAVING count(*) > 1
) t;

-- CHK 5: saldos pendientes derivados de pagos parciales (~20% del total)
SELECT id_sede, id_pedido, total_registrado, total_pagado, saldo_pendiente
FROM vista_saldos_pendientes
WHERE id_pedido % 5 = 0
ORDER BY id_sede, id_pedido
LIMIT 10;

-- CHK 6: anti fan-out. 6a y 6b deben COINCIDIR; 6c es el valor inflado erroneo.
SELECT SUM(total_facturado) AS total_en_vista FROM vista_reporte_corporativo;              -- 6a
SELECT SUM(total_registrado) AS total_real                                                 -- 6b
  FROM fdw_ventas.pedidos_venta WHERE estado IN ('CONFIRMADO','DESPACHADO','ENTREGADO');
SELECT SUM(pv.total_registrado) AS total_inflado_erroneo                                   -- 6c
FROM fdw_ventas.pedidos_venta pv
JOIN fdw_ventas.detalle_pedido dp ON dp.id_sede = pv.id_sede AND dp.id_pedido = pv.id_pedido
JOIN fdw_ventas.pagos p ON p.id_sede = pv.id_sede AND p.id_pedido = pv.id_pedido
WHERE pv.estado IN ('CONFIRMADO','DESPACHADO','ENTREGADO') AND p.estado = 'CONFIRMADO';

-- CHK 7: integridad logica inter-base (las 3 deben devolver 0 filas)
SELECT 'empleados_sede_huerfana' AS control, count(*) AS violaciones
FROM fdw_identidad.empleados e
WHERE NOT EXISTS (SELECT 1 FROM fdw_catalogo.sedes s WHERE s.id_sede = e.id_sede)
UNION ALL
SELECT 'pedidos_cliente_huerfano', count(*)
FROM fdw_ventas.pedidos_venta p
WHERE NOT EXISTS (SELECT 1 FROM fdw_catalogo.clientes c WHERE c.id_cliente = p.id_cliente)
UNION ALL
SELECT 'ordenes_proveedor_huerfano', count(*)
FROM fdw_compras.ordenes_compra o
WHERE NOT EXISTS (SELECT 1 FROM fdw_catalogo.proveedores pr WHERE pr.id_proveedor = o.id_proveedor);

-- CHK 8: reporte corporativo completo (las 4 sedes)
SELECT * FROM vista_reporte_corporativo ORDER BY id_sede;
