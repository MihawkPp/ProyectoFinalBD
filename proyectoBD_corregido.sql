-- =====================================================================
-- proyecto bd: arquitectura de microservicios simulada con esquemas
-- ejecutar sobre una base de datos vacia, con un superusuario (postgres)
--
-- convenciones:
--   * fk real  : solo entre tablas del mismo esquema (o dentro de una tabla particionada)
--   * ref. logica: id compartido hacia otro microservicio, SIN fk (ver "consultas de control" al final)
--   * ids de sede fijos: 1 distribucion, 2 norte, 3 sur, 4 centro (los fragmentos se definen por este valor)
-- =====================================================================

-- se crean microservicios como esquemas
create schema catalogo;
create schema compras;
create schema inventarios;
create schema ventas;
create schema identidad;
create schema reportes;

-- Microservicio de Catalogo y Terceros
create table catalogo.sedes (
	id_sede int primary key, -- fijo: 1 distribucion, 2 norte, 3 sur, 4 centro
	nombre varchar(100) not null,
	ciudad varchar(100) not null,
	direccion varchar(200) not null,
	tipo_sede varchar(50) not null check (tipo_sede in ('Venta', 'Distribucion')),
	estado varchar(20) not null default 'Activo' check (estado in ('Activo', 'Inactivo'))
);

create table catalogo.almacenes(
	id_almacen serial primary key,
	id_sede int not null references catalogo.sedes(id_sede),
	nombre varchar(100) not null,
	tipo_almacen varchar(50) not null check (tipo_almacen in ('Principal', 'Exhibicion', 'Bodega')),
	estado varchar(20) not null default 'Activo' check (estado in ('Activo', 'Inactivo'))
);

create table catalogo.categorias (
	id_categoria serial primary key,
	nombre varchar(100) not null,
	descripcion varchar(200) not null,
	estado varchar(20) not null default 'Activo' check (estado in ('Activo', 'Inactivo'))
);

create table catalogo.productos (
	id_producto serial primary key,
	sku varchar(50) not null unique,
	nombre varchar(100) not null,
	id_categoria int not null references catalogo.categorias(id_categoria),
	unidad_medida varchar(20) not null,
	precio_lista numeric(12, 2) not null check (precio_lista >= 0),
	estado varchar(20) not null default 'Activo' check (estado in ('Activo', 'Inactivo'))
);

create table catalogo.proveedores(
	id_proveedor serial primary key,
	identificacion varchar(20) not null unique,
	razon_social varchar(100) not null,
	ciudad varchar(100) not null,
	correo varchar(100) not null,
	telefono varchar(20) not null,
	estado varchar(20) not null default 'Activo' check (estado in ('Activo', 'Inactivo'))
);

create table catalogo.producto_proveedor(
	id_producto int not null references catalogo.productos(id_producto),
	id_proveedor int not null references catalogo.proveedores(id_proveedor),
	costo_referencia numeric(12, 2) not null check (costo_referencia >= 0),
	plazo_entrega_dias int not null check (plazo_entrega_dias >= 0),
	primary key(id_producto, id_proveedor)
);

create table catalogo.clientes(
	id_cliente serial primary key,
	tipo_documento varchar(20) not null,
	num_documento varchar(20) not null,
	nombre_completo varchar(100) not null,
	correo varchar(100) not null,
	telefono varchar(20) not null,
	estado varchar(20) not null default 'Activo' check (estado in ('Activo', 'Inactivo')),
	unique (tipo_documento, num_documento)
);

-- Microservicio de Identidad y Accesos
create table identidad.empleados(
	id_empleado serial primary key,
	id_sede int not null, -- ref. logica -> catalogo.sedes
	num_documento varchar(20) not null unique,
	nombre_completo varchar(100) not null,
	cargo varchar(50) not null,
	correo varchar(100) not null,
	estado varchar(20) not null default 'Activo' check (estado in ('Activo', 'Inactivo'))
);

