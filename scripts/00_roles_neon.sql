-- =====================================================================
-- 00_roles_neon.sql  -  Roles y Usuarios para Neon (por proyecto)
--
-- En Neon, cada proyecto es un clúster aislado. Los roles NO se
-- comparten entre proyectos. Este script debe ejecutarse EN CADA
-- proyecto Neon ANTES del script de datos correspondiente.
--
-- Crea los 6 roles funcionales y los 12 usuarios de prueba.
-- Es idempotente: si los roles ya existen, actualiza password y grants.
--
-- NOTA: En Neon, el owner del proyecto (neondb_owner) tiene
-- privilegios de superusuario. Ejecutar este script conectado
-- como neondb_owner.
-- =====================================================================

DO $$
BEGIN
  -- ---------- 1. Roles funcionales (NOLOGIN) ----------
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'r_administrador') THEN
    CREATE ROLE r_administrador NOLOGIN;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'r_gerencia') THEN
    CREATE ROLE r_gerencia NOLOGIN;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'r_inventario') THEN
    CREATE ROLE r_inventario NOLOGIN;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'r_compras') THEN
    CREATE ROLE r_compras NOLOGIN;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'r_vendedor') THEN
    CREATE ROLE r_vendedor NOLOGIN;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'r_auditor') THEN
    CREATE ROLE r_auditor NOLOGIN;
  END IF;

  -- ---------- 2. Usuarios de prueba (LOGIN) ----------
  -- Administrador (con CREATEROLE)
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'u_admin') THEN
    CREATE ROLE u_admin LOGIN CREATEROLE PASSWORD 'Admin_2026' IN ROLE r_administrador;
  ELSE
    ALTER ROLE u_admin WITH CREATEROLE PASSWORD 'Admin_2026';
    GRANT r_administrador TO u_admin;
  END IF;

  -- Gerencia
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'u_gerente') THEN
    CREATE ROLE u_gerente LOGIN PASSWORD 'Gerente_2026' IN ROLE r_gerencia;
  ELSE
    ALTER ROLE u_gerente WITH PASSWORD 'Gerente_2026';
    GRANT r_gerencia TO u_gerente;
  END IF;

  -- Compras
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'u_compras') THEN
    CREATE ROLE u_compras LOGIN PASSWORD 'Compras_2026' IN ROLE r_compras;
  ELSE
    ALTER ROLE u_compras WITH PASSWORD 'Compras_2026';
    GRANT r_compras TO u_compras;
  END IF;

  -- Auditor
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'u_auditor') THEN
    CREATE ROLE u_auditor LOGIN PASSWORD 'Auditor_2026' IN ROLE r_auditor;
  ELSE
    ALTER ROLE u_auditor WITH PASSWORD 'Auditor_2026';
    GRANT r_auditor TO u_auditor;
  END IF;

  -- Responsables de inventario por sede
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'u_inv_norte') THEN
    CREATE ROLE u_inv_norte LOGIN PASSWORD 'Inv_norte_2026' IN ROLE r_inventario;
  ELSE
    ALTER ROLE u_inv_norte WITH PASSWORD 'Inv_norte_2026';
    GRANT r_inventario TO u_inv_norte;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'u_inv_sur') THEN
    CREATE ROLE u_inv_sur LOGIN PASSWORD 'Inv_sur_2026' IN ROLE r_inventario;
  ELSE
    ALTER ROLE u_inv_sur WITH PASSWORD 'Inv_sur_2026';
    GRANT r_inventario TO u_inv_sur;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'u_inv_occidente') THEN
    CREATE ROLE u_inv_occidente LOGIN PASSWORD 'Inv_occidente_2026' IN ROLE r_inventario;
  ELSE
    ALTER ROLE u_inv_occidente WITH PASSWORD 'Inv_occidente_2026';
    GRANT r_inventario TO u_inv_occidente;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'u_inv_distribucion') THEN
    CREATE ROLE u_inv_distribucion LOGIN PASSWORD 'Inv_distribucion_2026' IN ROLE r_inventario;
  ELSE
    ALTER ROLE u_inv_distribucion WITH PASSWORD 'Inv_distribucion_2026';
    GRANT r_inventario TO u_inv_distribucion;
  END IF;

  -- Vendedores por sede
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'u_vend_norte') THEN
    CREATE ROLE u_vend_norte LOGIN PASSWORD 'Vend_norte_2026' IN ROLE r_vendedor;
  ELSE
    ALTER ROLE u_vend_norte WITH PASSWORD 'Vend_norte_2026';
    GRANT r_vendedor TO u_vend_norte;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'u_vend_sur') THEN
    CREATE ROLE u_vend_sur LOGIN PASSWORD 'Vend_sur_2026' IN ROLE r_vendedor;
  ELSE
    ALTER ROLE u_vend_sur WITH PASSWORD 'Vend_sur_2026';
    GRANT r_vendedor TO u_vend_sur;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'u_vend_occidente') THEN
    CREATE ROLE u_vend_occidente LOGIN PASSWORD 'Vend_occidente_2026' IN ROLE r_vendedor;
  ELSE
    ALTER ROLE u_vend_occidente WITH PASSWORD 'Vend_occidente_2026';
    GRANT r_vendedor TO u_vend_occidente;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'u_vend_distribucion') THEN
    CREATE ROLE u_vend_distribucion LOGIN PASSWORD 'Vend_distribucion_2026' IN ROLE r_vendedor;
  ELSE
    ALTER ROLE u_vend_distribucion WITH PASSWORD 'Vend_distribucion_2026';
    GRANT r_vendedor TO u_vend_distribucion;
  END IF;
END $$;
