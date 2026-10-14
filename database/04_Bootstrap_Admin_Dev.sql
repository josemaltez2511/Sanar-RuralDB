/* ==============================================================================
   SANAR RURAL UNAN - BOOTSTRAP DE CUENTA ADMINISTRADOR DE DESARROLLO
   Archivo: database/04_Bootstrap_Admin_Dev.sql
   Motor: Microsoft SQL Server 2022
   ⚠️ ALCANCE Y ORDEN DE EJECUCIÓN (FASE POSTERIOR):
   ------------------------------------------------------------------------------
   - Este script NO FORMA PARTE inmediata de la Fase 1 (Migración de Base de Datos).
   - Queda ESTRICTAMENTE RESERVADO para una fase posterior, en coordinación directa
     con la adaptación del código C# WinForms (cuando la capa de autenticación,
     permisos y perfiles de la aplicación sea plenamente compatible con el rol Admin).
   - Prerrequisito absoluto: que la base de datos SanarRuralDB_Dev haya sido migrada
     exitosamente con database/03_Migration_v2.sql.
   - Propósito: Script controlado y explícito para registrar el perfil personal real
     de la cuenta Admin (IdUsuario = 1) y habilitarla (Estado = 1) una vez aprobada
     la migración e implementado el soporte en la aplicación.
   ============================================================================== */

SET NOCOUNT ON;
SET XACT_ABORT ON;

-- =============================================================================
-- BARRERA DE SEGURIDAD: VALIDACIÓN OBLIGATORIA DEL CONTEXTO DE BASE DE DATOS
-- =============================================================================
-- Se valida antes de cualquier modificación. Al no existir separadores GO posteriores,
-- THROW detiene inmediatamente el script impidiendo la ejecución de cualquier instrucción.
IF DB_NAME() NOT IN (N'SanarRuralDB_Dev', N'SanarRuralDB')
BEGIN
    DECLARE @MensajeBloqueo NVARCHAR(2048) =
        N'BLOQUEO DE SEGURIDAD CRÍTICO: Este script SOLO puede ejecutarse en las bases de datos de desarrollo autorizadas ("SanarRuralDB_Dev" o "SanarRuralDB"). ' +
        N'Contexto actual detectado: ' + ISNULL(QUOTENAME(DB_NAME()), N'[DESCONOCIDO]') + N'. ' +
        N'La ejecución ha sido detenida mediante THROW sin modificar datos.';
    THROW 50001, @MensajeBloqueo, 1;
END;

PRINT '==============================================================================';
PRINT 'INICIANDO BOOTSTRAP CONTROLADO DEL PERFIL DE ADMINISTRADOR (' + DB_NAME() + ')';
PRINT '==============================================================================';