create table identidad.usuarios(
	id_usuario serial primary key,
	id_empleado int not null unique references identidad.empleados(id_empleado), -- unique: relacion 1:1
	nombre_usuario varchar(50) not null unique,
	password_hash varchar(255) not null,
	rol varchar(50) not null check (rol in ('Administrador', 'Gerencia', 'Inventario', 'Compras', 'Vendedor', 'Auditor')),
	estado varchar(20) not null default 'Activo' check (estado in ('Activo', 'Inactivo')),
	fecha_creacion timestamp not null default current_timestamp
);

create table identidad.auditoria_accesos(
	id_auditoria serial primary key,
	id_usuario int not null references identidad.usuarios(id_usuario),
	fecha_hora timestamp not null default current_timestamp,
	accion varchar(100) not null,
	objeto_consultado varchar(100) not null
);

-- Microservicio de Compras y Abastecimiento
create table compras.ordenes_compra(
	id_orden_compra serial primary key,
	id_proveedor int not null,         -- ref. logica -> catalogo.proveedores
	id_almacen_destino int not null,   -- ref. logica -> catalogo.almacenes
	id_empleado int not null,          -- ref. logica -> identidad.empleados
	fecha_orden timestamp not null default current_timestamp,
	fecha_estimada date not null,
	estado varchar(20) not null default 'Pendiente' check (estado in ('Pendiente', 'En Camino', 'Recibido', 'Cancelado')),
	constraint check_fecha_estimada check (fecha_estimada >= fecha_orden::date)
);

create table compras.detalle_orden_compra(
	id_orden_compra int not null references compras.ordenes_compra(id_orden_compra),
	id_producto int not null, -- ref. logica -> catalogo.productos
	cantidad_solicitada int not null check (cantidad_solicitada > 0),
	costo_unitario numeric(12, 2) not null check (costo_unitario >= 0), -- historico
	primary key (id_orden_compra, id_producto)
);

create table compras.recepciones_compra(
	id_recepcion serial primary key,
	id_orden_compra int not null references compras.ordenes_compra(id_orden_compra),
	fecha_recepcion date not null,
	estado varchar(20) not null default 'Total' check (estado in ('Parcialmente', 'Total'))
);

create table compras.detalle_recepcion(
	id_recepcion int not null references compras.recepciones_compra(id_recepcion),
	id_producto int not null, -- ref. logica -> catalogo.productos
	cantidad_recibida int not null check(cantidad_recibida > 0),
	primary key (id_recepcion, id_producto)
);

-- Microservicio de Inventarios y Transferencias
-- 9.2 fragmentacion horizontal por sede (particionamiento declarativo por lista de id_sede)
-- la tabla padre no guarda filas: cada fila vive en el fragmento de su sede
create table inventarios.inventarios(
	id_sede int not null,       -- columna de fragmentacion
	id_almacen int not null,    -- ref. logica -> catalogo.almacenes
	id_producto int not null,   -- ref. logica -> catalogo.productos
	existencia_actual int not null default 0 check(existencia_actual >= 0),
	stock_minimo int not null default 0 check(stock_minimo >= 0),
	fecha_actualizacion timestamp not null default current_timestamp,
	primary key(id_sede, id_almacen, id_producto)
) partition by list (id_sede);

create table inventarios.inventario_distribucion partition of inventarios.inventarios (id_sede default 1) for values in (1);
create table inventarios.inventario_norte        partition of inventarios.inventarios (id_sede default 2) for values in (2);
create table inventarios.inventario_sur          partition of inventarios.inventarios (id_sede default 3) for values in (3);
create table inventarios.inventario_centro       partition of inventarios.inventarios (id_sede default 4) for values in (4);

