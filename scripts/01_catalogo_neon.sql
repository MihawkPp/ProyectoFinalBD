-- =====================================================================
-- 01_catalogo_neon.sql  -  Microservicio: Catálogo y Terceros (Neon)
-- Proyecto Neon: empresa-catalogo
-- Entidades: sedes, almacenes, categorias, productos, proveedores,
--            producto_proveedor, clientes (7 tablas)
-- =====================================================================

-- ---------- 1. DDL y Restricciones ----------
CREATE TABLE sedes (
  id_sede    SMALLINT     NOT NULL,
  nombre     VARCHAR(100) NOT NULL,
  ciudad     VARCHAR(100) NOT NULL,
  direccion  VARCHAR(200) NOT NULL,
  tipo_sede  VARCHAR(15)  NOT NULL,
  estado     VARCHAR(10)  NOT NULL DEFAULT 'ACTIVO',
  CONSTRAINT pk_sedes PRIMARY KEY (id_sede),
  CONSTRAINT uq_sedes_nombre UNIQUE (nombre),
  CONSTRAINT ck_sedes_tipo CHECK (tipo_sede IN ('COMERCIAL', 'DISTRIBUCION')),
  CONSTRAINT ck_sedes_estado CHECK (estado IN ('ACTIVO', 'INACTIVO'))
);

CREATE TABLE almacenes (
  id_almacen   INTEGER GENERATED ALWAYS AS IDENTITY,
  id_sede      SMALLINT     NOT NULL,
  nombre       VARCHAR(100) NOT NULL,
  tipo_almacen VARCHAR(15)  NOT NULL,
  estado       VARCHAR(10)  NOT NULL DEFAULT 'ACTIVO',
  CONSTRAINT pk_almacenes PRIMARY KEY (id_almacen),
  CONSTRAINT fk_almacenes_sede FOREIGN KEY (id_sede) REFERENCES sedes (id_sede),
  CONSTRAINT uq_almacenes_nombre UNIQUE (id_sede, nombre),
  CONSTRAINT ck_almacenes_tipo CHECK (tipo_almacen IN ('PRINCIPAL', 'MAYORISTA', 'DEVOLUCIONES', 'EXHIBICION', 'BODEGA')),
  CONSTRAINT ck_almacenes_estado CHECK (estado IN ('ACTIVO', 'INACTIVO'))
);

CREATE TABLE categorias (
  id_categoria INTEGER GENERATED ALWAYS AS IDENTITY,
  nombre       VARCHAR(100) NOT NULL,
  descripcion  VARCHAR(255) NOT NULL,
  estado       VARCHAR(10)  NOT NULL DEFAULT 'ACTIVO',
  CONSTRAINT pk_categorias PRIMARY KEY (id_categoria),
  CONSTRAINT uq_categorias_nombre UNIQUE (nombre),
  CONSTRAINT ck_categorias_estado CHECK (estado IN ('ACTIVO', 'INACTIVO'))
);

CREATE TABLE productos (
  id_producto   INTEGER GENERATED ALWAYS AS IDENTITY,
  sku           VARCHAR(50)    NOT NULL,
  nombre        VARCHAR(120)   NOT NULL,
  id_categoria  INTEGER        NOT NULL,
  unidad_medida VARCHAR(10)    NOT NULL,
  precio_lista  NUMERIC(14,2)  NOT NULL,
  estado        VARCHAR(10)    NOT NULL DEFAULT 'ACTIVO',
  CONSTRAINT pk_productos PRIMARY KEY (id_producto),
  CONSTRAINT fk_productos_categoria FOREIGN KEY (id_categoria) REFERENCES categorias (id_categoria),
  CONSTRAINT uq_productos_sku UNIQUE (sku),
  CONSTRAINT ck_productos_precio CHECK (precio_lista > 0),
  CONSTRAINT ck_productos_unidad CHECK (unidad_medida IN ('UND', 'KG', 'LT', 'CAJA')),
  CONSTRAINT ck_productos_estado CHECK (estado IN ('ACTIVO', 'INACTIVO'))
);

