/* ==============================================================================
   SANAR RURAL UNAN - MIGRACIÓN ESQUEMA V2: RETIRO DE Usuarios.Correo
   Archivo: database/06_Migration_Usuarios_SoloNombreUsuario.sql
   Motor: Microsoft SQL Server 2022
   Entorno Autorizado: SanarRuralDB_Dev o SanarRuralDB

   PROPÓSITO:
     Completar la transición de autenticación para que las credenciales de acceso
     utilicen exclusivamente [Usuarios.NombreUsuario].
     Elimina la columna transitoria [Usuarios.Correo] de la tabla de autenticación,
     preservando intactas las columnas [Correo] en las tablas de perfiles
     (Pacientes, Doctores, Administradores, PersonalAdministrativo).

   BARRERA DE SEGURIDAD ESTRICTA:
     - No contiene USE [SanarRuralDB].
     - No utiliza SET NOEXEC ON/OFF.
     - Valida que la conexión activa sea exactamente [SanarRuralDB_Dev] o [SanarRuralDB].
     - Detiene la ejecución inmediatamente mediante THROW si la conexión apunta a otra base.
     - Estructurado como un único lote continuo sin separadores GO intermedios,
       garantizando que ninguna instrucción posterior pueda ejecutarse si la validación falla.
     - Es 100% idempotente: si la columna Correo ya no existe, finaliza informando
       el estado sin generar error ni alterar datos.
   ============================================================================== */

SET NOCOUNT ON;
SET XACT_ABORT ON;
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;

-- =============================================================================
-- BARRERA DE SEGURIDAD: VALIDACIÓN OBLIGATORIA DEL CONTEXTO DE BASE DE DATOS
-- =============================================================================
IF DB_NAME() NOT IN (N'SanarRuralDB_Dev', N'SanarRuralDB')
BEGIN
    DECLARE @MensajeBloqueo NVARCHAR(2048) =
        N'BLOQUEO DE SEGURIDAD CRÍTICO: Este script SOLO puede ejecutarse en las bases de datos autorizadas de Sanar Rural ("SanarRuralDB_Dev" o "SanarRuralDB"). ' +
        N'Contexto actual detectado: ' + ISNULL(QUOTENAME(DB_NAME()), N'[DESCONOCIDO]') + N'. ' +
        N'La ejecución ha sido detenida mediante THROW sin modificar datos.';
    THROW 50001, @MensajeBloqueo, 1;
END;

PRINT '==============================================================================';
PRINT 'INICIANDO MIGRACIÓN: EXCLUSIVIDAD DE NombreUsuario EN dbo.Usuarios (' + DB_NAME() + ')';
PRINT '==============================================================================';