create table inventarios.transferencias(
	id_transferencia serial primary key,
	id_almacen_origen int not null,   -- ref. logica -> catalogo.almacenes
	id_almacen_destino int not null,  -- ref. logica -> catalogo.almacenes
	fecha_solicitud timestamp not null default current_timestamp,
	fecha_despacho timestamp,
	fecha_recepcion timestamp,
	estado varchar(20) not null default 'Solicitado' check (estado in ('Solicitado', 'En Transito', 'Completado', 'Cancelado')),
	constraint check_almacenes_diferentes check (id_almacen_origen <> id_almacen_destino),
	constraint check_fechas_transferencia check (
		(fecha_despacho is null or fecha_despacho >= fecha_solicitud) and
		(fecha_recepcion is null or fecha_recepcion >= fecha_despacho)
	),
	-- coherencia estado <-> fechas (en transito = despachada y no recibida)
	constraint check_estado_fechas_transferencia check (
		(estado = 'Solicitado'  and fecha_despacho is null     and fecha_recepcion is null) or
		(estado = 'En Transito' and fecha_despacho is not null and fecha_recepcion is null) or
		(estado = 'Completado'  and fecha_despacho is not null and fecha_recepcion is not null) or
		(estado = 'Cancelado')
	)
);

create table inventarios.detalle_transferencia(
	id_transferencia int not null references inventarios.transferencias(id_transferencia),
	id_producto int not null, -- ref. logica -> catalogo.productos
	cantidad_enviada int not null check (cantidad_enviada > 0),
	cantidad_recibida int check (cantidad_recibida >= 0), -- null mientras esta en transito
	primary key (id_transferencia, id_producto)
);

-- Microservicio de Ventas y Pagos
-- pedidos_venta y detalle_pedido (fragmentacion derivada) y pagos se fragmentan por sede (9.2)
-- id_pedido sale de una sola secuencia (serial) para toda la empresa: no se repite entre fragmentos
-- venta confirmada = pedido en estado 'Pagado' o 'Completado'; pendiente = 'Pendiente'
create table ventas.pedidos_venta(
	id_pedido serial,
	id_sede int not null,       -- columna de fragmentacion; ref. logica -> catalogo.sedes
	id_almacen int not null,    -- ref. logica -> catalogo.almacenes
	id_cliente int not null,    -- ref. logica -> catalogo.clientes
	id_empleado int not null,   -- ref. logica -> identidad.empleados
	fecha_pedido timestamp not null default current_timestamp,
	estado varchar(20) not null default 'Pendiente' check (estado in ('Pendiente', 'Pagado', 'Completado', 'Cancelado')),
	total_registrado numeric(12, 2) not null default 0.00 check (total_registrado >= 0),
	primary key (id_sede, id_pedido)
) partition by list (id_sede);

create table ventas.pedidos_distribucion partition of ventas.pedidos_venta (id_sede default 1) for values in (1);
create table ventas.pedidos_norte        partition of ventas.pedidos_venta (id_sede default 2) for values in (2);
create table ventas.pedidos_sur          partition of ventas.pedidos_venta (id_sede default 3) for values in (3);
create table ventas.pedidos_centro       partition of ventas.pedidos_venta (id_sede default 4) for values in (4);

create table ventas.detalle_pedido(
	id_sede int not null,
	id_pedido int not null,
	id_producto int not null, -- ref. logica -> catalogo.productos
	cantidad int not null check (cantidad > 0),
	precio_unitario numeric(12, 2) not null check (precio_unitario >= 0), -- historico
	primary key (id_sede, id_pedido, id_producto),
	foreign key (id_sede, id_pedido) references ventas.pedidos_venta(id_sede, id_pedido)
) partition by list (id_sede);

create table ventas.detalle_pedido_distribucion partition of ventas.detalle_pedido (id_sede default 1) for values in (1);
create table ventas.detalle_pedido_norte        partition of ventas.detalle_pedido (id_sede default 2) for values in (2);
create table ventas.detalle_pedido_sur          partition of ventas.detalle_pedido (id_sede default 3) for values in (3);
create table ventas.detalle_pedido_centro       partition of ventas.detalle_pedido (id_sede default 4) for values in (4);

create table ventas.pagos(
	id_pago serial,
	id_sede int not null,
	id_pedido int not null,
	fecha_pago timestamp not null default current_timestamp,
	valor numeric(12, 2) not null check (valor > 0),
	medio_pago varchar(50) not null check (medio_pago in ('Efectivo', 'Tarjeta Debito', 'Tarjeta Credito', 'Transferencia', 'PSE')),
	estado varchar(20) not null default 'Confirmado' check (estado in ('Confirmado', 'Pendiente', 'Rechazado')),
	primary key (id_sede, id_pago),
	foreign key (id_sede, id_pedido) references ventas.pedidos_venta(id_sede, id_pedido)
) partition by list (id_sede);

