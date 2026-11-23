-- =====================================================================
-- 07_consultas_neon.sql  -  20 Consultas Avanzadas (Neon)
-- Proyecto Neon: empresa-reportes
-- Periodo de analisis: 2026-05-01 a 2026-10-31  |  Fecha de corte: 2026-10-31
--
-- Ejecutar en el SQL Editor de empresa-reportes DESPUES de 06_reportes_neon.sql.
-- Cada consulta esta numerada; ejecutalas de a una para ver su resultado.
-- =====================================================================

-- Q01: Inventario consolidado valorizado por producto y sede
SELECT
  s.nombre AS sede, p.sku, p.nombre AS producto, c.nombre AS categoria,
  SUM(i.existencia_actual) AS existencias, p.precio_lista,
  ROUND(SUM(i.existencia_actual) * p.precio_lista, 2) AS valor_total
FROM fdw_inventarios.inventarios i
JOIN fdw_catalogo.sedes s ON s.id_sede = i.id_sede
JOIN fdw_catalogo.productos p ON p.id_producto = i.id_producto
JOIN fdw_catalogo.categorias c ON c.id_categoria = p.id_categoria
GROUP BY s.id_sede, s.nombre, p.sku, p.nombre, c.nombre, p.precio_lista
ORDER BY s.id_sede, valor_total DESC
LIMIT 15;

-- Q02: Alertas de reabastecimiento (bajo minimo o agotado)
SELECT sede_nombre, sku, producto_nombre, categoria_nombre, almacen_nombre,
  existencia_actual, stock_minimo, unidades_faltantes, nivel_alerta
FROM vista_alertas_reabastecimiento
ORDER BY unidades_faltantes DESC, sede_nombre
LIMIT 15;

-- Q03: Productos activos sin inventario en alguna sede (NOT EXISTS)
SELECT s.nombre AS sede, p.id_producto, p.sku, p.nombre AS producto, c.nombre AS categoria
FROM fdw_catalogo.productos p
CROSS JOIN fdw_catalogo.sedes s
JOIN fdw_catalogo.categorias c ON c.id_categoria = p.id_categoria
WHERE p.estado = 'ACTIVO'
  AND NOT EXISTS (
    SELECT 1 FROM fdw_inventarios.inventarios i
    WHERE i.id_sede = s.id_sede AND i.id_producto = p.id_producto
  )
ORDER BY s.id_sede, p.id_producto
LIMIT 15;

-- Q04: Top 5 productos mas vendidos por sede y mes (CTE + DENSE_RANK)
WITH ventas_producto_mes AS (
  SELECT pv.id_sede, s.nombre AS sede, TO_CHAR(pv.fecha_pedido, 'YYYY-MM') AS periodo,
    p.sku, p.nombre AS producto,
    SUM(dp.cantidad) AS unidades_vendidas,
    ROUND(SUM(dp.cantidad * dp.precio_unitario), 2) AS total_vendido
  FROM fdw_ventas.pedidos_venta pv
  JOIN fdw_catalogo.sedes s ON s.id_sede = pv.id_sede
  JOIN fdw_ventas.detalle_pedido dp ON dp.id_sede = pv.id_sede AND dp.id_pedido = pv.id_pedido
  JOIN fdw_catalogo.productos p ON p.id_producto = dp.id_producto
  WHERE pv.estado IN ('CONFIRMADO', 'DESPACHADO', 'ENTREGADO')
  GROUP BY pv.id_sede, s.nombre, TO_CHAR(pv.fecha_pedido, 'YYYY-MM'), p.sku, p.nombre
),
ranking_productos AS (
  SELECT *, DENSE_RANK() OVER (PARTITION BY id_sede, periodo ORDER BY unidades_vendidas DESC) AS ranking
  FROM ventas_producto_mes
)
SELECT sede, periodo, ranking, sku, producto, unidades_vendidas, total_vendido
FROM ranking_productos
WHERE ranking <= 5
ORDER BY id_sede, periodo, ranking
LIMIT 20;

