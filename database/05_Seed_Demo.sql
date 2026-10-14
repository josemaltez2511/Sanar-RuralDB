/* ==============================================================================
   SANAR RURAL - DATOS SEMILLA INTEGRALES DE DEMOSTRACIÓN (FASE 5)
   Motor: Microsoft SQL Server 2022
   Archivo: database/05_Seed_Demo.sql

   PRINCIPIOS Y MANDAMIENTOS DE INTEGRIDAD:
     1. Totalmente idempotente: puede ejecutarse repetidamente sin duplicar filas
        ni generar conflictos de restricciones únicas o de clave foránea.
     2. Respeta los 4 roles definitivos del sistema:
        - Admin (demo_admin)
        - Personal_administrativo (demo_personal)
        - Doctor (demo_doctor)
        - Paciente (demo_paciente)
        Conservando además el rol histórico 'Administrativo'.
     3. Datos estrictamente ficticios y claramente identificables como demostración:
        - Prefijos estándar 'demo_*' en usuarios y 'DEMO-*' en cédulas y licencias.
        - Cero identidades o datos personales reales.
     4. Seguridad criptográfica de contraseñas:
        - Se utiliza el hash oficial PBKDF2-SHA256 con 600,000 iteraciones verificado
          por la aplicación en usuariosModels.cs.
        - Contraseña demo para todas las cuentas de prueba: SanarRural2026!
     5. Cobertura integral de relaciones clínicas y asistenciales:
        - Administradores y PersonalAdministrativo (perfiles vinculados y disponibles).
        - Doctores con especialidades y asignación hospitalaria (DoctorHospitalEspecialidad).
        - Pacientes con ubicación comunitaria y contactos de emergencia.
        - Flujo clínico asistencial completo: Citas en varios estados, Consultas médicas,
          Signos vitales, Diagnósticos vinculados a enfermedades y Prescripciones farmacológicas.
     6. No destructivo: NO elimina ni sobrescribe usuarios ni registros históricos existentes.
   ============================================================================== */

/* ==============================================================================
   VALIDACIÓN ESTRICTA DEL CONTEXTO DE BASE DE DATOS
   Evita cambios implícitos de contexto. Exige selección explícita de SanarRuralDB o SanarRuralDB_Dev.
   USO EXCLUSIVO: Desarrollo, demostraciones y pruebas locales.
   ============================================================================== */
IF DB_NAME() NOT IN (N'SanarRuralDB', N'SanarRuralDB_Dev')
BEGIN
    DECLARE @MensajeContextoDemo NVARCHAR(500) =
        N'ERROR DE CONTEXTO: Este script de datos de demostración debe ejecutarse explícitamente en "SanarRuralDB" o "SanarRuralDB_Dev". ' +
        N'Contexto actual detectado: ' + QUOTENAME(DB_NAME()) + N'. Seleccione la base de datos de desarrollo antes de ejecutar.';
    RAISERROR(@MensajeContextoDemo, 16, 1);
    SET NOEXEC ON;
END;
GO

SET NOCOUNT ON;
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

PRINT N'----------------------------------------------------------------------';
PRINT N'Iniciando carga/verificación de Datos Semilla de Demostración (Fase 5)';
PRINT N'Base de datos activa: ' + DB_NAME();
PRINT N'----------------------------------------------------------------------';
GO

/* ==============================================================================
   1. VARIABLES GLOBALES DE REFERENCIA Y HASH DE CONTRASEÑA
   ============================================================================== */
DECLARE @HashDemo NVARCHAR(255) = N'PBKDF2-SHA256$1$600000$FjEokw5DOvjlmCVYDF85lQ==$s/4L9rrX+ZwI3lR/1Y2OsKTvLDjQBVKDMFLb77ZWtSs=';
-- Contraseña asociada al hash: SanarRural2026!

DECLARE @IdRolAdmin INT = (SELECT IdRol FROM dbo.Roles WHERE Nombre = N'Admin');
DECLARE @IdRolPersonal INT = (SELECT IdRol FROM dbo.Roles WHERE Nombre = N'Personal_administrativo');
DECLARE @IdRolDoctor INT = (SELECT IdRol FROM dbo.Roles WHERE Nombre = N'Doctor');
DECLARE @IdRolPaciente INT = (SELECT IdRol FROM dbo.Roles WHERE Nombre = N'Paciente');

IF @IdRolAdmin IS NULL OR @IdRolPersonal IS NULL OR @IdRolDoctor IS NULL OR @IdRolPaciente IS NULL
BEGIN
    RAISERROR(N'ERROR CRÍTICO: Los roles definitivos no están presentes en la base de datos. Ejecute primero database/02_Seed.sql.', 16, 1);
    RETURN;
END;


/* ==============================================================================
   2. USUARIOS DE DEMOSTRACIÓN (1 CUENTA POR CADA ROL DEFINITIVO)
   ============================================================================== */