create table ventas.pagos_distribucion partition of ventas.pagos (id_sede default 1) for values in (1);
create table ventas.pagos_norte        partition of ventas.pagos (id_sede default 2) for values in (2);
create table ventas.pagos_sur          partition of ventas.pagos (id_sede default 3) for values in (3);
create table ventas.pagos_centro       partition of ventas.pagos (id_sede default 4) for values in (4);

-- devoluciones y su detalle son tablas globales del servicio (sin aislamiento fisico por sede)
create table ventas.devoluciones(
	id_devolucion serial primary key,
	id_sede int not null,
	id_pedido int not null,
	fecha_solicitud timestamp not null default current_timestamp,
	motivo text not null check (length(btrim(motivo)) > 0),
	estado varchar(20) not null default 'Solicitado' check (estado in ('Solicitado', 'Aprobado', 'Rechazado', 'Procesado')),
	foreign key (id_sede, id_pedido) references ventas.pedidos_venta(id_sede, id_pedido)
);

create table ventas.detalle_devolucion(
	id_devolucion int not null references ventas.devoluciones(id_devolucion),
	id_producto int not null, -- ref. logica -> catalogo.productos
	cantidad int not null check (cantidad > 0),
	condicion_producto varchar(50) not null check (condicion_producto in ('Nuevo', 'Defectuoso', 'Empaque Danado', 'Usado')),
	primary key (id_devolucion, id_producto)
);

-- vistas unificadas (reconstruccion con union all; fragmento_origen indica de donde viene cada fila)
create view reportes.vista_inventario_consolidado as
	select 'inventarios.inventario_distribucion'::text as fragmento_origen, t.* from inventarios.inventario_distribucion t
	union all
	select 'inventarios.inventario_norte', t.* from inventarios.inventario_norte t
	union all
	select 'inventarios.inventario_sur', t.* from inventarios.inventario_sur t
	union all
	select 'inventarios.inventario_centro', t.* from inventarios.inventario_centro t;

create view reportes.vista_pedidos_consolidado as
	select 'ventas.pedidos_distribucion'::text as fragmento_origen, t.* from ventas.pedidos_distribucion t
	union all
	select 'ventas.pedidos_norte', t.* from ventas.pedidos_norte t
	union all
	select 'ventas.pedidos_sur', t.* from ventas.pedidos_sur t
	union all
	select 'ventas.pedidos_centro', t.* from ventas.pedidos_centro t;

------- roles y usuarios

create role rol_admin;
create role rol_gerencia;
create role rol_inventario;
create role rol_compras;
create role rol_vendedor;
create role rol_auditor;

-- Administrador (acceso total a todos los esquemas, creacion de esquemas y de roles)
alter role rol_admin createrole;
do $$ begin execute format('grant create on database %I to rol_admin', current_database()); end $$;
grant usage, create on schema catalogo, compras, inventarios, ventas, identidad, reportes to rol_admin;
grant all privileges on all tables in schema catalogo, compras, inventarios, ventas, identidad, reportes to rol_admin;
grant all privileges on all sequences in schema catalogo, compras, inventarios, ventas, identidad, reportes to rol_admin;

-- Gerencia (solo lectura sobre reportes consolidados y sedes)
grant usage on schema reportes, catalogo to rol_gerencia;
grant select on all tables in schema reportes to rol_gerencia;
grant select on all tables in schema catalogo to rol_gerencia;

-- Responsable de inventario (consulta y actualizacion en inventarios)
-- el acceso a los fragmentos de inventario se concede por sede a cada usuario (mas abajo);
-- el rol NO tiene permisos sobre la tabla padre ni sobre los fragmentos de otras sedes
grant usage on schema inventarios, catalogo to rol_inventario;
grant select, insert, update on inventarios.transferencias, inventarios.detalle_transferencia to rol_inventario;
grant select on all tables in schema catalogo to rol_inventario;
grant usage, select on all sequences in schema inventarios to rol_inventario;