-- Q05: Ventas mensuales y variacion vs mes anterior (CTE + LAG)
WITH mensual AS (
  SELECT id_sede, sede_nombre, periodo, total_vendido FROM vista_ventas_mensuales_por_sede
),
comparativa AS (
  SELECT id_sede, sede_nombre, periodo, total_vendido,
    LAG(total_vendido) OVER (PARTITION BY id_sede ORDER BY periodo) AS venta_mes_anterior
  FROM mensual
)
SELECT sede_nombre, periodo, total_vendido,
  COALESCE(venta_mes_anterior, 0.00) AS venta_mes_anterior,
  ROUND(((total_vendido - venta_mes_anterior) / NULLIF(venta_mes_anterior, 0.00)) * 100.0, 2) AS variacion_pct
FROM comparativa
ORDER BY id_sede, periodo;

-- Q06: Clientes multisede (GROUP BY + HAVING)
SELECT c.id_cliente, c.nombre_completo AS cliente, c.correo,
  COUNT(DISTINCT pv.id_sede) AS sedes_atendidas,
  COUNT(pv.id_pedido) AS total_pedidos,
  ROUND(SUM(pv.total_registrado), 2) AS facturacion_total,
  STRING_AGG(DISTINCT s.nombre, ', ' ORDER BY s.nombre) AS detalle_sedes
FROM fdw_ventas.pedidos_venta pv
JOIN fdw_catalogo.clientes c ON c.id_cliente = pv.id_cliente
JOIN fdw_catalogo.sedes s ON s.id_sede = pv.id_sede
WHERE pv.estado <> 'ANULADO'
GROUP BY c.id_cliente, c.nombre_completo, c.correo
HAVING COUNT(DISTINCT pv.id_sede) >= 2
ORDER BY sedes_atendidas DESC, facturacion_total DESC
LIMIT 15;

-- Q07: Pedidos con saldo pendiente de pago (subconsulta + LEFT JOIN)
SELECT pv.id_sede, s.nombre AS sede, pv.id_pedido, c.nombre_completo AS cliente,
  pv.fecha_pedido, pv.estado AS estado_pedido, pv.total_registrado,
  COALESCE(pag.total_pagado, 0.00) AS total_pagado,
  ROUND((pv.total_registrado - COALESCE(pag.total_pagado, 0.00))::numeric, 2) AS saldo_pendiente
FROM fdw_ventas.pedidos_venta pv
JOIN fdw_catalogo.sedes s ON s.id_sede = pv.id_sede
JOIN fdw_catalogo.clientes c ON c.id_cliente = pv.id_cliente
LEFT JOIN (
  SELECT id_sede, id_pedido, SUM(valor) AS total_pagado
  FROM fdw_ventas.pagos WHERE estado = 'CONFIRMADO'
  GROUP BY id_sede, id_pedido
) pag ON pag.id_sede = pv.id_sede AND pag.id_pedido = pv.id_pedido
WHERE pv.estado NOT IN ('ANULADO')
  AND (pv.total_registrado - COALESCE(pag.total_pagado, 0.00)) > 0
ORDER BY saldo_pendiente DESC
LIMIT 15;

-- Q08: Pedidos con 3 o mas productos distintos (HAVING)
SELECT pv.id_sede, s.nombre AS sede, pv.id_pedido, pv.fecha_pedido, pv.total_registrado,
  COUNT(DISTINCT dp.id_producto) AS productos_distintos, SUM(dp.cantidad) AS total_unidades
FROM fdw_ventas.pedidos_venta pv
JOIN fdw_catalogo.sedes s ON s.id_sede = pv.id_sede
JOIN fdw_ventas.detalle_pedido dp ON dp.id_sede = pv.id_sede AND dp.id_pedido = pv.id_pedido
GROUP BY pv.id_sede, s.nombre, pv.id_pedido, pv.fecha_pedido, pv.total_registrado
HAVING COUNT(DISTINCT dp.id_producto) >= 3
ORDER BY productos_distintos DESC, pv.total_registrado DESC
LIMIT 15;

-- Q09: Pedidos abiertos con mas de 15 dias de antiguedad
WITH params AS (SELECT DATE '2026-10-31' AS fecha_corte, 15 AS umbral_dias)
SELECT pv.id_sede, s.nombre AS sede, pv.id_pedido, c.nombre_completo AS cliente,
  pv.fecha_pedido, (p.fecha_corte - pv.fecha_pedido) AS dias_transcurridos,
  pv.estado, pv.total_registrado