-- 2.1 Admin de Demostración
IF NOT EXISTS (SELECT 1 FROM dbo.Usuarios WHERE NombreUsuario = N'demo_admin')
BEGIN
    INSERT INTO dbo.Usuarios (IdRol, NombreUsuario, Correo, ContrasenaHash, FechaRegistro, Estado)
    VALUES (@IdRolAdmin, N'demo_admin', N'admin.demo@sanarrural.unan.edu.ni', @HashDemo, SYSDATETIME(), 1);
    PRINT N'[+] Usuario demo_admin creado (Rol: Admin).';
END;

-- 2.2 Personal Administrativo de Demostración
IF NOT EXISTS (SELECT 1 FROM dbo.Usuarios WHERE NombreUsuario = N'demo_personal')
BEGIN
    INSERT INTO dbo.Usuarios (IdRol, NombreUsuario, Correo, ContrasenaHash, FechaRegistro, Estado)
    VALUES (@IdRolPersonal, N'demo_personal', N'personal.demo@sanarrural.unan.edu.ni', @HashDemo, SYSDATETIME(), 1);
    PRINT N'[+] Usuario demo_personal creado (Rol: Personal_administrativo).';
END;

-- 2.3 Doctor de Demostración
IF NOT EXISTS (SELECT 1 FROM dbo.Usuarios WHERE NombreUsuario = N'demo_doctor')
BEGIN
    INSERT INTO dbo.Usuarios (IdRol, NombreUsuario, Correo, ContrasenaHash, FechaRegistro, Estado)
    VALUES (@IdRolDoctor, N'demo_doctor', N'doctora.demo@sanarrural.unan.edu.ni', @HashDemo, SYSDATETIME(), 1);
    PRINT N'[+] Usuario demo_doctor creado (Rol: Doctor).';
END;

-- 2.4 Paciente de Demostración
IF NOT EXISTS (SELECT 1 FROM dbo.Usuarios WHERE NombreUsuario = N'demo_paciente')
BEGIN
    INSERT INTO dbo.Usuarios (IdRol, NombreUsuario, Correo, ContrasenaHash, FechaRegistro, Estado)
    VALUES (@IdRolPaciente, N'demo_paciente', N'maria.demo@sanarrural.unan.edu.ni', @HashDemo, SYSDATETIME(), 1);
    PRINT N'[+] Usuario demo_paciente creado (Rol: Paciente).';
END;
GO


/* ==============================================================================
   3. PERFILES DE ADMINISTRADORES (Administradores)
   ============================================================================== */
DECLARE @IdUsuarioAdmin INT = (SELECT IdUsuario FROM dbo.Usuarios WHERE NombreUsuario = N'demo_admin');

-- Perfil vinculado a la cuenta demo_admin
IF NOT EXISTS (SELECT 1 FROM dbo.Administradores WHERE Cedula = N'DEMO-ADM-001')
BEGIN
    INSERT INTO dbo.Administradores (IdUsuario, PrimerNombre, SegundoNombre, PrimerApellido, SegundoApellido, Cedula, Telefono, Correo, Estado)
    VALUES (@IdUsuarioAdmin, N'Admin', N'Demo', N'Sanar', N'Rural', N'DEMO-ADM-001', N'2222-0001', N'admin.demo@sanarrural.unan.edu.ni', 1);
    PRINT N'[+] Perfil demo de Administrador vinculado a demo_admin insertado.';
END;

-- Perfil de Administrador sin usuario (para pruebas de vinculación desde la interfaz)
IF NOT EXISTS (SELECT 1 FROM dbo.Administradores WHERE Cedula = N'DEMO-ADM-002')
BEGIN
    INSERT INTO dbo.Administradores (IdUsuario, PrimerNombre, SegundoNombre, PrimerApellido, SegundoApellido, Cedula, Telefono, Correo, Estado)
    VALUES (NULL, N'Supervisor', N'Reserva', N'Demo', N'UNAN', N'DEMO-ADM-002', N'2222-0002', N'supervisor.demo@sanarrural.unan.edu.ni', 1);
    PRINT N'[+] Perfil demo de Administrador sin usuario insertado.';
END;
GO


/* ==============================================================================
   4. PERFILES DE PERSONAL ADMINISTRATIVO (PersonalAdministrativo)
   ============================================================================== */
DECLARE @IdUsuarioPersonal INT = (SELECT IdUsuario FROM dbo.Usuarios WHERE NombreUsuario = N'demo_personal');

-- Perfil vinculado a la cuenta demo_personal
IF NOT EXISTS (SELECT 1 FROM dbo.PersonalAdministrativo WHERE Cedula = N'DEMO-PER-001')
BEGIN
    INSERT INTO dbo.PersonalAdministrativo (IdUsuario, PrimerNombre, SegundoNombre, PrimerApellido, SegundoApellido, Cedula, Telefono, Correo, Cargo, Estado)
    VALUES (@IdUsuarioPersonal, N'Personal', N'Demo', N'Recepción', N'Central', N'DEMO-PER-001', N'2222-0003', N'personal.demo@sanarrural.unan.edu.ni', N'Oficinista de Citas y Admisión', 1);
    PRINT N'[+] Perfil demo de Personal Administrativo vinculado a demo_personal insertado.';
END;

