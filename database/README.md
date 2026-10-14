# Scripts de Base de Datos — Sanar Rural UNAN

Este directorio contiene los scripts SQL oficiales para la inicialización, migración y carga de datos de la base de datos de **Sanar Rural** (Microsoft SQL Server 2022).

---

## 1. Inventario de Scripts

| Script | Propósito | Entorno / Momento de Uso |
|---|---|---|
| `01_Schema.sql` | Creación completa del esquema DDL v2 desde cero. | **Exclusivo para bases nuevas o desechables.** Contiene barreras que abortan la ejecución si ya existen tablas de Sanar Rural para prevenir pérdidas accidentales de datos. |
| `02_Seed.sql` | Catálogos maestros de referencia: roles, división político-administrativa completa de Nicaragua (15 departamentos, 2 regiones autónomas y 153 municipios), comunidades representativas, hospitales, especialidades, enfermedades, síntomas, medicamentos y recomendaciones. | Posterior a `01_Schema.sql` o `03_Migration_v2.sql`. **Idempotente**: seguro para ejecutarse múltiples veces. |
| `03_Migration_v2.sql` | Migración incremental y transaccional desde el esquema v1 al esquema v2. | **Bases de datos existentes con datos históricos** (`SanarRuralDB` o `SanarRuralDB_Dev`). Preserva cuentas, citas y consultas existentes. |
| `04_Bootstrap_Admin_Dev.sql` | Alta controlada de la ficha personal del Administrador raíz (`IdUsuario = 1`). | **Requiere autorización explícita**. Mantiene por defecto `@ConfirmarEjecucionBootstrap = 0` y datos en `NULL`. No debe ejecutarse hasta verificar datos reales del titular. |
| `05_Seed_Demo.sql` | Datos semilla integrales de prueba y demostración asistencial (Fase 5). | **Exclusivo para desarrollo y pruebas locales**. Genera datos clínicos ficticios identificables (`demo_*`, `DEMO-*`) con transacciones seguras e idempotentes. |
| `06_Migration_Usuarios_SoloNombreUsuario.sql` | Retiro seguro de la columna transitoria `Usuarios.Correo`, estableciendo exclusividad de `Usuarios.NombreUsuario` para autenticación. | **Posterior a adaptación del código C# y EF.** Valida integridad, ausencia de duplicados y dependencias antes de eliminar la columna. Conserva intactos los correos en tablas de perfiles. |

---

## 2. Guía de Ejecución según el Escenario

### Escenario A: Crear un entorno de desarrollo completamente nuevo desde cero

Si no tienes una base de datos previa o necesitas un entorno local desechable limpio:

1. **Crear la base de datos vacía en SQL Server:**
   ```sql
   CREATE DATABASE SanarRuralDB_Dev;
   ```
2. **Seleccionar el contexto de la base de datos:**
   ```sql
   USE SanarRuralDB_Dev;
   ```
3. **Ejecutar en orden estricto:**
   - `01_Schema.sql` (crea tablas, llaves primarias, foráneas e índices del esquema v2).
   - `02_Seed.sql` (inserta los catálogos base y los 4 roles definitivos + rol histórico).
   - `05_Seed_Demo.sql` (opcional: carga datos ficticios de demostración asistencial).

---

### Escenario B: Actualizar una base de datos existente con esquema previo (v1)

Si tu base de datos ya contiene registros, pacientes, doctores, usuarios o citas creadas previamente:

1. **Realizar un respaldo completo obligatorio (BACKUP):**
   Antes de cualquier migración, es imperativo generar un respaldo de seguridad:
   ```sql
   BACKUP DATABASE [SanarRuralDB_Dev]
   TO DISK = N'C:\Respaldos\SanarRuralDB_Dev_PreV2.bak'
   WITH FORMAT, INIT, NAME = N'Respaldo previo a migracion v2';
   ```
2. **Seleccionar la base de datos correcta (`SanarRuralDB_Dev` o `SanarRuralDB`):**
   Asegúrate de que la conexión activa en SQL Server Management Studio (SSMS) o sqlcmd apunta a la base de desarrollo autorizada. El script valida activamente el contexto y detiene la ejecución si detecta bases no autorizadas o bases del sistema.