FROM fdw_ventas.pedidos_venta pv
CROSS JOIN params p
JOIN fdw_catalogo.sedes s ON s.id_sede = pv.id_sede
JOIN fdw_catalogo.clientes c ON c.id_cliente = pv.id_cliente
WHERE pv.estado IN ('PENDIENTE', 'CONFIRMADO')
  AND (p.fecha_corte - pv.fecha_pedido) > p.umbral_dias
ORDER BY dias_transcurridos DESC
LIMIT 15;

-- Q10: Demanda pendiente vs inventario disponible (CTE + subconsulta correlacionada)
WITH demanda AS (
  SELECT pv.id_sede, pv.id_almacen, dp.id_producto, SUM(dp.cantidad) AS cantidad_demandada
  FROM fdw_ventas.pedidos_venta pv
  JOIN fdw_ventas.detalle_pedido dp ON dp.id_sede = pv.id_sede AND dp.id_pedido = pv.id_pedido
  WHERE pv.estado IN ('PENDIENTE', 'CONFIRMADO')
  GROUP BY pv.id_sede, pv.id_almacen, dp.id_producto
)
SELECT s.nombre AS sede, a.nombre AS almacen, p.sku, p.nombre AS producto,
  d.cantidad_demandada, COALESCE(i.existencia_actual, 0) AS inventario_actual,
  (COALESCE(i.existencia_actual, 0) - d.cantidad_demandada) AS balance_stock,
  CASE WHEN COALESCE(i.existencia_actual, 0) < d.cantidad_demandada
       THEN 'DEFICIT_PARA_DESPACHO' ELSE 'STOCK_SUFICIENTE' END AS situacion
FROM demanda d
JOIN fdw_catalogo.sedes s ON s.id_sede = d.id_sede
JOIN fdw_catalogo.almacenes a ON a.id_almacen = d.id_almacen
JOIN fdw_catalogo.productos p ON p.id_producto = d.id_producto
LEFT JOIN fdw_inventarios.inventarios i
  ON i.id_sede = d.id_sede AND i.id_almacen = d.id_almacen AND i.id_producto = d.id_producto
WHERE d.cantidad_demandada > COALESCE(i.existencia_actual, 0)
ORDER BY balance_stock ASC
LIMIT 15;

-- Q11: Cumplimiento de proveedores (dias de retraso y puntualidad)
WITH primera_entrega AS (
  SELECT id_orden_compra, MIN(fecha_recepcion) AS fecha_primera_recepcion
  FROM fdw_compras.recepciones_compra GROUP BY id_orden_compra
),
ordenes_evaluadas AS (
  SELECT oc.id_proveedor, oc.id_orden_compra, pe.fecha_primera_recepcion,
    GREATEST(pe.fecha_primera_recepcion - oc.fecha_estimada, 0) AS dias_retraso,
    (pe.fecha_primera_recepcion <= oc.fecha_estimada) AS a_tiempo
  FROM fdw_compras.ordenes_compra oc
  LEFT JOIN primera_entrega pe ON pe.id_orden_compra = oc.id_orden_compra
)
SELECT pr.id_proveedor, pr.razon_social AS proveedor, COUNT(*) AS total_ordenes,
  COUNT(*) FILTER (WHERE oe.a_tiempo) AS recibidas_en_plazo,
  ROUND(AVG(oe.dias_retraso), 1) AS promedio_dias_retraso
FROM ordenes_evaluadas oe
JOIN fdw_catalogo.proveedores pr ON pr.id_proveedor = oe.id_proveedor
GROUP BY pr.id_proveedor, pr.razon_social
ORDER BY promedio_dias_retraso DESC, pr.id_proveedor;

-- Q12: Compras pendientes de recibir por orden y producto
SELECT id_orden_compra, proveedor_nombre AS proveedor, almacen_destino,
  fecha_orden, fecha_estimada, id_producto, producto_nombre AS producto,
  cantidad_solicitada, cantidad_recibida, cantidad_pendiente
FROM vista_compras_pendientes
ORDER BY id_orden_compra, cantidad_pendiente DESC
LIMIT 15;

-- Q13: Transferencias en transito y dias transcurridos
SELECT id_transferencia,
  sede_origen || ' (' || almacen_origen || ')' AS origen,
  sede_destino || ' (' || almacen_destino || ')' AS destino,
  fecha_despacho, dias_en_transito, sku, producto_nombre, cantidad_enviada
FROM vista_transferencias_en_transito
ORDER BY dias_en_transito DESC, id_transferencia
LIMIT 15;