-- Perfil de Personal Administrativo sin usuario (para pruebas de asignación)
IF NOT EXISTS (SELECT 1 FROM dbo.PersonalAdministrativo WHERE Cedula = N'DEMO-PER-002')
BEGIN
    INSERT INTO dbo.PersonalAdministrativo (IdUsuario, PrimerNombre, SegundoNombre, PrimerApellido, SegundoApellido, Cedula, Telefono, Correo, Cargo, Estado)
    VALUES (NULL, N'Asistente', N'Turno', N'Demo', N'Tarde', N'DEMO-PER-002', N'2222-0004', N'asistente.demo@sanarrural.unan.edu.ni', N'Admisión y Archivo Clínico', 1);
    PRINT N'[+] Perfil demo de Personal Administrativo sin usuario insertado.';
END;
GO


/* ==============================================================================
   5. PERFILES DE DOCTORES (Doctores)
   ============================================================================== */
DECLARE @IdUsuarioDoctor INT = (SELECT IdUsuario FROM dbo.Usuarios WHERE NombreUsuario = N'demo_doctor');

-- Doctora demo vinculada a cuenta demo_doctor
IF NOT EXISTS (SELECT 1 FROM dbo.Doctores WHERE Cedula = N'DEMO-DOC-001' OR NumeroLicencia = N'DEMO-LIC-001')
BEGIN
    INSERT INTO dbo.Doctores (IdUsuario, PrimerNombre, SegundoNombre, PrimerApellido, SegundoApellido, Cedula, NumeroLicencia, Telefono, Correo, Estado)
    VALUES (@IdUsuarioDoctor, N'Elena', N'María', N'Morales', N'Rostrán', N'DEMO-DOC-001', N'DEMO-LIC-001', N'8888-0001', N'doctora.demo@sanarrural.unan.edu.ni', 1);
    PRINT N'[+] Perfil demo Dra. Elena Morales vinculado a demo_doctor insertado.';
END;

-- Doctor demo sin usuario (para pruebas de vinculación y disponibilidad asistencial)
IF NOT EXISTS (SELECT 1 FROM dbo.Doctores WHERE Cedula = N'DEMO-DOC-002' OR NumeroLicencia = N'DEMO-LIC-002')
BEGIN
    INSERT INTO dbo.Doctores (IdUsuario, PrimerNombre, SegundoNombre, PrimerApellido, SegundoApellido, Cedula, NumeroLicencia, Telefono, Correo, Estado)
    VALUES (NULL, N'Roberto', N'José', N'Silva', N'Vivas', N'DEMO-DOC-002', N'DEMO-LIC-002', N'8888-0002', N'doctor.demo@sanarrural.unan.edu.ni', 1);
    PRINT N'[+] Perfil demo Dr. Roberto Silva sin usuario insertado.';
END;
GO


/* ==============================================================================
   6. ESPECIALIDADES Y SEDES DE DOCTORES
   ============================================================================== */
-- 6.1 DoctorEspecialidad
DECLARE @IdDocElena INT = (SELECT IdDoctor FROM dbo.Doctores WHERE NumeroLicencia = N'DEMO-LIC-001');
DECLARE @IdDocRoberto INT = (SELECT IdDoctor FROM dbo.Doctores WHERE NumeroLicencia = N'DEMO-LIC-002');

DECLARE @IdEspGeneral INT = (SELECT IdEspecialidad FROM dbo.Especialidades WHERE Nombre = N'Medicina General');
DECLARE @IdEspPediatria INT = (SELECT IdEspecialidad FROM dbo.Especialidades WHERE Nombre = N'Pediatría');
DECLARE @IdEspInterna INT = (SELECT IdEspecialidad FROM dbo.Especialidades WHERE Nombre = N'Medicina Interna');

IF @IdDocElena IS NOT NULL AND @IdEspGeneral IS NOT NULL
BEGIN
    IF NOT EXISTS (SELECT 1 FROM dbo.DoctorEspecialidad WHERE IdDoctor = @IdDocElena AND IdEspecialidad = @IdEspGeneral)
        INSERT INTO dbo.DoctorEspecialidad (IdDoctor, IdEspecialidad) VALUES (@IdDocElena, @IdEspGeneral);
END;

IF @IdDocElena IS NOT NULL AND @IdEspPediatria IS NOT NULL
BEGIN
    IF NOT EXISTS (SELECT 1 FROM dbo.DoctorEspecialidad WHERE IdDoctor = @IdDocElena AND IdEspecialidad = @IdEspPediatria)
        INSERT INTO dbo.DoctorEspecialidad (IdDoctor, IdEspecialidad) VALUES (@IdDocElena, @IdEspPediatria);
END;

IF @IdDocRoberto IS NOT NULL AND @IdEspInterna IS NOT NULL
BEGIN
    IF NOT EXISTS (SELECT 1 FROM dbo.DoctorEspecialidad WHERE IdDoctor = @IdDocRoberto AND IdEspecialidad = @IdEspInterna)
        INSERT INTO dbo.DoctorEspecialidad (IdDoctor, IdEspecialidad) VALUES (@IdDocRoberto, @IdEspInterna);
