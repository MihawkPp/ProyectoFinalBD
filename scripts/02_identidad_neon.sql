-- =====================================================================
-- 02_identidad_neon.sql  -  Microservicio: Identidad y Accesos (Neon)
-- Proyecto Neon: empresa-identidad
-- Entidades: empleados, usuarios, auditoria_accesos (3 tablas)
-- =====================================================================

CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ---------- 1. DDL y Restricciones ----------
CREATE TABLE empleados (
  id_empleado     INTEGER GENERATED ALWAYS AS IDENTITY,
  id_sede         SMALLINT     NOT NULL,
  num_documento   VARCHAR(20)  NOT NULL,
  nombre_completo VARCHAR(150) NOT NULL,
  cargo           VARCHAR(50)  NOT NULL,
  correo          VARCHAR(120) NOT NULL,
  estado          VARCHAR(10)  NOT NULL DEFAULT 'ACTIVO',
  CONSTRAINT pk_empleados PRIMARY KEY (id_empleado),
  CONSTRAINT uq_empleados_doc UNIQUE (num_documento),
  CONSTRAINT uq_empleados_correo UNIQUE (correo),
  CONSTRAINT ck_empleados_correo CHECK (correo LIKE '%_@_%._%'),
  CONSTRAINT ck_empleados_estado CHECK (estado IN ('ACTIVO', 'INACTIVO'))
);

CREATE TABLE usuarios (
  id_usuario      INTEGER GENERATED ALWAYS AS IDENTITY,
  id_empleado     INTEGER      NOT NULL,
  nombre_usuario  VARCHAR(50)  NOT NULL,
  password_hash   VARCHAR(255) NOT NULL,
  rol             VARCHAR(15)  NOT NULL,
  estado          VARCHAR(10)  NOT NULL DEFAULT 'ACTIVO',
  fecha_creacion  TIMESTAMP    NOT NULL DEFAULT now(),
  CONSTRAINT pk_usuarios PRIMARY KEY (id_usuario),
  CONSTRAINT fk_usuarios_empleado FOREIGN KEY (id_empleado) REFERENCES empleados (id_empleado),
  CONSTRAINT uq_usuarios_nombre UNIQUE (nombre_usuario),
  CONSTRAINT uq_usuarios_empleado UNIQUE (id_empleado),
  CONSTRAINT ck_usuarios_rol CHECK (rol IN ('ADMINISTRADOR','GERENCIA','INVENTARIO','COMPRAS','VENDEDOR','AUDITOR')),
  CONSTRAINT ck_usuarios_estado CHECK (estado IN ('ACTIVO', 'INACTIVO'))
);

CREATE TABLE auditoria_accesos (
  id_auditoria      BIGINT GENERATED ALWAYS AS IDENTITY,
  id_usuario        INTEGER      NOT NULL,
  fecha_hora        TIMESTAMP    NOT NULL DEFAULT now(),
  accion            VARCHAR(10)  NOT NULL,
  objeto_consultado VARCHAR(100) NOT NULL,
  CONSTRAINT pk_auditoria PRIMARY KEY (id_auditoria),
  CONSTRAINT fk_auditoria_usuario FOREIGN KEY (id_usuario) REFERENCES usuarios (id_usuario),
  CONSTRAINT ck_auditoria_accion CHECK (accion IN ('SELECT', 'INSERT', 'UPDATE', 'DELETE', 'LOGIN'))
);

-- ---------- 2. Carga de Datos de Prueba ----------
SELECT setseed(0.42);

INSERT INTO empleados (id_sede, num_documento, nombre_completo, cargo, correo)
SELECT
  ((g - 1) / 5) + 1 AS id_sede,
  (79000000 + g)::text AS num_documento,
  'Empleado ' || g || ' - Sede ' || (((g - 1) / 5) + 1) AS nombre_completo,
  CASE g
    WHEN 1 THEN 'Administrador'
    WHEN 2 THEN 'Gerente'
    WHEN 3 THEN 'Compras'
    WHEN 4 THEN 'Vendedor'
    WHEN 5 THEN 'Vendedor'
    WHEN 6 THEN 'Auditor'
    WHEN 7 THEN 'Inventario'
    WHEN 8 THEN 'Compras'
    WHEN 9 THEN 'Vendedor'
    WHEN 10 THEN 'Vendedor'
    WHEN 11 THEN 'Gerente'
    WHEN 12 THEN 'Inventario'
    WHEN 13 THEN 'Compras'
    WHEN 14 THEN 'Vendedor'
    WHEN 15 THEN 'Vendedor'
    WHEN 16 THEN 'Administrador'
    WHEN 17 THEN 'Inventario'
    WHEN 18 THEN 'Compras'
    WHEN 19 THEN 'Vendedor'
    ELSE 'Vendedor'
  END AS cargo,
  'empleado' || g || '@empresa.com' AS correo
FROM generate_series(1, 20) AS g;

INSERT INTO usuarios (id_empleado, nombre_usuario, password_hash, rol)
SELECT
  e.id_empleado,
  'user_' || e.id_empleado AS nombre_usuario,
  crypt('Pass_2026', gen_salt('bf', 6)) AS password_hash,
  CASE e.cargo
    WHEN 'Gerente'       THEN 'GERENCIA'
    WHEN 'Administrador' THEN 'ADMINISTRADOR'
    WHEN 'Compras'       THEN 'COMPRAS'
    WHEN 'Inventario'    THEN 'INVENTARIO'
    WHEN 'Vendedor'      THEN 'VENDEDOR'
    WHEN 'Auditor'       THEN 'AUDITOR'
  END AS rol
FROM empleados e;

INSERT INTO auditoria_accesos (id_usuario, fecha_hora, accion, objeto_consultado)
SELECT
  ((g % 20) + 1) AS id_usuario,
  TIMESTAMP '2026-10-31 18:00:00' - (g * INTERVAL '3 hours 15 minutes') AS fecha_hora,
  CASE (g % 4) WHEN 0 THEN 'SELECT' WHEN 1 THEN 'INSERT' WHEN 2 THEN 'UPDATE' ELSE 'LOGIN' END AS accion,
  CASE (g % 3) WHEN 0 THEN 'ventas.pedidos_venta' WHEN 1 THEN 'inventarios.inventarios' ELSE 'compras.ordenes_compra' END AS objeto_consultado
FROM generate_series(1, 40) AS g;


-- ---------- 3. Permisos en empresa_identidad ----------
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO r_administrador;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO r_administrador;
GRANT CREATE ON SCHEMA public TO r_administrador;

-- Gerencia: consulta empleados y auditoria; en usuarios excluye password_hash (§8.2)
GRANT SELECT ON empleados, auditoria_accesos TO r_gerencia;
GRANT SELECT (id_usuario, id_empleado, nombre_usuario, rol, estado, fecha_creacion)
  ON usuarios TO r_gerencia;

-- Auditor: consulta empleados y auditoria completa; en usuarios excluye password_hash
GRANT SELECT ON empleados, auditoria_accesos TO r_auditor;
GRANT SELECT (id_usuario, id_empleado, nombre_usuario, rol, estado, fecha_creacion)
  ON usuarios TO r_auditor;