-- Q14: Discrepancias entre cantidad enviada y recibida en transferencias
SELECT t.id_transferencia, so.nombre AS sede_origen, sd.nombre AS sede_destino,
  t.fecha_recepcion, p.sku, p.nombre AS producto,
  dt.cantidad_enviada, COALESCE(dt.cantidad_recibida, 0) AS cantidad_recibida,
  (dt.cantidad_enviada - COALESCE(dt.cantidad_recibida, 0)) AS merma_o_faltante
FROM fdw_inventarios.transferencias t
JOIN fdw_inventarios.detalle_transferencia dt ON dt.id_transferencia = t.id_transferencia
JOIN fdw_catalogo.almacenes ao ON ao.id_almacen = t.id_almacen_origen
JOIN fdw_catalogo.sedes so ON so.id_sede = ao.id_sede
JOIN fdw_catalogo.almacenes ad ON ad.id_almacen = t.id_almacen_destino
JOIN fdw_catalogo.sedes sd ON sd.id_sede = ad.id_sede
JOIN fdw_catalogo.productos p ON p.id_producto = dt.id_producto
WHERE t.estado = 'RECIBIDA' AND dt.cantidad_recibida IS DISTINCT FROM dt.cantidad_enviada
ORDER BY merma_o_faltante DESC;

-- Q15: Oportunidades de redistribucion entre sedes (excedente vs faltante)
SELECT orig.id_sede AS id_sede_origen, so.nombre AS sede_origen,
  dest.id_sede AS id_sede_destino, sd.nombre AS sede_destino,
  p.sku, p.nombre AS producto,
  orig.existencia_actual AS stock_origen, orig.stock_minimo AS minimo_origen,
  dest.existencia_actual AS stock_destino, dest.stock_minimo AS minimo_destino,
  LEAST(orig.existencia_actual - orig.stock_minimo, dest.stock_minimo - dest.existencia_actual) AS cantidad_sugerida_traslado
FROM fdw_inventarios.inventarios orig
JOIN fdw_inventarios.inventarios dest ON dest.id_producto = orig.id_producto AND dest.id_sede <> orig.id_sede
JOIN fdw_catalogo.sedes so ON so.id_sede = orig.id_sede
JOIN fdw_catalogo.sedes sd ON sd.id_sede = dest.id_sede
JOIN fdw_catalogo.productos p ON p.id_producto = orig.id_producto
WHERE orig.existencia_actual > orig.stock_minimo AND dest.existencia_actual < dest.stock_minimo
ORDER BY cantidad_sugerida_traslado DESC
LIMIT 15;

-- Q16: Productos de baja rotacion (sin ventas en 90 dias, NOT EXISTS)
SELECT p.id_producto, p.sku, p.nombre AS producto, c.nombre AS categoria, p.precio_lista,
  SUM(i.existencia_actual) AS stock_inmovilizado,
  ROUND(SUM(i.existencia_actual) * p.precio_lista, 2) AS capital_estancado
FROM fdw_catalogo.productos p
JOIN fdw_catalogo.categorias c ON c.id_categoria = p.id_categoria
JOIN fdw_inventarios.inventarios i ON i.id_producto = p.id_producto
WHERE p.estado = 'ACTIVO'
  AND NOT EXISTS (
    SELECT 1 FROM fdw_ventas.pedidos_venta pv
    JOIN fdw_ventas.detalle_pedido dp ON dp.id_sede = pv.id_sede AND dp.id_pedido = pv.id_pedido
    WHERE dp.id_producto = p.id_producto
      AND pv.estado IN ('CONFIRMADO', 'DESPACHADO', 'ENTREGADO')
      AND pv.fecha_pedido >= (DATE '2026-10-31' - INTERVAL '90 days')
  )
GROUP BY p.id_producto, p.sku, p.nombre, c.nombre, p.precio_lista
HAVING SUM(i.existencia_actual) > 0
ORDER BY capital_estancado DESC
LIMIT 15;