END;

-- 6.2 DoctorHospitalEspecialidad
DECLARE @IdHospTisma INT = (SELECT IdHospital FROM dbo.Hospitales WHERE Nombre = N'Hospital Primario Tisma');
DECLARE @IdHospMasaya INT = (SELECT IdHospital FROM dbo.Hospitales WHERE Nombre = N'Hospital Departamental Hilario Sánchez Vásquez');

IF @IdDocElena IS NOT NULL AND @IdHospTisma IS NOT NULL AND @IdEspGeneral IS NOT NULL
BEGIN
    IF NOT EXISTS (SELECT 1 FROM dbo.DoctorHospitalEspecialidad WHERE IdDoctor = @IdDocElena AND IdHospital = @IdHospTisma AND IdEspecialidad = @IdEspGeneral)
        INSERT INTO dbo.DoctorHospitalEspecialidad (IdDoctor, IdHospital, IdEspecialidad) VALUES (@IdDocElena, @IdHospTisma, @IdEspGeneral);
END;

IF @IdDocElena IS NOT NULL AND @IdHospTisma IS NOT NULL AND @IdEspPediatria IS NOT NULL
BEGIN
    IF NOT EXISTS (SELECT 1 FROM dbo.DoctorHospitalEspecialidad WHERE IdDoctor = @IdDocElena AND IdHospital = @IdHospTisma AND IdEspecialidad = @IdEspPediatria)
        INSERT INTO dbo.DoctorHospitalEspecialidad (IdDoctor, IdHospital, IdEspecialidad) VALUES (@IdDocElena, @IdHospTisma, @IdEspPediatria);
END;

IF @IdDocRoberto IS NOT NULL AND @IdHospMasaya IS NOT NULL AND @IdEspInterna IS NOT NULL
BEGIN
    IF NOT EXISTS (SELECT 1 FROM dbo.DoctorHospitalEspecialidad WHERE IdDoctor = @IdDocRoberto AND IdHospital = @IdHospMasaya AND IdEspecialidad = @IdEspInterna)
        INSERT INTO dbo.DoctorHospitalEspecialidad (IdDoctor, IdHospital, IdEspecialidad) VALUES (@IdDocRoberto, @IdHospMasaya, @IdEspInterna);
END;
PRINT N'[+] Asignaciones DoctorEspecialidad y DoctorHospitalEspecialidad verificadas.';
GO


/* ==============================================================================
   7. PACIENTES DE DEMOSTRACIÓN (Pacientes)
   ============================================================================== */
DECLARE @IdUsuarioPaciente INT = (SELECT IdUsuario FROM dbo.Usuarios WHERE NombreUsuario = N'demo_paciente');

DECLARE @IdComCortezas INT = (SELECT IdComunidad FROM dbo.Comunidades WHERE Nombre = N'Las Cortezas');
DECLARE @IdComCarmen INT = (SELECT IdComunidad FROM dbo.Comunidades WHERE Nombre = N'El Carmen');
DECLARE @IdComMonteVerde INT = (SELECT IdComunidad FROM dbo.Comunidades WHERE Nombre = N'Monte Verde');

-- Si alguna comunidad no se resolvió, asigna la primera disponible
IF @IdComCortezas IS NULL SELECT TOP 1 @IdComCortezas = IdComunidad FROM dbo.Comunidades;
IF @IdComCarmen IS NULL SELECT TOP 1 @IdComCarmen = IdComunidad FROM dbo.Comunidades;
IF @IdComMonteVerde IS NULL SELECT TOP 1 @IdComMonteVerde = IdComunidad FROM dbo.Comunidades;

-- 7.1 Paciente Demo 1: Vinculada a cuenta demo_paciente
IF NOT EXISTS (SELECT 1 FROM dbo.Pacientes WHERE Cedula = N'DEMO-PAC-001')
BEGIN
    INSERT INTO dbo.Pacientes (
        IdUsuario, PrimerNombre, SegundoNombre, PrimerApellido, SegundoApellido,
        Cedula, NumeroINSS, FechaNacimiento, Genero, Telefono, Correo,
        IdComunidad, Direccion, ReferenciaAdicional, TipoSangre, Alergias, Antecedentes, Estado
    )
    VALUES (
        @IdUsuarioPaciente, N'María', N'Teresa', N'Hernández', N'Rivas',
        N'DEMO-PAC-001', N'DEMO-INSS-001', '1992-04-10', N'Femenino', N'8765-4321', N'maria.demo@sanarrural.unan.edu.ni',
        @IdComCortezas, N'Del parque central 2c al este', N'Frente a pulpería La Bendición', N'O+', N'Penicilina', N'Gastritis crónica en tratamiento', 1
    );
    PRINT N'[+] Paciente María Hernández vinculada a demo_paciente insertada.';
END;