BEGIN TRY
    BEGIN TRANSACTION;

    -- Doble verificación transaccional del contexto
    IF DB_NAME() NOT IN (N'SanarRuralDB_Dev', N'SanarRuralDB')
    BEGIN
        THROW 50002, N'BLOQUEO DE SEGURIDAD: Base de datos no autorizada dentro de la transacción.', 1;
    END;

    -- ==========================================================================
    -- 1. COMPROBACIÓN DE REQUISITOS PREVIOS
    -- ==========================================================================
    IF OBJECT_ID('dbo.Usuarios', 'U') IS NULL
    BEGIN
        THROW 50003, N'BLOQUEO DE INTEGRIDAD: La tabla dbo.Usuarios no existe en esta base de datos.', 1;
    END;

    IF COL_LENGTH('dbo.Usuarios', 'NombreUsuario') IS NULL
    BEGIN
        THROW 50004, N'BLOQUEO DE INTEGRIDAD: La columna dbo.Usuarios.NombreUsuario no existe. Debe aplicar previamente 03_Migration_v2.sql.', 1;
    END;

    -- Verificar que ningún usuario tenga NombreUsuario NULL
    IF EXISTS (SELECT 1 FROM dbo.Usuarios WHERE NombreUsuario IS NULL)
    BEGIN
        THROW 50005, N'CONDICIÓN DE ROLLBACK: Existen cuentas con NombreUsuario nulo en dbo.Usuarios.', 1;
    END;

    -- Verificar que ningún usuario tenga NombreUsuario vacío
    IF EXISTS (SELECT 1 FROM dbo.Usuarios WHERE LTRIM(RTRIM(NombreUsuario)) = N'')
    BEGIN
        THROW 50006, N'CONDICIÓN DE ROLLBACK: Existen cuentas con NombreUsuario vacío o solo espacios en blanco.', 1;
    END;

    -- Verificar ausencia total de colisiones en NombreUsuario
    IF EXISTS (
        SELECT NombreUsuario
        FROM dbo.Usuarios
        GROUP BY NombreUsuario
        HAVING COUNT(*) > 1
    )
    BEGIN
        THROW 50007, N'CONDICIÓN DE ROLLBACK: Se detectaron colisiones/duplicados en NombreUsuario dentro de dbo.Usuarios.', 1;
    END;

    PRINT '-> [Paso 1] Validación de NombreUsuario superada (obligatorio, sin vacíos ni duplicados).';

    -- ==========================================================================
    -- 2. COMPROBACIÓN DE IDEMPOTENCIA
    -- ==========================================================================
    IF COL_LENGTH('dbo.Usuarios', 'Correo') IS NULL
    BEGIN
        PRINT '==============================================================================';
        PRINT 'INFORMACIÓN: La columna dbo.Usuarios.Correo YA FUE ELIMINADA previamente en (' + DB_NAME() + ').';
        PRINT 'El sistema ya opera exclusivamente con NombreUsuario para credenciales de acceso.';
        PRINT 'La migración finaliza con éxito sin realizar modificaciones.';
        PRINT '==============================================================================';
        COMMIT TRANSACTION;
        RETURN;
    END;

    -- Respaldo volátil previo de verificación
    IF OBJECT_ID('tempdb..#PreMigracionSoloNombre') IS NOT NULL
        DROP TABLE #PreMigracionSoloNombre;

    SELECT
        u.IdUsuario,
        u.IdRol,
        u.NombreUsuario,
        u.ContrasenaHash,
        u.Estado,
        u.FechaRegistro
    INTO #PreMigracionSoloNombre
    FROM dbo.Usuarios u;

    DECLARE @TotalUsuariosAntes INT = (SELECT COUNT(*) FROM #PreMigracionSoloNombre);
    PRINT '-> [Paso 2] Cuentas existentes verificadas antes de la modificación: ' + CAST(@TotalUsuariosAntes AS NVARCHAR(10));

    -- ==========================================================================
    -- 3. RETIRO DE DEPENDENCIAS DE LA COLUMNA Correo EN dbo.Usuarios
    -- ==========================================================================
    PRINT '-> [Paso 3] Comprobando y retirando dependencias de dbo.Usuarios.Correo...';

    -- 3.1 Eliminar índices asociados a Usuarios.Correo si existen
    DECLARE @NombreIndice NVARCHAR(128);
    DECLARE CursorIndices CURSOR LOCAL FAST_FORWARD FOR
        SELECT i.name
        FROM sys.indexes i
        INNER JOIN sys.index_columns ic ON i.object_id = ic.object_id AND i.index_id = ic.index_id
        INNER JOIN sys.columns c ON ic.object_id = c.object_id AND ic.column_id = c.column_id
        WHERE i.object_id = OBJECT_ID('dbo.Usuarios')
          AND c.name = 'Correo'
          AND i.is_primary_key = 0;

    OPEN CursorIndices;
    FETCH NEXT FROM CursorIndices INTO @NombreIndice;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        DECLARE @SqlDropIndex NVARCHAR(500) = N'DROP INDEX ' + QUOTENAME(@NombreIndice) + N' ON dbo.Usuarios;';
        EXEC sys.sp_executesql @SqlDropIndex;
        PRINT '   [OK] Índice retirado: ' + @NombreIndice;
        FETCH NEXT FROM CursorIndices INTO @NombreIndice;
    END;

    CLOSE CursorIndices;
    DEALLOCATE CursorIndices;

    -- 3.2 Eliminar restricciones UNIQUE o CHECK asociadas a Usuarios.Correo si existen
    DECLARE @NombreConstraint NVARCHAR(128);
    DECLARE CursorConstraints CURSOR LOCAL FAST_FORWARD FOR
        SELECT kc.name
        FROM sys.key_constraints kc
        INNER JOIN sys.index_columns ic ON kc.parent_object_id = ic.object_id AND kc.unique_index_id = ic.index_id
        INNER JOIN sys.columns c ON ic.object_id = c.object_id AND ic.column_id = c.column_id
        WHERE kc.parent_object_id = OBJECT_ID('dbo.Usuarios')
          AND c.name = 'Correo';

    OPEN CursorConstraints;
    FETCH NEXT FROM CursorConstraints INTO @NombreConstraint;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        DECLARE @SqlDropConstraint NVARCHAR(500) = N'ALTER TABLE dbo.Usuarios DROP CONSTRAINT ' + QUOTENAME(@NombreConstraint) + N';';
        EXEC sys.sp_executesql @SqlDropConstraint;
        PRINT '   [OK] Restricción retirada: ' + @NombreConstraint;
        FETCH NEXT FROM CursorConstraints INTO @NombreConstraint;
    END;

    CLOSE CursorConstraints;
    DEALLOCATE CursorConstraints;

    -- 3.3 Eliminar default constraints sobre Correo si existen
    DECLARE @NombreDefault NVARCHAR(128);
    SELECT @NombreDefault = dc.name
    FROM sys.default_constraints dc
    INNER JOIN sys.columns c ON dc.parent_object_id = c.object_id AND dc.parent_column_id = c.column_id
    WHERE dc.parent_object_id = OBJECT_ID('dbo.Usuarios')
      AND c.name = 'Correo';

    IF @NombreDefault IS NOT NULL
    BEGIN
        DECLARE @SqlDropDefault NVARCHAR(500) = N'ALTER TABLE dbo.Usuarios DROP CONSTRAINT ' + QUOTENAME(@NombreDefault) + N';';
        EXEC sys.sp_executesql @SqlDropDefault;
        PRINT '   [OK] Restricción por defecto retirada: ' + @NombreDefault;
    END;

    -- ==========================================================================
    -- 4. ELIMINACIÓN DE LA COLUMNA Correo EN dbo.Usuarios
    -- ==========================================================================
    PRINT '-> [Paso 4] Eliminando columna dbo.Usuarios.Correo...';

    ALTER TABLE dbo.Usuarios DROP COLUMN Correo;

    PRINT '   [OK] Columna dbo.Usuarios.Correo eliminada exitosamente.';

    -- ==========================================================================
    -- 5. VALIDACIÓN POSTERIOR DE INTEGRIDAD Y REGLAS DE CONSERVACIÓN
    -- ==========================================================================
    PRINT '-> [Paso 5] Verificando integridad posterior al cambio...';

    -- 5.1 Confirmar que Usuarios.Correo ya no existe
    IF COL_LENGTH('dbo.Usuarios', 'Correo') IS NOT NULL
    BEGIN
        THROW 50008, N'CONDICIÓN DE ROLLBACK: La columna dbo.Usuarios.Correo todavía existe tras el DROP.', 1;
    END;

    -- 5.2 Confirmar que las columnas Correo de las tablas de perfiles se conservan intactas
    IF OBJECT_ID('dbo.Pacientes', 'U') IS NOT NULL AND COL_LENGTH('dbo.Pacientes', 'Correo') IS NULL
    BEGIN
        THROW 50009, N'CONDICIÓN DE ROLLBACK: Se detectó alteración indebida de Pacientes.Correo.', 1;
    END;

    IF OBJECT_ID('dbo.Doctores', 'U') IS NOT NULL AND COL_LENGTH('dbo.Doctores', 'Correo') IS NULL
    BEGIN
        THROW 50010, N'CONDICIÓN DE ROLLBACK: Se detectó alteración indebida de Doctores.Correo.', 1;
    END;

    IF OBJECT_ID('dbo.Administradores', 'U') IS NOT NULL AND COL_LENGTH('dbo.Administradores', 'Correo') IS NULL
    BEGIN
        THROW 50011, N'CONDICIÓN DE ROLLBACK: Se detectó alteración indebida de Administradores.Correo.', 1;
    END;

    IF OBJECT_ID('dbo.PersonalAdministrativo', 'U') IS NOT NULL AND COL_LENGTH('dbo.PersonalAdministrativo', 'Correo') IS NULL
    BEGIN
        THROW 50012, N'CONDICIÓN DE ROLLBACK: Se detectó alteración indebida de PersonalAdministrativo.Correo.', 1;
    END;

    PRINT '   [OK] Columnas Correo en perfiles (Pacientes, Doctores, Administradores, PersonalAdministrativo) conservadas.';

    -- 5.3 Confirmar que la cantidad y atributos esenciales de usuarios no cambiaron
    DECLARE @TotalUsuariosDespues INT = (SELECT COUNT(*) FROM dbo.Usuarios);
    IF @TotalUsuariosAntes <> @TotalUsuariosDespues
    BEGIN
        THROW 50013, N'CONDICIÓN DE ROLLBACK: Discrepancia en la cantidad de cuentas de usuario tras la migración.', 1;
    END;

    -- Validar que no se alteraron IdUsuario, IdRol, ContrasenaHash ni Estado
    IF EXISTS (
        SELECT 1
        FROM dbo.Usuarios u
        INNER JOIN #PreMigracionSoloNombre p ON u.IdUsuario = p.IdUsuario
        WHERE u.IdRol <> p.IdRol
           OR u.NombreUsuario <> p.NombreUsuario
           OR u.ContrasenaHash <> p.ContrasenaHash
           OR u.Estado <> p.Estado
    )
    BEGIN
        THROW 50014, N'CONDICIÓN DE ROLLBACK: Se detectaron cambios imprevistos en atributos esenciales de las cuentas (Roles, Hashes, Estados).', 1;
    END;

    PRINT '   [OK] Cero alteraciones en Hashes, Roles, Estados e Identificadores de cuentas.';

    COMMIT TRANSACTION;

    PRINT '==============================================================================';
    PRINT 'MIGRACIÓN COMPLETADA CON ÉXITO: dbo.Usuarios opera exclusivamente con NombreUsuario.';
    PRINT '==============================================================================';

END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0
    BEGIN
        ROLLBACK TRANSACTION;
        PRINT '*** TRANSACCIÓN REVERTIDA (ROLLBACK) DEBIDO A UN ERROR ***';
    END;

    DECLARE @ErrorMsg NVARCHAR(2048) = ERROR_MESSAGE();
    DECLARE @ErrorNum INT = ERROR_NUMBER();
    DECLARE @ErrorLine INT = ERROR_LINE();

    RAISERROR(N'ERROR EN MIGRACIÓN [Línea %d, Código %d]: %s', 16, 1, @ErrorLine, @ErrorNum, @ErrorMsg);
END CATCH;