-- Q17: Tasa de devolucion por producto y categoria (CTE)
WITH vend AS (
  SELECT dp.id_producto, SUM(dp.cantidad) AS total_vendido
  FROM fdw_ventas.pedidos_venta pv
  JOIN fdw_ventas.detalle_pedido dp ON dp.id_sede = pv.id_sede AND dp.id_pedido = pv.id_pedido
  WHERE pv.estado IN ('CONFIRMADO', 'DESPACHADO', 'ENTREGADO')
    AND pv.fecha_pedido BETWEEN DATE '2026-05-01' AND DATE '2026-10-31'
  GROUP BY dp.id_producto
),
dev AS (
  SELECT dd.id_producto, SUM(dd.cantidad) AS total_devuelto,
    COUNT(DISTINCT d.id_devolucion) AS eventos_devolucion
  FROM fdw_ventas.devoluciones d
  JOIN fdw_ventas.detalle_devolucion dd ON dd.id_devolucion = d.id_devolucion
  WHERE d.fecha_solicitud BETWEEN DATE '2026-05-01' AND DATE '2026-10-31'
  GROUP BY dd.id_producto
)
SELECT p.id_producto, p.sku, p.nombre AS producto, c.nombre AS categoria,
  COALESCE(v.total_vendido, 0) AS unidades_vendidas,
  COALESCE(d.total_devuelto, 0) AS unidades_devueltas,
  COALESCE(d.eventos_devolucion, 0) AS reclamos_totales,
  ROUND((COALESCE(d.total_devuelto, 0)::numeric / NULLIF(v.total_vendido, 0)) * 100.0, 2) AS tasa_devolucion_pct
FROM fdw_catalogo.productos p
JOIN fdw_catalogo.categorias c ON c.id_categoria = p.id_categoria
LEFT JOIN vend v ON v.id_producto = p.id_producto
LEFT JOIN dev d ON d.id_producto = p.id_producto
WHERE COALESCE(d.total_devuelto, 0) > 0
ORDER BY tasa_devolucion_pct DESC, unidades_devueltas DESC
LIMIT 15;

-- Q18a: Productos en Sede Norte y no en Sede Sur (EXCEPT)
SELECT id_producto, sku, nombre
FROM fdw_catalogo.productos
WHERE id_producto IN (
  SELECT id_producto FROM fdw_inventarios.inventarios WHERE id_sede = 1
  EXCEPT
  SELECT id_producto FROM fdw_inventarios.inventarios WHERE id_sede = 2
)
ORDER BY id_producto;

-- Q18b: Surtido compartido entre Sede Norte y Sede Sur (INTERSECT)
SELECT COUNT(*) AS total_productos_compartidos
FROM (
  SELECT id_producto FROM fdw_inventarios.inventarios WHERE id_sede = 1
  INTERSECT
  SELECT id_producto FROM fdw_inventarios.inventarios WHERE id_sede = 2
) compartidos;

-- Q19: Clasificacion de vendedores por sede (RANK)
WITH ventas_vendedor AS (
  SELECT pv.id_sede, s.nombre AS sede, e.id_empleado, e.nombre_completo AS vendedor,
    COUNT(pv.id_pedido) AS total_pedidos, ROUND(SUM(pv.total_registrado), 2) AS total_facturado
  FROM fdw_ventas.pedidos_venta pv
  JOIN fdw_catalogo.sedes s ON s.id_sede = pv.id_sede
  JOIN fdw_identidad.empleados e ON e.id_empleado = pv.id_empleado
  WHERE pv.estado IN ('CONFIRMADO', 'DESPACHADO', 'ENTREGADO')
  GROUP BY pv.id_sede, s.nombre, e.id_empleado, e.nombre_completo
)
SELECT sede,
  RANK() OVER (PARTITION BY id_sede ORDER BY total_facturado DESC) AS puesto_sede,
  vendedor, total_pedidos, total_facturado
FROM ventas_vendedor
ORDER BY id_sede, puesto_sede;

-- Q20: Consolidado corporativo por sede + total general (CTE + UNION ALL)
WITH base AS (
  SELECT sede_nombre AS sede, productos_activos, stock_total_unidades,
    pedidos_confirmados, total_facturado, pedidos_pendientes, total_compras, total_transferencias
  FROM vista_reporte_corporativo
)
SELECT * FROM base
UNION ALL
SELECT 'TOTAL CORPORATIVO',
  (SELECT COUNT(*) FROM fdw_catalogo.productos WHERE estado = 'ACTIVO'),
  SUM(stock_total_unidades), SUM(pedidos_confirmados), SUM(total_facturado),
  SUM(pedidos_pendientes), SUM(total_compras), SUM(total_transferencias)
FROM base;