-- 7.2 Paciente Demo 2: Adulto sin usuario
IF NOT EXISTS (SELECT 1 FROM dbo.Pacientes WHERE Cedula = N'DEMO-PAC-002')
BEGIN
    INSERT INTO dbo.Pacientes (
        IdUsuario, PrimerNombre, SegundoNombre, PrimerApellido, SegundoApellido,
        Cedula, NumeroINSS, FechaNacimiento, Genero, Telefono, Correo,
        IdComunidad, Direccion, ReferenciaAdicional, TipoSangre, Alergias, Antecedentes, Estado
    )
    VALUES (
        NULL, N'Pedro', N'Antonio', N'Gaitán', N'López',
        N'DEMO-PAC-002', N'DEMO-INSS-002', '1985-08-22', N'Masculino', N'8877-6655', N'pedro.demo@sanarrural.unan.edu.ni',
        @IdComCarmen, N'Km 35 carretera a Tisma', N'Casa esquinera color verde con cerca blanca', N'A+', N'Ninguna', N'Hipertensión arterial controlada', 1
    );
    PRINT N'[+] Paciente Pedro Gaitán sin usuario insertado.';
END;

-- 7.3 Paciente Demo 3: Paciente pediátrica sin usuario
IF NOT EXISTS (SELECT 1 FROM dbo.Pacientes WHERE Cedula = N'DEMO-PAC-003')
BEGIN
    INSERT INTO dbo.Pacientes (
        IdUsuario, PrimerNombre, SegundoNombre, PrimerApellido, SegundoApellido,
        Cedula, NumeroINSS, FechaNacimiento, Genero, Telefono, Correo,
        IdComunidad, Direccion, ReferenciaAdicional, TipoSangre, Alergias, Antecedentes, Estado
    )
    VALUES (
        NULL, N'Rosa', N'Elena', N'Castillo', N'Valle',
        N'DEMO-PAC-003', N'DEMO-INSS-003', '2015-11-05', N'Femenino', N'8999-1122', NULL,
        @IdComMonteVerde, N'Comunidad Monte Verde sector Los Mangos', N'Junto al pozo comunal', N'O+', N'Sulfas', N'Asma bronquial infantil en control', 1
    );
    PRINT N'[+] Paciente pediátrica Rosa Castillo sin usuario insertada.';
END;
GO


/* ==============================================================================
   8. CONTACTOS DE EMERGENCIA (ContactosEmergencia)
   ============================================================================== */
DECLARE @IdPacMaria INT = (SELECT IdPaciente FROM dbo.Pacientes WHERE Cedula = N'DEMO-PAC-001');
DECLARE @IdPacPedro INT = (SELECT IdPaciente FROM dbo.Pacientes WHERE Cedula = N'DEMO-PAC-002');
DECLARE @IdPacRosa INT = (SELECT IdPaciente FROM dbo.Pacientes WHERE Cedula = N'DEMO-PAC-003');

IF @IdPacMaria IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dbo.ContactosEmergencia WHERE IdPaciente = @IdPacMaria AND PrimerNombre = N'Carlos' AND PrimerApellido = N'Rivas')
BEGIN
    INSERT INTO dbo.ContactosEmergencia (IdPaciente, PrimerNombre, SegundoNombre, PrimerApellido, SegundoApellido, Parentesco, Telefono, Cedula)
    VALUES (@IdPacMaria, N'Carlos', N'Alberto', N'Rivas', N'Gómez', N'Esposo', N'8765-4320', N'DEMO-CON-001');
END;

IF @IdPacPedro IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dbo.ContactosEmergencia WHERE IdPaciente = @IdPacPedro AND PrimerNombre = N'Luisa' AND PrimerApellido = N'López')
BEGIN
    INSERT INTO dbo.ContactosEmergencia (IdPaciente, PrimerNombre, SegundoNombre, PrimerApellido, SegundoApellido, Parentesco, Telefono, Cedula)
    VALUES (@IdPacPedro, N'Luisa', N'Amanda', N'López', N'Castillo', N'Madre', N'8877-6650', N'DEMO-CON-002');
END;

IF @IdPacRosa IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dbo.ContactosEmergencia WHERE IdPaciente = @IdPacRosa AND PrimerNombre = N'Carmen' AND PrimerApellido = N'Valle')
BEGIN
    INSERT INTO dbo.ContactosEmergencia (IdPaciente, PrimerNombre, SegundoNombre, PrimerApellido, SegundoApellido, Parentesco, Telefono, Cedula)
    VALUES (@IdPacRosa, N'Carmen', N'Rosa', N'Valle', N'Pérez', N'Madre', N'8999-1120', N'DEMO-CON-003');
END;
PRINT N'[+] Contactos de emergencia verificados.';
GO


/* ==============================================================================
   9. CITAS MÉDICAS DEMO (Citas)
   ============================================================================== */
DECLARE @IdPacMaria INT = (SELECT IdPaciente FROM dbo.Pacientes WHERE Cedula = N'DEMO-PAC-001');
DECLARE @IdPacPedro INT = (SELECT IdPaciente FROM dbo.Pacientes WHERE Cedula = N'DEMO-PAC-002');
DECLARE @IdPacRosa INT = (SELECT IdPaciente FROM dbo.Pacientes WHERE Cedula = N'DEMO-PAC-003');

