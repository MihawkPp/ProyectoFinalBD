# Despliegue en Neon — 6 Bases de Datos Aisladas

Guía para subir cada microservicio como un **proyecto independiente en Neon**, replicando la arquitectura database-per-service del entorno local PostgreSQL, incluyendo los 6 roles funcionales, 12 usuarios de prueba y la matriz de permisos.

---

## Requisitos Previos

- Cuenta en [Neon](https://neon.tech) (el plan Free soporta hasta 100 proyectos)
- `psql` instalado en tu máquina (cliente PostgreSQL)
- Opcional: [Neon CLI](https://neon.tech/docs/reference/neon-cli) (`npm i -g neonctl`)

---

## 1. Crear los 6 Proyectos en Neon

Desde el [dashboard de Neon](https://console.neon.tech) o por CLI:

```bash
neonctl auth
neonctl projects create --name empresa-catalogo
neonctl projects create --name empresa-identidad
neonctl projects create --name empresa-inventarios
neonctl projects create --name empresa-compras
neonctl projects create --name empresa-ventas
neonctl projects create --name empresa-reportes
```

Cada proyecto genera una connection string con este formato:

```
postgresql://neondb_owner:<PASSWORD>@<HOST>/neondb?sslmode=require
```

Anota el **host**, **usuario** y **password** de cada uno. Los vas a necesitar.

---

## 2. Mapa de Scripts y Proyectos

| Orden | Script | Proyecto Neon | Contenido |
|-------|--------|---------------|-----------|
| 0° | `00_roles_neon.sql` | **Todos** (ejecutar en cada proyecto) | 6 roles + 12 usuarios de prueba |
| 1° | `01_catalogo_neon.sql` | empresa-catalogo | 7 tablas + datos + permisos |
| 2° | `02_identidad_neon.sql` | empresa-identidad | 3 tablas + pgcrypto + permisos |
| 3° | `03_inventarios_neon.sql` | empresa-inventarios | Inventarios particionados + permisos por sede |
| 4° | `04_compras_neon.sql` | empresa-compras | Órdenes de compra + permisos |
| 5° | `05_ventas_neon.sql` | empresa-ventas | Pedidos particionados + permisos por sede |
| 6° | `06_reportes_neon.sql` | empresa-reportes | FDW + 10 vistas + permisos sobre esquemas foráneos |
| 7° | `07_consultas_neon.sql` | empresa-reportes | Las 20 consultas avanzadas obligatorias (§5) |
| 8° | `08_pruebas_neon.sql` | varios (ver encabezados) | Pruebas de verificación de restricciones, roles y fan-out (§11) |

> **Importante:** En cada proyecto, ejecutar primero `00_roles_neon.sql` y luego el script de datos correspondiente.
>
> `07_consultas_neon.sql` se ejecuta en **empresa-reportes** al final. `08_pruebas_neon.sql` está dividido en bloques A–D; cada bloque indica en qué proyecto ejecutarlo (en Neon no se puede cambiar de base con `\c`).

---

## 3. Orden de Ejecución por Proyecto

Para **cada** proyecto Neon, se ejecutan 2 scripts: primero los roles, luego los datos.

```bash
# ── empresa-catalogo ──
psql "postgresql://neondb_owner:PASS@ep-xxxx.neon.tech/neondb?sslmode=require" -f 00_roles_neon.sql
psql "postgresql://neondb_owner:PASS@ep-xxxx.neon.tech/neondb?sslmode=require" -f 01_catalogo_neon.sql

# ── empresa-identidad ──
psql "postgresql://neondb_owner:PASS@ep-yyyy.neon.tech/neondb?sslmode=require" -f 00_roles_neon.sql
psql "postgresql://neondb_owner:PASS@ep-yyyy.neon.tech/neondb?sslmode=require" -f 02_identidad_neon.sql

# ── empresa-inventarios ──
psql "postgresql://neondb_owner:PASS@ep-zzzz.neon.tech/neondb?sslmode=require" -f 00_roles_neon.sql
psql "postgresql://neondb_owner:PASS@ep-zzzz.neon.tech/neondb?sslmode=require" -f 03_inventarios_neon.sql

# ── empresa-compras ──
psql "postgresql://neondb_owner:PASS@ep-aaaa.neon.tech/neondb?sslmode=require" -f 00_roles_neon.sql
psql "postgresql://neondb_owner:PASS@ep-aaaa.neon.tech/neondb?sslmode=require" -f 04_compras_neon.sql

# ── empresa-ventas ──
psql "postgresql://neondb_owner:PASS@ep-bbbb.neon.tech/neondb?sslmode=require" -f 00_roles_neon.sql
psql "postgresql://neondb_owner:PASS@ep-bbbb.neon.tech/neondb?sslmode=require" -f 05_ventas_neon.sql

# ── empresa-reportes (al final, requiere las 5 anteriores pobladas) ──
psql "postgresql://neondb_owner:PASS@ep-cccc.neon.tech/neondb?sslmode=require" -f 00_roles_neon.sql
psql "postgresql://neondb_owner:PASS@ep-cccc.neon.tech/neondb?sslmode=require" -f 06_reportes_neon.sql
```

---

## 4. Roles, Usuarios y Permisos

### 4.1 Estrategia en Neon

En PostgreSQL local, los roles son globales al clúster (un rol existe en todas las bases). En Neon, cada proyecto es un clúster aislado. La solución: **crear los mismos roles en cada proyecto** mediante `00_roles_neon.sql`.

Esto permite:
- Demostrar los 6 roles funcionales y 12 usuarios exigidos en la entrega
- Mantener los GRANT/REVOKE idénticos al entorno local
- Probar accesos permitidos y denegados en cada proyecto

### 4.2 Los 6 Roles Funcionales

| Rol | Tipo | Función |
|-----|------|---------|
| `r_administrador` | NOLOGIN | Crea esquemas, administra permisos, consulta todo |
| `r_gerencia` | NOLOGIN | Consulta reportes consolidados, solo lectura |
| `r_inventario` | NOLOGIN | Gestiona inventarios y transferencias de sus sedes |
| `r_compras` | NOLOGIN | Gestiona órdenes de compra y recepciones |
| `r_vendedor` | NOLOGIN | Registra pedidos, pagos y devoluciones de su sede |
| `r_auditor` | NOLOGIN | Consulta toda la información sin modificar nada |

### 4.3 Los 12 Usuarios de Prueba

| Usuario | Rol asignado | Password |
|---------|-------------|----------|
| `u_admin` | r_administrador | `Admin_2026` |
| `u_gerente` | r_gerencia | `Gerente_2026` |
| `u_compras` | r_compras | `Compras_2026` |
| `u_auditor` | r_auditor | `Auditor_2026` |
| `u_inv_norte` | r_inventario | `Inv_norte_2026` |
| `u_inv_sur` | r_inventario | `Inv_sur_2026` |
| `u_inv_occidente` | r_inventario | `Inv_occidente_2026` |
| `u_inv_distribucion` | r_inventario | `Inv_distribucion_2026` |
| `u_vend_norte` | r_vendedor | `Vend_norte_2026` |
| `u_vend_sur` | r_vendedor | `Vend_sur_2026` |
| `u_vend_occidente` | r_vendedor | `Vend_occidente_2026` |
| `u_vend_distribucion` | r_vendedor | `Vend_distribucion_2026` |

### 4.4 Matriz de Permisos por Proyecto

#### empresa-catalogo

| Rol | SELECT | INSERT | UPDATE | DELETE |
|-----|--------|--------|--------|--------|
| r_administrador | ✅ | ✅ | ✅ | ✅ |
| r_compras | ✅ | ❌ | ❌ | ❌ |
| r_inventario | ✅ | ❌ | ❌ | ❌ |
| r_vendedor | ✅ | ❌ | ❌ | ❌ |
| r_auditor | ✅ | ❌ | ❌ | ❌ |
| r_gerencia | ✅ | ❌ | ❌ | ❌ |

#### empresa-identidad

| Rol | empleados | usuarios | auditoria_accesos |
|-----|-----------|----------|-------------------|
| r_administrador | ALL | ALL | ALL |
| r_auditor | SELECT | SELECT (sin password_hash) | SELECT |
| r_gerencia | SELECT | SELECT (sin password_hash) | SELECT |

#### empresa-inventarios

| Rol | inventarios (particiones) | transferencias | detalle_transferencia |
|-----|--------------------------|----------------|-----------------------|
| r_administrador | ALL | ALL | ALL |
| r_inventario | — (por usuario de sede) | SELECT, INSERT, UPDATE | SELECT, INSERT, UPDATE |
| u_inv_norte | SELECT, INSERT, UPDATE (solo partición norte) | — | — |
| u_inv_sur | SELECT, INSERT, UPDATE (solo partición sur) | — | — |
| r_auditor | SELECT | SELECT | SELECT |
| r_gerencia | SELECT | SELECT | SELECT |

#### empresa-compras

| Rol | SELECT | INSERT | UPDATE | DELETE |
|-----|--------|--------|--------|--------|
| r_administrador | ✅ | ✅ | ✅ | ✅ |
| r_compras | ✅ | ✅ | ✅ | ❌ |
| r_auditor | ✅ | ❌ | ❌ | ❌ |
| r_gerencia | ✅ | ❌ | ❌ | ❌ |

#### empresa-ventas

| Rol | pedidos (particiones) | devoluciones | pagos | vistas |
|-----|----------------------|-------------|-------|--------|
| r_administrador | ALL | ALL | ALL | ALL |
| r_vendedor | — (por usuario de sede) | SELECT, INSERT, UPDATE | — (por usuario) | SELECT |
| u_vend_norte | SELECT, INSERT, UPDATE (solo partición norte) | — | SELECT, INSERT, UPDATE (solo norte) | — |
| r_auditor | SELECT | SELECT | SELECT | SELECT |
| r_gerencia | SELECT | SELECT | SELECT | SELECT |

#### empresa-reportes

| Rol | Vistas públicas | fdw_catalogo | fdw_identidad | fdw_inventarios | fdw_compras | fdw_ventas |
|-----|----------------|-------------|---------------|-----------------|-------------|------------|
| r_administrador | SELECT | SELECT | SELECT (todo) | SELECT | SELECT | SELECT |
| r_gerencia | SELECT | SELECT | SELECT (sin password_hash) | SELECT | SELECT | SELECT |
| r_auditor | SELECT | SELECT | SELECT (sin password_hash) | SELECT | SELECT | SELECT |

### 4.5 Probar Accesos Permitidos y Denegados

Para conectarte como un usuario específico en Neon:

```bash
# Acceso permitido: vendedor norte consulta sus pedidos
psql "postgresql://u_vend_norte:Vend_norte_2026@ep-bbbb.neon.tech/neondb?sslmode=require" \
  -c "SELECT count(*) FROM pedidos_norte;"

# Acceso denegado: vendedor norte intenta ver pedidos del sur
psql "postgresql://u_vend_norte:Vend_norte_2026@ep-bbbb.neon.tech/neondb?sslmode=require" \
  -c "SELECT count(*) FROM pedidos_sur;"
-- ERROR: permission denied for table pedidos_sur

# Acceso permitido: auditor consulta inventarios
psql "postgresql://u_auditor:Auditor_2026@ep-zzzz.neon.tech/neondb?sslmode=require" \
  -c "SELECT count(*) FROM inventarios;"

# Acceso denegado: auditor intenta modificar
psql "postgresql://u_auditor:Auditor_2026@ep-zzzz.neon.tech/neondb?sslmode=require" \
  -c "UPDATE inventarios SET existencia_actual = 0 WHERE id_producto = 1;"
-- ERROR: permission denied for table inventarios
```

> **Nota Neon:** Para que los usuarios de prueba puedan conectarse, es necesario que el endpoint del proyecto permita conexiones de roles adicionales. En el plan Free de Neon esto funciona directamente.

---

## 5. Configurar Reportes (FDW entre proyectos Neon)

Antes de ejecutar `06_reportes_neon.sql`, editar los placeholders:

### 5.1 Hosts de los servidores foráneos

Busca las líneas con `<<HOST_xxx>>` y pon el host real de cada proyecto:

```sql
-- Ejemplo: si empresa-catalogo tiene host ep-cool-rain-123456.us-east-2.aws.neon.tech
host '<<HOST_CATALOGO>>'  →  host 'ep-cool-rain-123456.us-east-2.aws.neon.tech'
```

### 5.2 Credenciales de User Mapping

Busca las líneas con `<<USER_xxx>>` y `<<PASSWORD_xxx>>`:

```sql
OPTIONS (user '<<USER_CATALOGO>>', password '<<PASSWORD_CATALOGO>>')
-- Se convierte en:
OPTIONS (user 'neondb_owner', password 'tu-password-real-del-proyecto-catalogo')
```

### 5.3 Verificar que funciona

```sql
-- Conectado a empresa-reportes:
SELECT * FROM vista_reporte_corporativo;
SELECT * FROM vista_alertas_reabastecimiento LIMIT 10;
SELECT * FROM vista_ventas_mensuales_por_sede;
```

---

## 6. Diferencias clave vs. entorno local

| Aspecto | Local (PostgreSQL) | Neon |
|---|---|---|
| Aislamiento | 6 DBs en 1 clúster | 6 proyectos independientes |
| Roles | Globales al clúster (se crean 1 vez) | Locales por proyecto (se crean en cada uno con `00_roles_neon.sql`) |
| Usuarios de prueba | 12 usuarios, se conectan con `\c` | 12 usuarios, se conectan por connection string con su password |
| FDW | `dbname` local sin host | Host remoto + SSL + credenciales |
| Nombre de la DB | empresa_catalogo, etc. | `neondb` (nombre por defecto en Neon) |
| Conexión | `\c empresa_catalogo` | Connection string individual |
| `REVOKE ON DATABASE` | Funciona | No aplica (Neon gestiona acceso por proyecto) |
| `GRANT CONNECT` | Necesario | No aplica (acceso vía connection string) |

---

## 7. Alternativa: SQL Editor de Neon (sin psql)

Si no tienes `psql` instalado, puedes ejecutar los scripts desde el navegador:

1. Abre el [dashboard de Neon](https://console.neon.tech)
2. Selecciona el proyecto (ej: empresa-catalogo)
3. Ve a **SQL Editor** en el menú lateral
4. Pega primero el contenido de `00_roles_neon.sql` → **Run**
5. Pega el contenido de `01_catalogo_neon.sql` → **Run**
6. Repite para cada proyecto

---

## 8. Troubleshooting

### "permission denied for foreign-data wrapper postgres_fdw"
Neon habilita `postgres_fdw` por defecto, pero asegúrate de conectarte como `neondb_owner` al proyecto de reportes.

### "could not connect to server" en FDW
Verifica host, usuario y password en `CREATE SERVER` y `CREATE USER MAPPING`. Los endpoints de Neon se suspenden tras inactividad; la primera consulta FDW puede tardar unos segundos en despertar.

### "relation does not exist" en las vistas de reportes
Ejecutar los 5 scripts operativos **antes** de `06_reportes_neon.sql`. El `IMPORT FOREIGN SCHEMA` necesita que las tablas ya existan.

### "role already exists"
El script `00_roles_neon.sql` es idempotente (usa `IF NOT EXISTS`). Si ves este mensaje, es seguro ignorarlo.

### pgcrypto en empresa-identidad
Neon soporta `pgcrypto` de forma nativa. El `CREATE EXTENSION IF NOT EXISTS pgcrypto` funciona sin problemas.

### Usuarios de prueba no pueden conectarse
En Neon, los roles creados con `CREATE ROLE ... LOGIN` pueden conectarse usando la connection string del proyecto, reemplazando `neondb_owner` por el nombre del usuario. Ejemplo:
```
postgresql://u_vend_norte:Vend_norte_2026@ep-bbbb.neon.tech/neondb?sslmode=require
```