-- Responsable de compras (gestion de ordenes y recepciones)
grant usage on schema compras, catalogo to rol_compras;
grant select, insert, update on all tables in schema compras to rol_compras;
grant select on all tables in schema catalogo to rol_compras;
grant usage, select on all sequences in schema compras to rol_compras;

-- Vendedor (registra y consulta pedidos/pagos de su sede)
-- los permisos sobre pedidos, detalle_pedido y pagos se conceden por sede a cada usuario (mas abajo);
-- el rol NO tiene permisos sobre la tabla padre ni sobre los fragmentos de otras sedes. No se concede delete.
grant usage on schema ventas, catalogo to rol_vendedor;
grant select, insert, update on ventas.devoluciones, ventas.detalle_devolucion to rol_vendedor;
grant select on all tables in schema catalogo to rol_vendedor;
grant usage, select on all sequences in schema ventas to rol_vendedor;

-- Auditor (consulta de toda la informacion, cero permisos de modificacion)
grant usage on schema catalogo, compras, inventarios, ventas, identidad, reportes to rol_auditor;
grant select on all tables in schema catalogo, compras, inventarios, ventas, identidad, reportes to rol_auditor;
-- el auditor no puede ver password_hash: acceso por columnas a identidad.usuarios
revoke select on identidad.usuarios from rol_auditor;
grant select (id_usuario, id_empleado, nombre_usuario, rol, estado, fecha_creacion) on identidad.usuarios to rol_auditor;

-- objetos que se creen despues (por ejemplo las 10 vistas) heredan estos permisos
alter default privileges in schema catalogo, compras, inventarios, ventas, identidad, reportes grant all on tables to rol_admin;
alter default privileges in schema reportes grant select on tables to rol_gerencia, rol_auditor;

-- crear usuarios
create user usuario_admin_1 with password 'Admin123!' login;
create user usuario_gerente_1 with password 'Gerente123!' login;
create user usuario_compra_1 with password 'Compra123!' login;
create user usuario_auditor_1 with password 'Auditor123!' login;

grant rol_admin to usuario_admin_1;
grant rol_gerencia to usuario_gerente_1;
grant rol_compras to usuario_compra_1;
grant rol_auditor to usuario_auditor_1;

-- usuarios por sede: responsable de inventario y vendedor
create user usuario_inv_distribucion with password 'InvDist123!' login;
create user usuario_inv_norte        with password 'InvNorte123!' login;
create user usuario_inv_sur          with password 'InvSur123!' login;
create user usuario_inv_centro       with password 'InvCentro123!' login;
create user usuario_vend_distribucion with password 'VendDist123!' login;
create user usuario_vend_norte        with password 'VendNorte123!' login;
create user usuario_vend_sur          with password 'VendSur123!' login;
create user usuario_vend_centro       with password 'VendCentro123!' login;

grant rol_inventario to usuario_inv_distribucion, usuario_inv_norte, usuario_inv_sur, usuario_inv_centro;
grant rol_vendedor to usuario_vend_distribucion, usuario_vend_norte, usuario_vend_sur, usuario_vend_centro;

-- permisos por fragmento (control de acceso por sede sin rls)
grant select, insert, update on inventarios.inventario_distribucion to usuario_inv_distribucion;
grant select, insert, update on inventarios.inventario_norte        to usuario_inv_norte;
grant select, insert, update on inventarios.inventario_sur          to usuario_inv_sur;
grant select, insert, update on inventarios.inventario_centro       to usuario_inv_centro;

grant select, insert, update on ventas.pedidos_distribucion, ventas.detalle_pedido_distribucion, ventas.pagos_distribucion to usuario_vend_distribucion;
grant select, insert, update on ventas.pedidos_norte,        ventas.detalle_pedido_norte,        ventas.pagos_norte        to usuario_vend_norte;
grant select, insert, update on ventas.pedidos_sur,          ventas.detalle_pedido_sur,          ventas.pagos_sur          to usuario_vend_sur;
grant select, insert, update on ventas.pedidos_centro,       ventas.detalle_pedido_centro,       ventas.pagos_centro       to usuario_vend_centro;