DECLARE @IdDocElena INT = (SELECT IdDoctor FROM dbo.Doctores WHERE NumeroLicencia = N'DEMO-LIC-001');
DECLARE @IdDocRoberto INT = (SELECT IdDoctor FROM dbo.Doctores WHERE NumeroLicencia = N'DEMO-LIC-002');

DECLARE @IdHospTisma INT = (SELECT IdHospital FROM dbo.Hospitales WHERE Nombre = N'Hospital Primario Tisma');
DECLARE @IdHospMasaya INT = (SELECT IdHospital FROM dbo.Hospitales WHERE Nombre = N'Hospital Departamental Hilario Sánchez Vásquez');

DECLARE @IdEspGeneral INT = (SELECT IdEspecialidad FROM dbo.Especialidades WHERE Nombre = N'Medicina General');
DECLARE @IdEspPediatria INT = (SELECT IdEspecialidad FROM dbo.Especialidades WHERE Nombre = N'Pediatría');
DECLARE @IdEspInterna INT = (SELECT IdEspecialidad FROM dbo.Especialidades WHERE Nombre = N'Medicina Interna');

-- 9.1 Cita 1: Atendida (María Hernández con Dra. Elena Morales)
IF @IdPacMaria IS NOT NULL AND @IdDocElena IS NOT NULL AND @IdHospTisma IS NOT NULL AND @IdEspGeneral IS NOT NULL
BEGIN
    IF NOT EXISTS (SELECT 1 FROM dbo.Citas WHERE IdPaciente = @IdPacMaria AND Motivo LIKE N'%Control y seguimiento de cuadro respiratorio%')
    BEGIN
        INSERT INTO dbo.Citas (IdPaciente, IdDoctor, IdHospital, IdEspecialidad, FechaHoraProgramada, Estado, Motivo, FechaCreacion)
        VALUES (@IdPacMaria, @IdDocElena, @IdHospTisma, @IdEspGeneral, DATEADD(DAY, -3, CAST('2026-10-11 08:30:00' AS DATETIME2)), N'Atendida', N'Control y seguimiento de cuadro respiratorio agudo', DATEADD(DAY, -5, SYSDATETIME()));
        PRINT N'[+] Cita Atendida demo creada.';
    END;
END;

-- 9.2 Cita 2: Confirmada (Pedro Gaitán con Dr. Roberto Silva)
IF @IdPacPedro IS NOT NULL AND @IdDocRoberto IS NOT NULL AND @IdHospMasaya IS NOT NULL AND @IdEspInterna IS NOT NULL
BEGIN
    IF NOT EXISTS (SELECT 1 FROM dbo.Citas WHERE IdPaciente = @IdPacPedro AND Motivo LIKE N'%Revisión y ajuste de medicación para presión arterial%')
    BEGIN
        INSERT INTO dbo.Citas (IdPaciente, IdDoctor, IdHospital, IdEspecialidad, FechaHoraProgramada, Estado, Motivo, FechaCreacion)
        VALUES (@IdPacPedro, @IdDocRoberto, @IdHospMasaya, @IdEspInterna, DATEADD(DAY, 1, CAST('2026-10-15 09:00:00' AS DATETIME2)), N'Confirmada', N'Revisión y ajuste de medicación para presión arterial', SYSDATETIME());
        PRINT N'[+] Cita Confirmada demo creada.';
    END;
END;

-- 9.3 Cita 3: Pendiente (Rosa Castillo con Dra. Elena Morales)
IF @IdPacRosa IS NOT NULL AND @IdDocElena IS NOT NULL AND @IdHospTisma IS NOT NULL AND @IdEspPediatria IS NOT NULL
BEGIN
    IF NOT EXISTS (SELECT 1 FROM dbo.Citas WHERE IdPaciente = @IdPacRosa AND Motivo LIKE N'%Evaluación pediátrica por tos alérgica%')
    BEGIN
        INSERT INTO dbo.Citas (IdPaciente, IdDoctor, IdHospital, IdEspecialidad, FechaHoraProgramada, Estado, Motivo, FechaCreacion)
        VALUES (@IdPacRosa, @IdDocElena, @IdHospTisma, @IdEspPediatria, DATEADD(DAY, 4, CAST('2026-10-18 10:30:00' AS DATETIME2)), N'Pendiente', N'Evaluación pediátrica por tos alérgica persistente', SYSDATETIME());
        PRINT N'[+] Cita Pendiente demo creada.';
    END;
END;
GO


/* ==============================================================================
   10. CONSULTA MÉDICA DEMO (Consultas)
   ============================================================================== */
DECLARE @IdCitaAtendida INT = (
    SELECT TOP 1 IdCita FROM dbo.Citas
    WHERE Motivo LIKE N'%Control y seguimiento de cuadro respiratorio%' AND Estado = N'Atendida'
);