CREATE TABLE proveedores (
  id_proveedor   INTEGER GENERATED ALWAYS AS IDENTITY,
  identificacion VARCHAR(20)  NOT NULL,
  razon_social   VARCHAR(150) NOT NULL,
  ciudad         VARCHAR(100) NOT NULL,
  correo         VARCHAR(120) NOT NULL,
  telefono       VARCHAR(30)  NOT NULL,
  estado         VARCHAR(10)  NOT NULL DEFAULT 'ACTIVO',
  CONSTRAINT pk_proveedores PRIMARY KEY (id_proveedor),
  CONSTRAINT uq_proveedores_ident UNIQUE (identificacion),
  CONSTRAINT ck_proveedores_correo CHECK (correo LIKE '%_@_%._%'),
  CONSTRAINT ck_proveedores_estado CHECK (estado IN ('ACTIVO', 'INACTIVO'))
);

CREATE TABLE producto_proveedor (
  id_producto        INTEGER       NOT NULL,
  id_proveedor       INTEGER       NOT NULL,
  costo_referencia   NUMERIC(14,2) NOT NULL,
  plazo_entrega_dias INTEGER       NOT NULL,
  CONSTRAINT pk_producto_proveedor PRIMARY KEY (id_producto, id_proveedor),
  CONSTRAINT fk_pp_producto FOREIGN KEY (id_producto) REFERENCES productos (id_producto),
  CONSTRAINT fk_pp_proveedor FOREIGN KEY (id_proveedor) REFERENCES proveedores (id_proveedor),
  CONSTRAINT ck_pp_costo CHECK (costo_referencia >= 0),
  CONSTRAINT ck_pp_plazo CHECK (plazo_entrega_dias > 0)
);

CREATE TABLE clientes (
  id_cliente      INTEGER GENERATED ALWAYS AS IDENTITY,
  tipo_documento  VARCHAR(10)  NOT NULL,
  num_documento   VARCHAR(20)  NOT NULL,
  nombre_completo VARCHAR(150) NOT NULL,
  correo          VARCHAR(120) NOT NULL,
  telefono        VARCHAR(30)  NOT NULL,
  estado          VARCHAR(10)  NOT NULL DEFAULT 'ACTIVO',
  CONSTRAINT pk_clientes PRIMARY KEY (id_cliente),
  CONSTRAINT uq_clientes_doc UNIQUE (tipo_documento, num_documento),
  CONSTRAINT ck_clientes_tipo_doc CHECK (tipo_documento IN ('CC', 'CE', 'NIT', 'PASAPORTE')),
  CONSTRAINT ck_clientes_correo CHECK (correo LIKE '%_@_%._%'),
  CONSTRAINT ck_clientes_estado CHECK (estado IN ('ACTIVO', 'INACTIVO'))
);

-- ---------- 2. Carga de Datos Maestros y de Prueba ----------
SELECT setseed(0.42);

INSERT INTO sedes (id_sede, nombre, ciudad, direccion, tipo_sede, estado) VALUES
  (1, 'Sede Norte',               'Bogota',   'Calle 170 # 15-20',   'COMERCIAL',    'ACTIVO'),
  (2, 'Sede Sur',                 'Medellin', 'Carrera 43A # 12-50', 'COMERCIAL',    'ACTIVO'),
  (3, 'Sede Occidente',           'Cali',     'Avenida 6N # 22-15',  'COMERCIAL',    'ACTIVO'),
  (4, 'Centro de Distribucion',   'Bogota',   'Autopista Medellin km 3.5 Parque Ind.', 'DISTRIBUCION', 'ACTIVO');

INSERT INTO almacenes (id_sede, nombre, tipo_almacen, estado) VALUES
  (1, 'Almacen Norte Principal',    'PRINCIPAL',    'ACTIVO'),
  (2, 'Almacen Sur Principal',      'PRINCIPAL',    'ACTIVO'),
  (3, 'Almacen Occidente Principal','PRINCIPAL',    'ACTIVO'),
  (4, 'CD Principal Bodega Central','PRINCIPAL',    'ACTIVO'),
  (4, 'CD Mayorista',               'MAYORISTA',    'ACTIVO'),
  (4, 'CD Devoluciones y Mermas',   'DEVOLUCIONES', 'ACTIVO');

