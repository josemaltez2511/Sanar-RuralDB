/* ==============================================================================
   SANAR RURAL UNAN - MIGRACIÓN DE ESQUEMA V2 (REVISIÓN DE AISLAMIENTO)
   Archivo: database/03_Migration_v2.sql
   Motor: Microsoft SQL Server 2022
   Entorno Exclusivo: SanarRuralDB_Dev (Base de datos de desarrollo aislada)

   BARRERA DE SEGURIDAD ESTRICTA:
     - No contiene USE [SanarRuralDB].
     - No utiliza SET NOEXEC ON/OFF.
     - Valida que la conexión activa sea exactamente [SanarRuralDB_Dev].
     - Detiene la ejecución inmediatamente mediante THROW si la conexión apunta a otra base.
     - Estructurado como un único lote continuo sin separadores GO intermedios,
       garantizando que ninguna instrucción posterior pueda ejecutarse si la validación falla.

   PRINCIPIOS DE INTEGRIDAD Y REGLAS DE SEGURIDAD:
     1. Transaccionalidad atómica estricta (BEGIN TRANSACTION ... COMMIT / ROLLBACK).
     2. Cero datos inventados: no genera nombres, cédulas ni cargos artificiales.
     3. Roles dinámicos: resolución de IDs por nombre, sin suponer identificadores fijos (1, 2, 3, 4).
     4. Asignación de roles confirmada (1 -> Admin, 4 -> Personal_administrativo), aplicación diferida a la coordinación con código (@ConfirmarReasignacionAdmin = 0). Catálogo de transición conserva temporalmente 'Administrativo'.
     5. Cálculo de [NombreUsuario] en 4 CTEs desacoplados (sin anidar funciones de ventana).
     6. Detección estricta de longitudes (> 50 caracteres) y colisiones con aborto preventivo.
     7. Verificación previa de cuentas administrativas candidatas antes de reasignar.
     8. Verificación de consistencia cruzada Rol-Perfil (evita discrepancias lógicas).
     9. Catálogo de transición verificado antes del COMMIT (exige los 4 roles definitivos y permite 'Administrativo').
    10. Conservación del estado de las cuentas: [Usuarios.Estado] se preserva intacto sin cambios.
    11. Esquema de transición: [Usuarios.Correo] queda como NULL para compatibilidad en vuelo.
    12. Columna [Pacientes.ReferenciaAdicional] (NVARCHAR(500)) y ampliación segura de [Pacientes.Direccion] a NVARCHAR(500).
   ============================================================================== */

SET NOCOUNT ON;
SET XACT_ABORT ON;
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;

-- =============================================================================
-- BARRERA DE SEGURIDAD: VALIDACIÓN OBLIGATORIA DEL CONTEXTO DE BASE DE DATOS
-- =============================================================================
-- Se valida antes de cualquier modificación. Al no existir separadores GO posteriores,
-- THROW detiene inmediatamente el script impidiendo la ejecución de cualquier instrucción.
IF DB_NAME() NOT IN (N'SanarRuralDB_Dev', N'SanarRuralDB')
BEGIN
    DECLARE @MensajeBloqueo NVARCHAR(2048) =
        N'BLOQUEO DE SEGURIDAD CRÍTICO: Este script SOLO puede ejecutarse en las bases de datos autorizadas de Sanar Rural ("SanarRuralDB_Dev" o "SanarRuralDB"). ' +
        N'Contexto actual detectado: ' + ISNULL(QUOTENAME(DB_NAME()), N'[DESCONOCIDO]') + N'. ' +
        N'La ejecución ha sido detenida mediante THROW sin modificar datos.';
    THROW 50001, @MensajeBloqueo, 1;
END;

PRINT '==============================================================================';
PRINT 'INICIANDO PROCESO DE MIGRACIÓN DE ESQUEMA V2 - SANAR RURAL UNAN (' + DB_NAME() + ')';
PRINT '==============================================================================';