IF @IdCitaAtendida IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dbo.Consultas WHERE IdCita = @IdCitaAtendida)
BEGIN
    INSERT INTO dbo.Consultas (
        IdCita, FechaHoraInicio, FechaHoraFin, EstadoConsulta,
        PadecimientoActual, ExamenFisico, Observaciones, PlanSeguimiento
    )
    VALUES (
        @IdCitaAtendida,
        DATEADD(DAY, -3, CAST('2026-10-11 08:30:00' AS DATETIME2)),
        DATEADD(DAY, -3, CAST('2026-10-11 09:05:00' AS DATETIME2)),
        N'Finalizada',
        N'Paciente femenina de 34 años de edad que acude por cuadro de 3 días de evolución caracterizado por febrícula vespertina, odinofagia leve, cefalea holocraneana y tos seca persistente.',
        N'Paciente orientada y colaboradora. Orofaringe eritematosa sin placas blanquecinas ni exudados purulentos. Ruidos respiratorios claros y audibles, murmullo vesicular presente sin ruidos agregados. Abdomen suave y depresible.',
        N'Cuadro clínico típico de infección respiratoria aguda de vía aérea superior de probable curso viral. Sin datos de alarma respiratoria.',
        N'Manejo sintomático domiciliario. Abundante ingesta de líquidos tibios, reposo por 48 horas y acudir a urgencias si presenta disnea o fiebre mayor a 39 °C.'
    );
    PRINT N'[+] Consulta Finalizada demo insertada.';
END;
GO


/* ==============================================================================
   11. SIGNOS VITALES DEMO (SignosVitales)
   ============================================================================== */
DECLARE @IdConsultaDemo INT = (
    SELECT c.IdConsulta FROM dbo.Consultas c
    INNER JOIN dbo.Citas ci ON ci.IdCita = c.IdCita
    WHERE ci.Motivo LIKE N'%Control y seguimiento de cuadro respiratorio%'
);

IF @IdConsultaDemo IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dbo.SignosVitales WHERE IdConsulta = @IdConsultaDemo)
BEGIN
    INSERT INTO dbo.SignosVitales (
        IdConsulta, PresionSistolica, PresionDiastolica, FrecuenciaCardiaca,
        FrecuenciaRespiratoria, Temperatura, SaturacionOxigeno, PesoKg, TallaCm
    )
    VALUES (
        @IdConsultaDemo, 110, 70, 74, 18, 37.4, 98.50, 58.50, 162.00
    );
    PRINT N'[+] Signos vitales de demostración insertados.';
END;
GO


/* ==============================================================================
   12. DIAGNÓSTICOS MÉDICOS DEMO (Diagnosticos)
   ============================================================================== */
DECLARE @IdConsultaDemo INT = (
    SELECT c.IdConsulta FROM dbo.Consultas c
    INNER JOIN dbo.Citas ci ON ci.IdCita = c.IdCita
    WHERE ci.Motivo LIKE N'%Control y seguimiento de cuadro respiratorio%'
);

DECLARE @IdEnfIRA INT = (SELECT IdEnfermedad FROM dbo.Enfermedades WHERE NombreEnfermedad = N'Infección Respiratoria Aguda');

IF @IdConsultaDemo IS NOT NULL
BEGIN
    -- Diagnóstico Principal
    IF NOT EXISTS (SELECT 1 FROM dbo.Diagnosticos WHERE IdConsulta = @IdConsultaDemo AND TipoDiagnostico = N'Principal')
    BEGIN
        INSERT INTO dbo.Diagnosticos (IdConsulta, IdEnfermedad, TipoDiagnostico, Descripcion, Observaciones)
        VALUES (
            @IdConsultaDemo, @IdEnfIRA, N'Principal',
            N'Infección Respiratoria Aguda no especificada de origen viral',
            N'Faringitis viral aguda sin compromiso hemodinámico ni alveolar'
        );
        PRINT N'[+] Diagnóstico Principal demo insertado.';
    END;

    -- Diagnóstico Secundario
    IF NOT EXISTS (SELECT 1 FROM dbo.Diagnosticos WHERE IdConsulta = @IdConsultaDemo AND TipoDiagnostico = N'Secundario')
    BEGIN
        INSERT INTO dbo.Diagnosticos (IdConsulta, IdEnfermedad, TipoDiagnostico, Descripcion, Observaciones)
        VALUES (
            @IdConsultaDemo, NULL, N'Secundario',
            N'Cefalea tensional asociada a síndrome febril leve',
            N'Controlada con analgesia sintomática'
        );
        PRINT N'[+] Diagnóstico Secundario demo insertado.';
    END;
END;
GO


/* ==============================================================================
   13. PRESCRIPCIONES MÉDICAS DEMO (Prescripciones)
   ============================================================================== */
DECLARE @IdConsultaDemo INT = (
    SELECT c.IdConsulta FROM dbo.Consultas c
    INNER JOIN dbo.Citas ci ON ci.IdCita = c.IdCita
    WHERE ci.Motivo LIKE N'%Control y seguimiento de cuadro respiratorio%'
);

DECLARE @IdMedParacetamol INT = (SELECT IdMedicamento FROM dbo.Medicamentos WHERE NombreMedicamento LIKE N'%Acetaminofén%');
DECLARE @IdMedLoratadina INT = (SELECT IdMedicamento FROM dbo.Medicamentos WHERE NombreMedicamento LIKE N'%Loratadina%');