BEGIN TRY
    BEGIN TRANSACTION;

    -- Doble verificación transaccional del contexto
    IF DB_NAME() NOT IN (N'SanarRuralDB_Dev', N'SanarRuralDB')
    BEGIN
        THROW 50002, N'BLOQUEO DE SEGURIDAD: Base de datos no autorizada dentro de la transacción.', 1;
    END;

    -- =========================================================================
    -- BARRERA DE CONFIRMACIÓN EXPRESA
    -- =========================================================================
    -- Mantener en 0. Requiere confirmación explícita antes de ejecutar el bootstrap.
    DECLARE @ConfirmarEjecucionBootstrap BIT = 0;

    IF @ConfirmarEjecucionBootstrap = 0
    BEGIN
        THROW 50003, N'BLOQUEO DE CONTROL: La ejecución del bootstrap está pendiente de confirmación explícita de datos personales. Verifique los parámetros y configure @ConfirmarEjecucionBootstrap = 1 para proceder.', 1;
    END;

    -- =========================================================================
    -- PARÁMETROS DEL ADMINISTRADOR (EDITAR ÚNICAMENTE CON DATOS OFICIALES)
    -- NOTA: PrimerNombre y PrimerApellido son obligatorios y deben verificarse
    --       estrictamente antes de autorizar el bootstrap. Se mantienen en NULL.
    --       Cedula, Telefono y Correo son opcionales (mantener en NULL si no
    --       han sido verificados directamente con el titular).
    -- =========================================================================
    DECLARE @TargetIdUsuario INT = 1;
    DECLARE @PrimerNombre NVARCHAR(50) = NULL;         -- Obligatorio: mantener NULL hasta verificar datos reales
    DECLARE @SegundoNombre NVARCHAR(50) = NULL;         -- Opcional
    DECLARE @PrimerApellido NVARCHAR(50) = NULL;       -- Obligatorio: mantener NULL hasta verificar datos reales
    DECLARE @SegundoApellido NVARCHAR(50) = NULL;       -- Opcional
    DECLARE @Cedula NVARCHAR(20) = NULL;                -- Opcional: ingresar cédula real o mantener NULL
    DECLARE @Telefono NVARCHAR(30) = NULL;              -- Opcional: ingresar teléfono real o mantener NULL
    DECLARE @Correo NVARCHAR(150) = NULL;               -- Opcional: mantener NULL (no registrar correos sin verificar)

    -- =========================================================================
    -- VALIDACIÓN PREVIA DEL ESTADO DEL ESQUEMA (VERIFICACIÓN DE MIGRACIÓN V2)
    -- =========================================================================
    -- Se verifica que la base de datos ya haya completado la migración V2.
    -- Si el esquema aún no cuenta con la tabla Administradores o la columna NombreUsuario,
    -- el script se detiene inmediatamente con un mensaje claro y sin modificaciones.
    IF NOT EXISTS (
        SELECT 1 FROM INFORMATION_SCHEMA.TABLES
        WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'Administradores'
    )
    OR NOT EXISTS (
        SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
        WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'Usuarios' AND COLUMN_NAME = 'NombreUsuario'
    )
    BEGIN
        THROW 50004, N'BLOQUEO DE ESQUEMA: El esquema V2 aún no ha sido migrado en SanarRuralDB_Dev (no se encontró dbo.Administradores o dbo.Usuarios.NombreUsuario). Ejecute y confirme primero 03_Migration_v2.sql antes del bootstrap.', 1;
    END;

    -- 1. Validación estricta de campos obligatorios
    IF @TargetIdUsuario IS NULL OR @TargetIdUsuario <= 0
    BEGIN
        THROW 50005, N'ERROR DE VALIDACIÓN: TargetIdUsuario debe ser un identificador válido mayor a 0.', 1;
    END;

    IF @PrimerNombre IS NULL OR LTRIM(RTRIM(@PrimerNombre)) = N''
       OR @PrimerApellido IS NULL OR LTRIM(RTRIM(@PrimerApellido)) = N''
    BEGIN
        THROW 50006, N'ERROR DE VALIDACIÓN: PrimerNombre y PrimerApellido son campos obligatorios y no pueden ser nulos ni vacíos. Suministre datos reales verificados antes de autorizar.', 1;
    END;

    IF LEN(@PrimerNombre) > 50 OR LEN(@PrimerApellido) > 50
    BEGIN
        THROW 50007, N'ERROR DE VALIDACIÓN: PrimerNombre o PrimerApellido exceden la longitud máxima de 50 caracteres.', 1;
    END;

    -- 2. Validar que la cuenta de usuario exista y posea el rol Admin (o Administrativo histórico en transición)
    DECLARE @IdRolAdmin INT = (SELECT IdRol FROM dbo.Roles WHERE Nombre = N'Admin');
    DECLARE @IdRolHistAdministrativo INT = (SELECT IdRol FROM dbo.Roles WHERE Nombre = N'Administrativo');

    IF NOT EXISTS (
        SELECT 1
        FROM dbo.Usuarios
        WHERE IdUsuario = @TargetIdUsuario
          AND (IdRol = @IdRolAdmin OR (@IdRolHistAdministrativo IS NOT NULL AND IdRol = @IdRolHistAdministrativo))
    )
    BEGIN
        THROW 50008, N'ERROR DE VALIDACIÓN: El usuario indicado no existe o no posee el rol Admin ni Administrativo histórico.', 1;
    END;

    -- 3. Validar que NO exista ya un perfil asociado en Administradores (impide sobrescritura)
    IF EXISTS (
        SELECT 1
        FROM dbo.Administradores
        WHERE IdUsuario = @TargetIdUsuario
    )
    BEGIN
        THROW 50009, N'BLOQUEO DE SEGURIDAD: Ya existe un perfil de Administrador vinculado a este usuario. El script aborta para impedir que una segunda ejecución sobrescriba información existente.', 1;
    END;

    -- Validar unicidad de cédula si fue proporcionada
    IF @Cedula IS NOT NULL AND EXISTS (SELECT 1 FROM dbo.Administradores WHERE Cedula = @Cedula)
    BEGIN
        THROW 50010, N'BLOQUEO DE SEGURIDAD: La cédula especificada ya pertenece a otro administrador registrado.', 1;
    END;

    -- 4. Inserción segura del perfil
    INSERT INTO dbo.Administradores
    (
        IdUsuario,
        PrimerNombre,
        SegundoNombre,
        PrimerApellido,
        SegundoApellido,
        Cedula,
        Telefono,
        Correo,
        Estado
    )
    VALUES
    (
        @TargetIdUsuario,
        @PrimerNombre,
        @SegundoNombre,
        @PrimerApellido,
        @SegundoApellido,
        @Cedula,
        @Telefono,
        @Correo,
        1
    );
    PRINT '   [OK] Perfil nuevo insertado exitosamente en dbo.Administradores.';

    -- 5. Habilitar la cuenta en dbo.Usuarios (Estado = 1) y asegurar asignación definitiva a rol Admin
    UPDATE dbo.Usuarios
    SET Estado = 1,
        IdRol = @IdRolAdmin
    WHERE IdUsuario = @TargetIdUsuario;

    PRINT '   [OK] Cuenta de usuario habilitada en dbo.Usuarios (Estado = 1) con rol definitivo Admin.';

    -- 6. Comprobación final de verificación (ejecución diferida mediante sys.sp_executesql)
    DECLARE @SqlVerificacionBootstrap NVARCHAR(MAX) = N'
        SELECT
            u.IdUsuario,
            u.NombreUsuario,
            r.Nombre AS Rol,
            u.Estado AS CuentaActiva,
            a.IdAdministrador,
            a.PrimerNombre + '' '' + a.PrimerApellido AS NombreCompleto,
            a.Cedula,
            a.Correo
        FROM dbo.Usuarios u
        INNER JOIN dbo.Roles r ON u.IdRol = r.IdRol
        INNER JOIN dbo.Administradores a ON u.IdUsuario = a.IdUsuario
        WHERE u.IdUsuario = @TargetId;';

    EXEC sys.sp_executesql
        @SqlVerificacionBootstrap,
        N'@TargetId INT',
        @TargetId = @TargetIdUsuario;

    COMMIT TRANSACTION;
    PRINT '==============================================================================';
    PRINT 'BOOTSTRAP DE ADMINISTRADOR COMPLETADO EXITOSAMENTE.';
    PRINT '==============================================================================';
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;

    PRINT 'ERROR EN BOOTSTRAP: ' + ERROR_MESSAGE();
    THROW;
END CATCH;
GO