3. **Ejecutar la migración:**
   - `03_Migration_v2.sql`:
     - Valida la existencia del esquema v1.
     - Añade tablas de perfiles (`Administradores`, `PersonalAdministrativo`).
     - Añade columnas requeridas (`Pacientes.ReferenciaAdicional`, `Usuarios.NombreUsuario`).
     - Calcula de forma desacoplada los nombres de usuario basados en el correo histórico sin colisiones.
     - Configura `Usuarios.NombreUsuario` como `NOT NULL UNIQUE`.
     - Es transaccional y atómico (en caso de error aplica `ROLLBACK` total).
     - Si la migración ya fue aplicada previamente y el esquema v2 está completo, informa y finaliza sin alterar datos.
4. **Actualizar o verificar catálogos:**
   - Ejecutar `02_Seed.sql` para cargar la división político-administrativa completa de Nicaragua (15 departamentos, 2 regiones autónomas y 153 municipios), los nuevos catálogos clínicos (síntomas, medicamentos esenciales, recomendaciones) y roles definitivos.
5. **Cargar datos de demostración (opcional para desarrollo):**
   - Ejecutar `05_Seed_Demo.sql` si se requieren expedientes y citas de prueba para verificar los módulos.
6. **Migración a exclusividad de NombreUsuario (Fase posterior coordinada):**
   - Ejecutar `06_Migration_Usuarios_SoloNombreUsuario.sql` **únicamente cuando el código C# y el modelo de Entity Framework (`ModelSanarRural.edmx`) hayan sido adaptados** para prescindir de `Usuarios.Correo`.
   - Este script retira la columna `Correo` de `dbo.Usuarios` tras verificar que no existen dependencias activas, conservando intactos los correos personales en las tablas de perfiles (`Pacientes`, `Doctores`, `Administradores`, `PersonalAdministrativo`).

---

## 3. División Político-Administrativa y Limitación Semántica

El catálogo geográfico de `02_Seed.sql` incorpora la totalidad de las entidades territoriales de Nicaragua:
- **17 Divisiones de Primer Nivel:** 15 Departamentos y 2 Regiones Autónomas (`Región Autónoma de la Costa Caribe Norte` y `Región Autónoma de la Costa Caribe Sur`).
- **153 Municipios:** distribuidos en estricta conformidad con la Ley No. 59 de División Política Administrativa y los derroteros oficiales del Instituto Nicaragüense de Estudios Territoriales (INETER) / MINED.
- **Carazo:** Incluye sus 8 municipios oficiales (Jinotepe, Diriamba, Dolores, El Rosario, La Paz de Carazo, La Conquista, San Marcos y Santa Teresa).

> [!NOTE]
> **Limitación Semántica de la Tabla `dbo.Departamentos`:**
> Por diseño histórico del modelo relacional, la tabla se denomina `dbo.Departamentos`, aunque aloja tanto departamentos como las 2 regiones autónomas. Para mantener la estabilidad del esquema y no romper el mapeo de Entity Framework, se preserva el nombre físico de la tabla. Las interfaces de usuario deben rotular el campo selector correspondiente como **«Departamento / Región autónoma»**.

---

## 4. Política sobre `04_Bootstrap_Admin_Dev.sql`

- Este script **NO debe ejecutarse de forma rutinaria ni automática**.
- Su propósito es asignar la ficha de perfil real y habilitar la cuenta de administrador principal creada en esquemas anteriores.
- Viene protegido con una bandera de control:
  ```sql
  DECLARE @ConfirmarEjecucionBootstrap BIT = 0;
  ```
  y campos obligatorios en `NULL` (`@PrimerNombre = NULL`, `@PrimerApellido = NULL`).
- Solo debe ser configurado y ejecutado por el líder técnico una vez verificados los datos oficiales y cuando la aplicación esté en producción/fase final.

---

## 5. Credenciales de Demostración (Uso Exclusivo de Desarrollo)

Los datos generados por `05_Seed_Demo.sql` son puramente ficticios y están concebidos para pruebas funcionales locales:

- **Contraseña universal de demostración:** `SanarRural2026!`
- **Cuentas disponibles:**
  - Administrador: `demo_admin`
  - Personal Administrativo: `demo_personal`
  - Doctor: `demo_doctor`
  - Paciente: `demo_paciente`

> [!WARNING]
> Estas credenciales y datos semilla son exclusivamente para desarrollo, capacitación y pruebas de laboratorio. Queda terminantemente prohibido utilizar estas cuentas o contraseñas en entornos de producción o redes institucionales públicas.