------- consultas de control (deben devolver 0 filas)
-- las referencias entre microservicios no tienen fk; su coherencia se valida con estas consultas

-- 1. empleados con sede inexistente
select e.id_empleado from identidad.empleados e
where not exists (select 1 from catalogo.sedes s where s.id_sede = e.id_sede);

-- 2. ordenes de compra con proveedor, almacen o empleado inexistente
select o.id_orden_compra from compras.ordenes_compra o
where not exists (select 1 from catalogo.proveedores p where p.id_proveedor = o.id_proveedor)
   or not exists (select 1 from catalogo.almacenes a where a.id_almacen = o.id_almacen_destino)
   or not exists (select 1 from identidad.empleados e where e.id_empleado = o.id_empleado);

-- 3. detalles (y inventarios) con producto inexistente
select x.tabla, x.id_producto from (
	select 'detalle_orden_compra' as tabla, id_producto from compras.detalle_orden_compra
	union all select 'detalle_recepcion', id_producto from compras.detalle_recepcion
	union all select 'detalle_transferencia', id_producto from inventarios.detalle_transferencia
	union all select 'detalle_pedido', id_producto from ventas.detalle_pedido
	union all select 'detalle_devolucion', id_producto from ventas.detalle_devolucion
	union all select 'inventarios', id_producto from inventarios.inventarios
) x
where not exists (select 1 from catalogo.productos p where p.id_producto = x.id_producto);

-- 4. inventarios con almacen inexistente o que no pertenece a la sede del fragmento
select i.id_sede, i.id_almacen from inventarios.inventarios i
left join catalogo.almacenes a on a.id_almacen = i.id_almacen
where a.id_almacen is null or a.id_sede <> i.id_sede;

-- 5. transferencias con almacen de origen o destino inexistente
select t.id_transferencia from inventarios.transferencias t
where not exists (select 1 from catalogo.almacenes a where a.id_almacen = t.id_almacen_origen)
   or not exists (select 1 from catalogo.almacenes a where a.id_almacen = t.id_almacen_destino);

-- 6. pedidos con cliente inexistente, almacen que no es de la sede o vendedor que no es de la sede
select p.id_sede, p.id_pedido from ventas.pedidos_venta p
left join catalogo.almacenes a on a.id_almacen = p.id_almacen
left join identidad.empleados e on e.id_empleado = p.id_empleado
where not exists (select 1 from catalogo.clientes c where c.id_cliente = p.id_cliente)
   or a.id_almacen is null or a.id_sede <> p.id_sede
   or e.id_empleado is null or e.id_sede <> p.id_sede;

-- 7. total_registrado distinto de la suma de cantidad x precio del detalle
select p.id_sede, p.id_pedido from ventas.pedidos_venta p
left join (select id_sede, id_pedido, sum(cantidad * precio_unitario) as total
           from ventas.detalle_pedido group by id_sede, id_pedido) d
       on d.id_sede = p.id_sede and d.id_pedido = p.id_pedido
where p.total_registrado <> coalesce(d.total, 0);

-- 8. recepciones: producto no solicitado en la orden o cantidad recibida acumulada mayor que la solicitada
select r.id_orden_compra, dr.id_producto
from compras.detalle_recepcion dr
join compras.recepciones_compra r on r.id_recepcion = dr.id_recepcion
left join compras.detalle_orden_compra d on d.id_orden_compra = r.id_orden_compra and d.id_producto = dr.id_producto
group by r.id_orden_compra, dr.id_producto, d.cantidad_solicitada
having d.cantidad_solicitada is null or sum(dr.cantidad_recibida) > d.cantidad_solicitada;

-- 9. devoluciones: producto que no esta en el pedido o cantidad devuelta mayor que la vendida
select dv.id_devolucion, dd.id_producto
from ventas.detalle_devolucion dd
join ventas.devoluciones dv on dv.id_devolucion = dd.id_devolucion
left join ventas.detalle_pedido p on p.id_sede = dv.id_sede and p.id_pedido = dv.id_pedido and p.id_producto = dd.id_producto
where p.id_producto is null or dd.cantidad > p.cantidad;