INSERT INTO categorias (nombre, descripcion) VALUES
  ('Tecnologia',           'Equipos de computo, celulares y accesorios electronicos'),
  ('Papeleria y Oficina',  'Articulos de escritorio, papel y consumibles'),
  ('Hogar y Decoracion',   'Mobiliario menor, organizadores y ambientacion'),
  ('Deportes y Fitness',   'Implementos deportivos, termos y entrenamiento'),
  ('Seguridad y Accesorios','Cintas, candados y equipos de proteccion personal');

INSERT INTO productos (sku, nombre, id_categoria, unidad_medida, precio_lista, estado)
SELECT
  'SKU-' || LPAD(g::text, 4, '0') AS sku,
  'Producto Corporativo ' || g AS nombre,
  ((g % 5) + 1) AS id_categoria,
  CASE (g % 4)
    WHEN 0 THEN 'UND'
    WHEN 1 THEN 'CAJA'
    WHEN 2 THEN 'KG'
    ELSE 'LT'
  END AS unidad_medida,
  ROUND((15000 + (g * 2300))::numeric, 2) AS precio_lista,
  CASE WHEN g <= 76 THEN 'ACTIVO' ELSE 'INACTIVO' END AS estado
FROM generate_series(1, 80) AS g;

INSERT INTO proveedores (identificacion, razon_social, ciudad, correo, telefono)
SELECT
  'NIT-900' || LPAD(g::text, 6, '0') AS identificacion,
  'Proveedor Industrial ' || g || ' S.A.S.' AS razon_social,
  CASE WHEN g % 2 = 0 THEN 'Bogota' ELSE 'Medellin' END AS ciudad,
  'contacto.prov' || g || '@suministros.com' AS correo,
  '300' || LPAD((7000000 + g)::text, 7, '0') AS telefono
FROM generate_series(1, 10) AS g;

INSERT INTO producto_proveedor (id_producto, id_proveedor, costo_referencia, plazo_entrega_dias)
SELECT
  p.id_producto,
  (((p.id_producto - 1) % 10) + 1) AS id_proveedor,
  ROUND(p.precio_lista * 0.65, 2) AS costo_referencia,
  (3 + (p.id_producto % 10)) AS plazo_entrega_dias
FROM productos p;

INSERT INTO producto_proveedor (id_producto, id_proveedor, costo_referencia, plazo_entrega_dias)
SELECT
  p.id_producto,
  (((p.id_producto + 3) % 10) + 1) AS id_proveedor,
  ROUND(p.precio_lista * 0.68, 2) AS costo_referencia,
  (5 + (p.id_producto % 7)) AS plazo_entrega_dias
FROM productos p
WHERE p.id_producto <= 30;

INSERT INTO clientes (tipo_documento, num_documento, nombre_completo, correo, telefono)
SELECT
  CASE (g % 3) WHEN 0 THEN 'NIT' WHEN 1 THEN 'CC' ELSE 'CE' END AS tipo_documento,
  (1020000000 + g)::text AS num_documento,
  'Cliente Registrado ' || g AS nombre_completo,
  'cliente' || g || '@correo-empresarial.com' AS correo,
  '315' || LPAD((5000000 + g)::text, 7, '0') AS telefono
FROM generate_series(1, 100) AS g;


-- ---------- 3. Permisos en empresa_catalogo ----------
GRANT SELECT ON ALL TABLES IN SCHEMA public TO r_compras, r_inventario, r_vendedor, r_auditor;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO r_administrador;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO r_administrador;
GRANT CREATE ON SCHEMA public TO r_administrador;

-- Gerencia: consulta sin modificar (§8.2)
GRANT SELECT ON ALL TABLES IN SCHEMA public TO r_gerencia;