IF @IdConsultaDemo IS NOT NULL
BEGIN
    -- Prescripción 1: Acetaminofén
    IF @IdMedParacetamol IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dbo.Prescripciones WHERE IdConsulta = @IdConsultaDemo AND IdMedicamento = @IdMedParacetamol)
    BEGIN
        INSERT INTO dbo.Prescripciones (
            IdConsulta, IdMedicamento, Dosis, Frecuencia, Duracion, ViaAdministracion, Indicaciones, PermiteSustitucion, FechaPrescripcion
        )
        VALUES (
            @IdConsultaDemo, @IdMedParacetamol, N'500 mg (1 tableta)', N'Cada 8 horas', N'Por 3 días', N'Oral',
            N'Tomar 1 tableta cada 8 horas después de las comidas en caso de fiebre o dolor corporal.', 1, DATEADD(DAY, -3, SYSDATETIME())
        );
        PRINT N'[+] Prescripción demo de Acetaminofén insertada.';
    END;

    -- Prescripción 2: Loratadina
    IF @IdMedLoratadina IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dbo.Prescripciones WHERE IdConsulta = @IdConsultaDemo AND IdMedicamento = @IdMedLoratadina)
    BEGIN
        INSERT INTO dbo.Prescripciones (
            IdConsulta, IdMedicamento, Dosis, Frecuencia, Duracion, ViaAdministracion, Indicaciones, PermiteSustitucion, FechaPrescripcion
        )
        VALUES (
            @IdConsultaDemo, @IdMedLoratadina, N'10 mg (1 tableta)', N'Cada 24 horas', N'Por 5 días', N'Oral',
            N'Tomar 1 tableta por las noches antes de acostarse para control de rinorrea y prurito nasal.', 0, DATEADD(DAY, -3, SYSDATETIME())
        );
        PRINT N'[+] Prescripción demo de Loratadina insertada.';
    END;
END;
GO


/* ==============================================================================
   14. AUDITORÍA Y RESUMEN FINAL DEL SEED DEMO
   ============================================================================== */
PRINT N'----------------------------------------------------------------------';
PRINT N'VERIFICACIÓN DEL ESTADO DE TABLAS EN ' + DB_NAME();
PRINT N'----------------------------------------------------------------------';

SELECT 'Roles' AS Entidad, COUNT(*) AS Registros FROM dbo.Roles
UNION ALL SELECT 'Usuarios', COUNT(*) FROM dbo.Usuarios
UNION ALL SELECT 'Administradores', COUNT(*) FROM dbo.Administradores
UNION ALL SELECT 'PersonalAdministrativo', COUNT(*) FROM dbo.PersonalAdministrativo
UNION ALL SELECT 'Doctores', COUNT(*) FROM dbo.Doctores
UNION ALL SELECT 'Pacientes', COUNT(*) FROM dbo.Pacientes
UNION ALL SELECT 'ContactosEmergencia', COUNT(*) FROM dbo.ContactosEmergencia
UNION ALL SELECT 'Departamentos', COUNT(*) FROM dbo.Departamentos
UNION ALL SELECT 'Municipios', COUNT(*) FROM dbo.Municipios
UNION ALL SELECT 'Comunidades', COUNT(*) FROM dbo.Comunidades
UNION ALL SELECT 'Hospitales', COUNT(*) FROM dbo.Hospitales
UNION ALL SELECT 'Especialidades', COUNT(*) FROM dbo.Especialidades
UNION ALL SELECT 'DoctorEspecialidad', COUNT(*) FROM dbo.DoctorEspecialidad
UNION ALL SELECT 'DoctorHospitalEspecialidad', COUNT(*) FROM dbo.DoctorHospitalEspecialidad
UNION ALL SELECT 'Enfermedades', COUNT(*) FROM dbo.Enfermedades
UNION ALL SELECT 'Sintomas', COUNT(*) FROM dbo.Sintomas
UNION ALL SELECT 'Enfermedades_Sintomas', COUNT(*) FROM dbo.Enfermedades_Sintomas
UNION ALL SELECT 'RecomendacionesMedicas', COUNT(*) FROM dbo.RecomendacionesMedicas
UNION ALL SELECT 'Medicamentos', COUNT(*) FROM dbo.Medicamentos
UNION ALL SELECT 'Citas', COUNT(*) FROM dbo.Citas
UNION ALL SELECT 'Consultas', COUNT(*) FROM dbo.Consultas
UNION ALL SELECT 'SignosVitales', COUNT(*) FROM dbo.SignosVitales
UNION ALL SELECT 'Diagnosticos', COUNT(*) FROM dbo.Diagnosticos
UNION ALL SELECT 'Prescripciones', COUNT(*) FROM dbo.Prescripciones;

PRINT N'----------------------------------------------------------------------';
PRINT N'05_Seed_Demo.sql completado satisfactoriamente.';
PRINT N'Credenciales demo de prueba para todos los usuarios: SanarRural2026!';
PRINT N'----------------------------------------------------------------------';
GO

SET NOEXEC OFF;
GO