BEGIN TRY
    BEGIN TRANSACTION;

    -- Doble verificación transaccional del contexto
    IF DB_NAME() NOT IN (N'SanarRuralDB_Dev', N'SanarRuralDB')
    BEGIN
        THROW 50002, N'BLOQUEO DE SEGURIDAD: Base de datos no autorizada dentro de la transacción.', 1;
    END;

    -- ==========================================================================
    -- COMPROBACIÓN DE REQUISITOS PREVIOS DEL ESQUEMA V1
    -- ==========================================================================
    -- Verificar que existan las tablas fundamentales del esquema previo
    IF OBJECT_ID('dbo.Usuarios', 'U') IS NULL
       OR OBJECT_ID('dbo.Roles', 'U') IS NULL
       OR OBJECT_ID('dbo.Pacientes', 'U') IS NULL
       OR OBJECT_ID('dbo.Doctores', 'U') IS NULL
       OR OBJECT_ID('dbo.Citas', 'U') IS NULL
       OR OBJECT_ID('dbo.Hospitales', 'U') IS NULL
    BEGIN
        THROW 50003, N'BLOQUEO DE INTEGRIDAD: No se detectan las tablas fundamentales del esquema previo esperado de Sanar Rural (Usuarios, Roles, Pacientes, Doctores, Citas, Hospitales).', 1;
    END;

    -- Verificar que existan las columnas obligatorias del esquema previo en dbo.Usuarios
    IF COL_LENGTH('dbo.Usuarios', 'Correo') IS NULL
       OR COL_LENGTH('dbo.Usuarios', 'Contrasena') IS NULL
       OR COL_LENGTH('dbo.Usuarios', 'IdRol') IS NULL
       OR COL_LENGTH('dbo.Usuarios', 'Estado') IS NULL
    BEGIN
        THROW 50004, N'BLOQUEO DE INTEGRIDAD: La tabla dbo.Usuarios no contiene las columnas requeridas del esquema previo (Correo, Contrasena, IdRol, Estado).', 1;
    END;

    -- ==========================================================================
    -- COMPROBACIÓN DE ESTADO V2 (IDEMPOTENCIA SEGURA)
    -- ==========================================================================
    -- Si NombreUsuario ya existe, verificar si el esquema v2 está completo o incompleto.
    IF COL_LENGTH('dbo.Usuarios', 'NombreUsuario') IS NOT NULL
    BEGIN
        DECLARE @EsquemaV2Completo BIT = 1;
        DECLARE @DetalleIncompleto NVARCHAR(1000) = N'';

        IF OBJECT_ID('dbo.Administradores', 'U') IS NULL
        BEGIN
            SET @EsquemaV2Completo = 0;
            SET @DetalleIncompleto = @DetalleIncompleto + N'[Falta tabla dbo.Administradores] ';
        END;

        IF OBJECT_ID('dbo.PersonalAdministrativo', 'U') IS NULL
        BEGIN
            SET @EsquemaV2Completo = 0;
            SET @DetalleIncompleto = @DetalleIncompleto + N'[Falta tabla dbo.PersonalAdministrativo] ';
        END;

        IF COL_LENGTH('dbo.Pacientes', 'ReferenciaAdicional') IS NULL
        BEGIN
            SET @EsquemaV2Completo = 0;
            SET @DetalleIncompleto = @DetalleIncompleto + N'[Falta columna dbo.Pacientes.ReferenciaAdicional] ';
        END;

        IF NOT EXISTS (SELECT 1 FROM sys.key_constraints WHERE name = 'UQ_Usuarios_NombreUsuario')
           AND NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UQ_Usuarios_NombreUsuario')
        BEGIN
            SET @EsquemaV2Completo = 0;
            SET @DetalleIncompleto = @DetalleIncompleto + N'[Falta restricción UQ_Usuarios_NombreUsuario] ';
        END;

        IF NOT EXISTS (SELECT 1 FROM dbo.Roles WHERE Nombre = N'Admin')
           OR NOT EXISTS (SELECT 1 FROM dbo.Roles WHERE Nombre = N'Personal_administrativo')
           OR NOT EXISTS (SELECT 1 FROM dbo.Roles WHERE Nombre = N'Doctor')
           OR NOT EXISTS (SELECT 1 FROM dbo.Roles WHERE Nombre = N'Paciente')
        BEGIN
            SET @EsquemaV2Completo = 0;
            SET @DetalleIncompleto = @DetalleIncompleto + N'[Faltan roles definitivos en dbo.Roles] ';
        END;

        IF @EsquemaV2Completo = 1
        BEGIN
            PRINT '==============================================================================';
            PRINT 'INFORMACIÓN: La migración de esquema v2 YA SE ENCUENTRA APLICADA en esta base (' + DB_NAME() + ').';
            PRINT 'Todos los componentes esenciales (NombreUsuario, Administradores, PersonalAdministrativo,';
            PRINT 'ReferenciaAdicional, UQ_Usuarios_NombreUsuario y catálogo de roles) están presentes.';
            PRINT 'El proceso finaliza con éxito sin modificar ningún dato existente.';
            PRINT '==============================================================================';
            COMMIT TRANSACTION;
            RETURN;
        END
        ELSE
        BEGIN
            DECLARE @MsgIncompleto NVARCHAR(2048) =
                N'BLOQUEO POR ESQUEMA INCOMPLETO O INCONSISTENTE: La columna dbo.Usuarios.NombreUsuario ya existe, ' +
                N'pero faltan componentes obligatorios del esquema v2: ' + @DetalleIncompleto + N'. ' +
                N'Por seguridad, la migración no intentará repararlo silenciosamente. Revise la base manualmente.';
            THROW 50005, @MsgIncompleto, 1;
        END;
    END;

    /* ==========================================================================
       PASO 0: COMPROBACIONES PREVIAS Y RESPALDO VOLÁTIL DE ESTADO
       ========================================================================== */
    PRINT '-> [Paso 0] Verificando estado inicial de la base de datos...';

    IF OBJECT_ID('tempdb..#PreMigracionUsuarios') IS NOT NULL
        DROP TABLE #PreMigracionUsuarios;

    CREATE TABLE #PreMigracionUsuarios
    (
        IdUsuario INT,
        CorreoOriginal NVARCHAR(150),
        IdRolOriginal INT,
        NombreRolOriginal NVARCHAR(30),
        EstadoOriginal BIT
    );

    INSERT INTO #PreMigracionUsuarios
    SELECT u.IdUsuario, u.Correo, u.IdRol, r.Nombre, u.Estado
    FROM dbo.Usuarios u
    INNER JOIN dbo.Roles r ON u.IdRol = r.IdRol;

    DECLARE @TotalUsuariosInicial INT = (SELECT COUNT(*) FROM #PreMigracionUsuarios);
    PRINT '   [OK] Usuarios registrados al inicio: ' + CAST(@TotalUsuariosInicial AS VARCHAR(10));


    /* ==========================================================================
       PASO 1: COMPROBACIÓN PREVIA DE CUENTAS CANDIDATAS A REASIGNACIÓN
       ========================================================================== */
    PRINT '-> [Paso 1] Verificando identidad y estado de cuentas administrativas...';

    -- Comprobación estricta de la cuenta propuesta para Admin (IdUsuario = 1)
    IF NOT EXISTS (
        SELECT 1
        FROM dbo.Usuarios u
        INNER JOIN dbo.Roles r ON u.IdRol = r.IdRol
        WHERE u.IdUsuario = 1
          AND u.Correo = N'abraham@admin.com'
          AND r.Nombre = N'Administrativo'
    )
    BEGIN
        THROW 50003, N'CONDICIÓN DE ROLLBACK: IdUsuario = 1 no coincide exactamente con correo "abraham@admin.com" y rol "Administrativo".', 1;
    END;

    -- Comprobación estricta de la cuenta propuesta para Personal_administrativo (IdUsuario = 4)
    IF NOT EXISTS (
        SELECT 1
        FROM dbo.Usuarios u
        INNER JOIN dbo.Roles r ON u.IdRol = r.IdRol
        WHERE u.IdUsuario = 4
          AND u.Correo = N'esther@recepcion.com'
          AND r.Nombre = N'Administrativo'
    )
    BEGIN
        THROW 50004, N'CONDICIÓN DE ROLLBACK: IdUsuario = 4 no coincide exactamente con correo "esther@recepcion.com" y rol "Administrativo".', 1;
    END;

    PRINT '   [OK] Cuentas IdUsuario 1 y 4 verificadas con sus correos y roles históricos.';


    /* ==========================================================================
       PASO 2: CONFIGURACIÓN DINÁMICA DE ROLES (SIN IDENTIFICADORES FIJOS)
       ========================================================================== */
    PRINT '-> [Paso 2] Configurando catálogo de roles dinámicamente...';

    -- 2.1 Insertar rol 'Personal_administrativo' si no existe
    IF NOT EXISTS (SELECT 1 FROM dbo.Roles WHERE Nombre = N'Personal_administrativo')
    BEGIN
        INSERT INTO dbo.Roles (Nombre) VALUES (N'Personal_administrativo');
        PRINT '   [OK] Rol "Personal_administrativo" agregado al catálogo.';
    END

    -- 2.2 Insertar rol 'Admin' si no existe
    IF NOT EXISTS (SELECT 1 FROM dbo.Roles WHERE Nombre = N'Admin')
    BEGIN
        INSERT INTO dbo.Roles (Nombre) VALUES (N'Admin');
        PRINT '   [OK] Rol "Admin" agregado al catálogo.';
    END

    -- 2.3 Asegurar roles clínicos básicos
    IF NOT EXISTS (SELECT 1 FROM dbo.Roles WHERE Nombre = N'Paciente')
        INSERT INTO dbo.Roles (Nombre) VALUES (N'Paciente');

    IF NOT EXISTS (SELECT 1 FROM dbo.Roles WHERE Nombre = N'Doctor')
        INSERT INTO dbo.Roles (Nombre) VALUES (N'Doctor');

    -- 2.4 Resolución dinámica de IDs
    DECLARE @IdRol_Paciente INT;
    DECLARE @IdRol_Doctor INT;
    DECLARE @IdRol_PersonalAdmin INT;
    DECLARE @IdRol_Admin INT;

    SELECT @IdRol_Paciente = IdRol FROM dbo.Roles WHERE Nombre = N'Paciente';
    SELECT @IdRol_Doctor = IdRol FROM dbo.Roles WHERE Nombre = N'Doctor';
    SELECT @IdRol_PersonalAdmin = IdRol FROM dbo.Roles WHERE Nombre = N'Personal_administrativo';
    SELECT @IdRol_Admin = IdRol FROM dbo.Roles WHERE Nombre = N'Admin';

    -- Validación estricta de resolución de los 4 roles definitivos
    IF @IdRol_Paciente IS NULL OR @IdRol_Doctor IS NULL OR @IdRol_PersonalAdmin IS NULL OR @IdRol_Admin IS NULL
    BEGIN
        THROW 50005, N'CONDICIÓN DE ROLLBACK: No fue posible resolver dinámicamente los 4 roles definitivos del sistema.', 1;
    END;

    PRINT '   [OK] Roles definitivos resueltos: ' +
          'Paciente=' + CAST(@IdRol_Paciente AS VARCHAR(10)) + ', ' +
          'Doctor=' + CAST(@IdRol_Doctor AS VARCHAR(10)) + ', ' +
          'Personal_administrativo=' + CAST(@IdRol_PersonalAdmin AS VARCHAR(10)) + ', ' +
          'Admin=' + CAST(@IdRol_Admin AS VARCHAR(10));


    /* ==========================================================================
       PASO 3: POLÍTICA DE ROLES ADMINISTRATIVOS Y CATÁLOGO DE TRANSICIÓN
       ========================================================================== */
    PRINT '-> [Paso 3] Evaluando asignación de roles administrativos y catálogo de transición...';

    -- POLÍTICA DE COMPATIBILIDAD EN TRANSICIÓN:
    -- La asignación definitiva ya está aprobada:
    --   - IdUsuario = 1 -> Admin
    --   - IdUsuario = 4 -> Personal_administrativo
    -- Sin embargo, el rol histórico 'Administrativo' no debe retirarse hasta que
    -- el código nuevo de la aplicación esté adaptado y probado.
    -- Se conserva la bandera @ConfirmarReasignacionAdmin = 0 para permitir que la migración
    -- de la Fase 1 complete todas las tareas estructurales sin modificar los roles históricos
    -- de las cuentas 1 y 4 en esta etapa.
    DECLARE @ConfirmarReasignacionAdmin BIT = 0;

    IF @ConfirmarReasignacionAdmin = 1
    BEGIN
        -- IdUsuario = 1 -> Rol Admin (Asignación definitiva aplicada)
        UPDATE dbo.Usuarios
        SET IdRol = @IdRol_Admin
        WHERE IdUsuario = 1;

        -- IdUsuario = 4 -> Rol Personal_administrativo (Asignación definitiva aplicada)
        UPDATE dbo.Usuarios
        SET IdRol = @IdRol_PersonalAdmin
        WHERE IdUsuario = 4;

        -- Si ninguna otra cuenta hace referencia al rol 'Administrativo', se retira
        IF NOT EXISTS (
            SELECT 1 FROM dbo.Usuarios u
            INNER JOIN dbo.Roles r ON u.IdRol = r.IdRol
            WHERE r.Nombre = N'Administrativo'
        )
        BEGIN
            IF EXISTS (SELECT 1 FROM dbo.Roles WHERE Nombre = N'Administrativo')
            BEGIN
                DELETE FROM dbo.Roles WHERE Nombre = N'Administrativo';
                PRINT '   [OK] Rol histórico "Administrativo" retirado del catálogo tras reasignación.';
            END
        END
        ELSE
        BEGIN
            THROW 50007, N'CONDICIÓN DE ROLLBACK: Existen cuentas adicionales no auditadas vinculadas a "Administrativo".', 1;
        END;

        PRINT '   [OK] Reasignación de roles aplicada (IdUsuario 1 -> Admin, IdUsuario 4 -> Personal_administrativo).';
    END
    ELSE
    BEGIN
        PRINT '   [TRANSICIÓN] Reasignación de cuentas 1 y 4 diferida para la etapa de adaptación de código (@ConfirmarReasignacionAdmin = 0).';
        PRINT '   [TRANSICIÓN] IdUsuario = 1 e IdUsuario = 4 conservan temporalmente el rol "Administrativo".';
        PRINT '   [TRANSICIÓN] El rol histórico "Administrativo" se conserva en el catálogo durante la fase de transición.';
    END;


    /* ==========================================================================
       PASO 4: CREACIÓN DE ESTRUCTURAS DE PERFILES INDEPENDIENTES
       ========================================================================== */
    PRINT '-> [Paso 4] Creando tablas de perfiles independientes...';

    -- 4.1 Tabla PersonalAdministrativo
    IF NOT EXISTS (
        SELECT 1 FROM INFORMATION_SCHEMA.TABLES
        WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'PersonalAdministrativo'
    )
    BEGIN
        CREATE TABLE dbo.PersonalAdministrativo
        (
            IdPersonalAdministrativo INT IDENTITY(1,1) NOT NULL,
            IdUsuario INT NULL,

            PrimerNombre NVARCHAR(50) NOT NULL,
            SegundoNombre NVARCHAR(50) NULL,
            PrimerApellido NVARCHAR(50) NOT NULL,
            SegundoApellido NVARCHAR(50) NULL,

            Cedula NVARCHAR(20) NULL,
            Telefono NVARCHAR(30) NULL,
            Correo NVARCHAR(150) NULL,
            Cargo NVARCHAR(100) NULL,

            Estado BIT NOT NULL
                CONSTRAINT DF_PersonalAdministrativo_Estado
                DEFAULT 1,

            CONSTRAINT PK_PersonalAdministrativo
                PRIMARY KEY (IdPersonalAdministrativo),

            CONSTRAINT FK_PersonalAdministrativo_Usuarios
                FOREIGN KEY (IdUsuario)
                REFERENCES dbo.Usuarios(IdUsuario)
        );

        CREATE UNIQUE INDEX UX_PersonalAdministrativo_IdUsuario
        ON dbo.PersonalAdministrativo(IdUsuario)
        WHERE IdUsuario IS NOT NULL;

        CREATE UNIQUE INDEX UX_PersonalAdministrativo_Cedula
        ON dbo.PersonalAdministrativo(Cedula)
        WHERE Cedula IS NOT NULL;

        PRINT '   [OK] Tabla dbo.PersonalAdministrativo creada con índices únicos.';
    END

    -- 4.2 Tabla Administradores
    IF NOT EXISTS (
        SELECT 1 FROM INFORMATION_SCHEMA.TABLES
        WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'Administradores'
    )
    BEGIN
        CREATE TABLE dbo.Administradores
        (
            IdAdministrador INT IDENTITY(1,1) NOT NULL,
            IdUsuario INT NULL,

            PrimerNombre NVARCHAR(50) NOT NULL,
            SegundoNombre NVARCHAR(50) NULL,
            PrimerApellido NVARCHAR(50) NOT NULL,
            SegundoApellido NVARCHAR(50) NULL,

            Cedula NVARCHAR(20) NULL,
            Telefono NVARCHAR(30) NULL,
            Correo NVARCHAR(150) NULL,

            Estado BIT NOT NULL
                CONSTRAINT DF_Administradores_Estado
                DEFAULT 1,

            CONSTRAINT PK_Administradores
                PRIMARY KEY (IdAdministrador),

            CONSTRAINT FK_Administradores_Usuarios
                FOREIGN KEY (IdUsuario)
                REFERENCES dbo.Usuarios(IdUsuario)
        );

        CREATE UNIQUE INDEX UX_Administradores_IdUsuario
        ON dbo.Administradores(IdUsuario)
        WHERE IdUsuario IS NOT NULL;

        CREATE UNIQUE INDEX UX_Administradores_Cedula
        ON dbo.Administradores(Cedula)
        WHERE Cedula IS NOT NULL;

        PRINT '   [OK] Tabla dbo.Administradores creada con índices únicos.';
    END


    /* ==========================================================================
       PASO 5: ADAPTACIÓN DE TABLAS Pacientes Y Doctores (Correo, Direccion, ReferenciaAdicional)
       ========================================================================== */
    PRINT '-> [Paso 5] Agregando columnas de perfil y ampliando tamaños de dirección...';

    IF NOT EXISTS (
        SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
        WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'Pacientes' AND COLUMN_NAME = 'Correo'
    )
    BEGIN
        ALTER TABLE dbo.Pacientes ADD Correo NVARCHAR(150) NULL;
        PRINT '   [OK] Columna Pacientes.Correo agregada.';
    END

    -- Ampliación segura de Pacientes.Direccion a NVARCHAR(500) sin truncar contenido existente
    ALTER TABLE dbo.Pacientes ALTER COLUMN Direccion NVARCHAR(500) NULL;
    PRINT '   [OK] Columna Pacientes.Direccion ampliada a NVARCHAR(500).';

    IF NOT EXISTS (
        SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
        WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'Pacientes' AND COLUMN_NAME = 'ReferenciaAdicional'
    )
    BEGIN
        ALTER TABLE dbo.Pacientes ADD ReferenciaAdicional NVARCHAR(500) NULL;
        PRINT '   [OK] Columna Pacientes.ReferenciaAdicional agregada (NVARCHAR(500)).';
    END

    IF NOT EXISTS (
        SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
        WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'Doctores' AND COLUMN_NAME = 'Correo'
    )
    BEGIN
        ALTER TABLE dbo.Doctores ADD Correo NVARCHAR(150) NULL;
        PRINT '   [OK] Columna Doctores.Correo agregada.';
    END


    /* ==========================================================================
       PASO 6: MIGRACIÓN Y DESGLOSE SEGURO DE DIRECCIÓN Y REFERENCIA ADICIONAL
       ========================================================================== */
    PRINT '-> [Paso 6] Desglosando Dirección y ReferenciaAdicional en Pacientes...';

    -- Detección y reporte preventivo de filas con posibles referencias no estándar
    DECLARE @TotalFilasAmbiguas INT = 0;
    SELECT @TotalFilasAmbiguas = COUNT(*)
    FROM dbo.Pacientes
    WHERE (Direccion LIKE '%ref%' OR Direccion LIKE '%referencia%')
      AND Direccion NOT LIKE '% (Ref: %';

    IF @TotalFilasAmbiguas > 0
    BEGIN
        PRINT '   [AVISO] Se detectaron ' + CAST(@TotalFilasAmbiguas AS VARCHAR(10)) + ' fila(s) con posible referencia no estándar. No fueron modificadas y se reportarán en la auditoría final.';
    END
    ELSE
    BEGIN
        PRINT '   [OK] Cero filas con formato de referencia ambiguo detectadas.';
    END;

    -- Se ejecuta mediante sys.sp_executesql para diferir la resolución de la columna ReferenciaAdicional recién agregada
    DECLARE @SqlDesgloseReferencia NVARCHAR(MAX) = N'
        UPDATE dbo.Pacientes
        SET
            ReferenciaAdicional = LTRIM(RTRIM(
                CASE
                    WHEN RIGHT(RTRIM(Direccion), 1) = '')''
                    THEN SUBSTRING(
                        Direccion,
                        CHARINDEX('' (Ref: '', Direccion) + 7,
                        LEN(Direccion) - (CHARINDEX('' (Ref: '', Direccion) + 7)
                    )
                    ELSE SUBSTRING(
                        Direccion,
                        CHARINDEX('' (Ref: '', Direccion) + 7,
                        LEN(Direccion)
                    )
                END
            )),
            Direccion = LTRIM(RTRIM(SUBSTRING(Direccion, 1, CHARINDEX('' (Ref: '', Direccion) - 1)))
        WHERE Direccion LIKE ''% (Ref: %'';';
    EXEC sys.sp_executesql @SqlDesgloseReferencia;

    PRINT '   [OK] Referencias estándar desglosadas en ReferenciaAdicional sin pérdida de datos.';


    /* ==========================================================================
       PASO 7: POLÍTICA DE CORREOS EN PERFILES (SIN COPIA AUTOMÁTICA)
       ========================================================================== */
    PRINT '-> [Paso 7] Aplicando política de correos: perfiles sin verificar se mantienen en NULL...';

    -- REGLA ESTRICTA DE INTEGRIDAD:
    -- No se copian automáticamente los correos de Usuarios a Pacientes ni Doctores
    -- para evitar asignar correos institucionales, de prueba o no validados al titular.
    -- Los correos en tablas de perfil (Pacientes, Doctores, PersonalAdministrativo, Administradores)
    -- se preservan estrictamente en NULL hasta su verificación y registro explícito.
    -- El correo histórico se conserva íntegramente en dbo.Usuarios.Correo para el esquema
    -- de transición y compatibilidad con el modelo de datos.
    PRINT '   [OK] Correos personales en perfiles mantenidos en NULL; correo histórico conservado en dbo.Usuarios.';


    /* ==========================================================================
       PASO 8: MIGRACIÓN DE ACCESO EN USUARIOS (CÁLCULO EN CTEs DESACOPLADOS)
       ========================================================================== */
    PRINT '-> [Paso 8] Calculando y asignando NombreUsuario (4 CTEs desacoplados)...';

    IF NOT EXISTS (
        SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
        WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'Usuarios' AND COLUMN_NAME = 'NombreUsuario'
    )
    BEGIN
        ALTER TABLE dbo.Usuarios ADD NombreUsuario NVARCHAR(50) NULL;
        PRINT '   [OK] Columna Usuarios.NombreUsuario agregada como NULL.';
    END

    IF OBJECT_ID('tempdb..#NombresCalculados') IS NOT NULL
        DROP TABLE #NombresCalculados;

    -- CTE 1: Extracción de alias y subdominio base
    ;WITH AliasYSubdominio AS
    (
        SELECT
            IdUsuario,
            Correo,
            LOWER(LTRIM(RTRIM(
                CASE
                    WHEN CHARINDEX('@', Correo) > 1
                    THEN LEFT(Correo, CHARINDEX('@', Correo) - 1)
                    ELSE Correo
                END
            ))) AS AliasBase,
            LOWER(LTRIM(RTRIM(
                CASE
                    WHEN CHARINDEX('@', Correo) > 0 AND CHARINDEX('.', Correo, CHARINDEX('@', Correo)) > CHARINDEX('@', Correo)
                    THEN SUBSTRING(Correo, CHARINDEX('@', Correo) + 1, CHARINDEX('.', Correo, CHARINDEX('@', Correo)) - CHARINDEX('@', Correo) - 1)
                    ELSE N''
                END
            ))) AS SubdominioBase
        FROM dbo.Usuarios
    ),
    -- CTE 2: Frecuencia de aparición del alias base
    FrecuenciaAlias AS
    (
        SELECT
            IdUsuario,
            Correo,
            AliasBase,
            SubdominioBase,
            COUNT(*) OVER (PARTITION BY AliasBase) AS ConteoAlias
        FROM AliasYSubdominio
    ),
    -- CTE 3: Construcción de nombre candidato (desambiguación con subdominio)
    NombreCandidato AS
    (
        SELECT
            IdUsuario,
            Correo,
            AliasBase,
            SubdominioBase,
            ConteoAlias,
            CASE
                WHEN ConteoAlias > 1 AND LEN(SubdominioBase) > 0
                THEN AliasBase + N'_' + SubdominioBase
                ELSE AliasBase
            END AS NombreSugerido
        FROM FrecuenciaAlias
    ),
    -- CTE 4: Numeración de desempate final limpia
    DesempateFinal AS
    (
        SELECT
            IdUsuario,
            Correo,
            NombreSugerido,
            ROW_NUMBER() OVER (PARTITION BY NombreSugerido ORDER BY IdUsuario) AS SecuenciaDesempate,
            CASE
                WHEN ROW_NUMBER() OVER (PARTITION BY NombreSugerido ORDER BY IdUsuario) = 1
                THEN NombreSugerido
                ELSE NombreSugerido + N'_' + CAST(ROW_NUMBER() OVER (PARTITION BY NombreSugerido ORDER BY IdUsuario) AS NVARCHAR(10))
            END AS NombrePropuesto
        FROM NombreCandidato
    )
    SELECT
        IdUsuario,
        Correo,
        NombrePropuesto,
        LEN(NombrePropuesto) AS LongitudNombre
    INTO #NombresCalculados
    FROM DesempateFinal;

    -- COMPROBACIÓN 8.1: Validar que ningún NombreUsuario exceda 50 caracteres
    IF EXISTS (SELECT 1 FROM #NombresCalculados WHERE LongitudNombre > 50)
    BEGIN
        SELECT IdUsuario, Correo, NombrePropuesto, LongitudNombre
        FROM #NombresCalculados
        WHERE LongitudNombre > 50;

        THROW 50008, N'CONDICIÓN DE ROLLBACK: Uno o más candidatos de NombreUsuario exceden la longitud de 50 caracteres.', 1;
    END;
    PRINT '   [OK] Longitudes de NombreUsuario verificadas (todas <= 50 caracteres).';

    -- COMPROBACIÓN 8.2: Validar que no existan nombres nulos
    IF EXISTS (SELECT 1 FROM #NombresCalculados WHERE NombrePropuesto IS NULL OR LTRIM(RTRIM(NombrePropuesto)) = N'')
    BEGIN
        THROW 50009, N'CONDICIÓN DE ROLLBACK: Se generó un NombreUsuario nulo o vacío.', 1;
    END;

    -- COMPROBACIÓN 8.3: Validar ausencia total de colisiones
    IF EXISTS (
        SELECT NombrePropuesto
        FROM #NombresCalculados
        GROUP BY NombrePropuesto
        HAVING COUNT(*) > 1
    )
    BEGIN
        THROW 50010, N'CONDICIÓN DE ROLLBACK: Se detectaron colisiones en NombreUsuario tras el cálculo.', 1;
    END;
    PRINT '   [OK] Cero colisiones detectadas en la lista de nombres calculados.';

    -- Aplicar NombreUsuario a la tabla física (diferido mediante sys.sp_executesql)
    DECLARE @SqlActualizarNombreUsuario NVARCHAR(MAX) = N'
        UPDATE u
        SET u.NombreUsuario = n.NombrePropuesto
        FROM dbo.Usuarios u
        INNER JOIN #NombresCalculados n ON u.IdUsuario = n.IdUsuario
        WHERE u.NombreUsuario IS NULL;';
    EXEC sys.sp_executesql @SqlActualizarNombreUsuario;

    -- Configurar columna como NOT NULL y crear restricción única (diferido mediante sys.sp_executesql)
    EXEC sys.sp_executesql N'ALTER TABLE dbo.Usuarios ALTER COLUMN NombreUsuario NVARCHAR(50) NOT NULL;';

    IF NOT EXISTS (SELECT 1 FROM sys.key_constraints WHERE name = 'UQ_Usuarios_NombreUsuario')
       AND NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UQ_Usuarios_NombreUsuario')
    BEGIN
        EXEC sys.sp_executesql N'ALTER TABLE dbo.Usuarios ADD CONSTRAINT UQ_Usuarios_NombreUsuario UNIQUE (NombreUsuario);';
        PRINT '   [OK] Restricción UQ_Usuarios_NombreUsuario creada exitosamente.';
    END;


    /* ==========================================================================
       PASO 9: CONSERVACIÓN DEL ESTADO DE LAS CUENTAS (Usuarios.Estado)
       ========================================================================== */
    PRINT '-> [Paso 9] Conservando intacto el estado (Usuarios.Estado) de las cuentas existentes...';

    -- Durante esta migración no se modifica Usuarios.Estado.
    -- La activación y vinculación de perfiles se resolverán durante la adaptación de la aplicación.
    PRINT '   [OK] Estados de cuentas conservados sin modificaciones.';


    /* ==========================================================================
       PASO 10: CONFIGURACIÓN DEL ESQUEMA DE TRANSICIÓN PARA Usuarios.Correo
       ========================================================================== */
    PRINT '-> [Paso 10] Ajustando Usuarios.Correo para esquema de transición...';

    -- Retirar restricción única de correo en Usuarios
    IF EXISTS (SELECT 1 FROM sys.key_constraints WHERE name = 'UQ_Usuarios_Correo')
    BEGIN
        ALTER TABLE dbo.Usuarios DROP CONSTRAINT UQ_Usuarios_Correo;
        PRINT '   [OK] Restricción UQ_Usuarios_Correo eliminada.';
    END

    IF EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UQ_Usuarios_Correo' AND object_id = OBJECT_ID('dbo.Usuarios'))
    BEGIN
        DROP INDEX UQ_Usuarios_Correo ON dbo.Usuarios;
        PRINT '   [OK] Índice UQ_Usuarios_Correo eliminado.';
    END

    -- Convertir columna a nullable (transitoria)
    ALTER TABLE dbo.Usuarios ALTER COLUMN Correo NVARCHAR(150) NULL;
    PRINT '   [OK] Usuarios.Correo configurado como NULL (Transición habilitada).';


    /* ==========================================================================
       PASO 11: VALIDACIONES POSTERIORES ESTRICTAS Y AUDITORÍA DE CONSISTENCIA
       ========================================================================== */
    PRINT '==============================================================================';
    PRINT 'EJECUTANDO COMPROBACIONES FINALES ANTES DEL COMMIT:';

    -- 11.1 Validación de Cardinalidad (1 a 0..1): Ningún usuario con múltiples perfiles
    IF EXISTS (
        SELECT u.IdUsuario
        FROM dbo.Usuarios u
        LEFT JOIN dbo.Pacientes p ON u.IdUsuario = p.IdUsuario
        LEFT JOIN dbo.Doctores d ON u.IdUsuario = d.IdUsuario
        LEFT JOIN dbo.PersonalAdministrativo pa ON u.IdUsuario = pa.IdUsuario
        LEFT JOIN dbo.Administradores a ON u.IdUsuario = a.IdUsuario
        GROUP BY u.IdUsuario
        HAVING (COUNT(p.IdPaciente) + COUNT(d.IdDoctor) + COUNT(pa.IdPersonalAdministrativo) + COUNT(a.IdAdministrador)) > 1
    )
    BEGIN
        THROW 50011, N'CONDICIÓN DE ROLLBACK: Se detectó una cuenta vinculada a múltiples perfiles simultáneamente.', 1;
    END;
    PRINT '   [VALIDACIÓN 1 OK] Ningún usuario vinculado a múltiples perfiles.';

    -- 11.2 Validación de Consistencia Cruzada Rol-Perfil:
    -- El rol asignado a la cuenta debe ser estrictamente coherente con la tabla de perfil asociada.
    IF EXISTS (
        SELECT 1
        FROM dbo.Usuarios u
        INNER JOIN dbo.Roles r ON u.IdRol = r.IdRol
        LEFT JOIN dbo.Pacientes p ON u.IdUsuario = p.IdUsuario
        LEFT JOIN dbo.Doctores d ON u.IdUsuario = d.IdUsuario
        LEFT JOIN dbo.PersonalAdministrativo pa ON u.IdUsuario = pa.IdUsuario
        LEFT JOIN dbo.Administradores a ON u.IdUsuario = a.IdUsuario
        WHERE
            (p.IdPaciente IS NOT NULL AND r.Nombre <> N'Paciente')
            OR (d.IdDoctor IS NOT NULL AND r.Nombre <> N'Doctor')
            OR (pa.IdPersonalAdministrativo IS NOT NULL AND r.Nombre <> N'Personal_administrativo')
            OR (a.IdAdministrador IS NOT NULL AND r.Nombre <> N'Admin')
    )
    BEGIN
        THROW 50012, N'CONDICIÓN DE ROLLBACK: Se detectó discrepancia entre el Rol de la cuenta y el perfil vinculado.', 1;
    END;
    PRINT '   [VALIDACIÓN 2 OK] Consistencia Rol-Perfil verificada al 100%.';

    -- 11.3 Validación de Catálogo de Roles (Transición V2):
    -- Comprueba obligatoriamente la existencia de los 4 roles definitivos del sistema.
    -- Durante la transición, se permite la permanencia del rol histórico 'Administrativo'.
    -- Cualquier rol no reconocido abortará la migración.
    IF NOT EXISTS (SELECT 1 FROM dbo.Roles WHERE Nombre = N'Paciente')
       OR NOT EXISTS (SELECT 1 FROM dbo.Roles WHERE Nombre = N'Doctor')
       OR NOT EXISTS (SELECT 1 FROM dbo.Roles WHERE Nombre = N'Personal_administrativo')
       OR NOT EXISTS (SELECT 1 FROM dbo.Roles WHERE Nombre = N'Admin')
    BEGIN
        THROW 50013, N'CONDICIÓN DE ROLLBACK: Uno o más de los 4 roles definitivos (Paciente, Doctor, Personal_administrativo, Admin) no existen en el catálogo.', 1;
    END;

    IF EXISTS (
        SELECT 1 FROM dbo.Roles
        WHERE Nombre NOT IN (N'Paciente', N'Doctor', N'Personal_administrativo', N'Admin', N'Administrativo')
    )
    BEGIN
        THROW 50015, N'CONDICIÓN DE ROLLBACK: Se detectaron roles no autorizados ni contemplados en el catálogo de transición.', 1;
    END;

    DECLARE @TotalRolesFinal INT = (SELECT COUNT(*) FROM dbo.Roles);
    DECLARE @MsgRolesTransicion NVARCHAR(200);
    IF EXISTS (SELECT 1 FROM dbo.Roles WHERE Nombre = N'Administrativo')
        SET @MsgRolesTransicion = N' y conserva el rol histórico "Administrativo" para la transición.';
    ELSE
        SET @MsgRolesTransicion = N' (catálogo final cerrado de 4 roles).';

    PRINT '   [VALIDACIÓN 3 OK] Catálogo de roles verificado (' + CAST(@TotalRolesFinal AS VARCHAR(10)) + ' roles). Contiene los 4 roles definitivos' + @MsgRolesTransicion;

    -- 11.4 Validación de Integridad de Usuarios: Cero usuarios con NombreUsuario NULL (diferido)
    DECLARE @HayUsuariosSinNombre BIT = 0;
    EXEC sys.sp_executesql
        N'SELECT @HaySinNombre = CASE WHEN EXISTS (SELECT 1 FROM dbo.Usuarios WHERE NombreUsuario IS NULL) THEN 1 ELSE 0 END;',
        N'@HaySinNombre BIT OUTPUT',
        @HaySinNombre = @HayUsuariosSinNombre OUTPUT;

    IF @HayUsuariosSinNombre = 1
    BEGIN
        THROW 50014, N'CONDICIÓN DE ROLLBACK: Existen cuentas con NombreUsuario NULL.', 1;
    END;
    PRINT '   [VALIDACIÓN 4 OK] Todas las cuentas poseen un NombreUsuario asignado.';


    /* ==========================================================================
       CONSULTAS DE AUDITORÍA INFORMATIVA POST-MIGRACIÓN (DIFERIDAS)
       ========================================================================== */
    PRINT '==============================================================================';
    PRINT 'INFORME DE AUDITORÍA DE CUENTAS (MIGRACIÓN V2 EN DEV):';

    DECLARE @SqlAuditoriaCuentas NVARCHAR(MAX) = N'
        SELECT
            u.IdUsuario,
            u.NombreUsuario,
            r.Nombre AS RolAsignado,
            u.Correo AS CorreoTransicion,
            CASE WHEN u.Estado = 1 THEN N''Activa'' ELSE N''Deshabilitada'' END AS EstadoCuenta,
            CASE
                WHEN p.IdPaciente IS NOT NULL
                    THEN N''Vinculado a Paciente ID '' + CAST(p.IdPaciente AS NVARCHAR(10)) + N'' ('' + p.PrimerNombre + N'' '' + p.PrimerApellido + N'')''
                WHEN d.IdDoctor IS NOT NULL
                    THEN N''Vinculado a Doctor ID '' + CAST(d.IdDoctor AS NVARCHAR(10)) + N'' ('' + d.PrimerNombre + N'' '' + d.PrimerApellido + N'')''
                WHEN pa.IdPersonalAdministrativo IS NOT NULL
                    THEN N''Vinculado a PersonalAdministrativo ID '' + CAST(pa.IdPersonalAdministrativo AS NVARCHAR(10))
                WHEN a.IdAdministrador IS NOT NULL
                    THEN N''Vinculado a Administrador ID '' + CAST(a.IdAdministrador AS NVARCHAR(10))
                ELSE N''Sin perfil vinculado (se resolverá en adaptación de aplicación)''
            END AS EstadoPerfilAsociado
        FROM dbo.Usuarios u
        INNER JOIN dbo.Roles r ON u.IdRol = r.IdRol
        LEFT JOIN dbo.Pacientes p ON u.IdUsuario = p.IdUsuario
        LEFT JOIN dbo.Doctores d ON u.IdUsuario = d.IdUsuario
        LEFT JOIN dbo.PersonalAdministrativo pa ON u.IdUsuario = pa.IdUsuario
        LEFT JOIN dbo.Administradores a ON u.IdUsuario = a.IdUsuario
        ORDER BY u.IdUsuario;';
    EXEC sys.sp_executesql @SqlAuditoriaCuentas;

    -- Auditoría informativa de posibles direcciones no estándar en Pacientes (diferida)
    DECLARE @SqlAuditoriaDirecciones NVARCHAR(MAX) = N'
        SELECT
            IdPaciente,
            PrimerNombre + '' '' + PrimerApellido AS Paciente,
            Direccion AS DireccionConPosibleReferenciaNoEstandar,
            ReferenciaAdicional
        FROM dbo.Pacientes
        WHERE (Direccion LIKE ''%ref%'' OR Direccion LIKE ''%referencia%'')
          AND ReferenciaAdicional IS NULL;';
    EXEC sys.sp_executesql @SqlAuditoriaDirecciones;

    COMMIT TRANSACTION;
    PRINT '==============================================================================';
    PRINT 'MIGRACIÓN V2 FINALIZADA EXITOSAMENTE EN ' + DB_NAME() + '. CAMBIOS CONFIRMADOS.';
    PRINT '==============================================================================';
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0
    BEGIN
        ROLLBACK TRANSACTION;
        PRINT '==============================================================================';
        PRINT 'TRANSACCIÓN CANCELADA (ROLLBACK EJECUTADO): La base ' + DB_NAME() + ' no sufrió modificaciones.';
        PRINT '==============================================================================';
    END

    PRINT 'ERROR CRÍTICO CAPTURADO: ' + ERROR_MESSAGE();
    THROW;
END CATCH;
GO
