USE [SanarRuralDB];
GO

/* =========================================================
   SANAR RURAL v1
   SQL Server 2022
   Reconstrucción completa de la estructura
   ========================================================= */

SET NOCOUNT ON;
GO

/* =========================================================
   1. ELIMINAR TABLAS EXISTENTES
   ========================================================= */

DROP TABLE IF EXISTS dbo.Prescripciones;
DROP TABLE IF EXISTS dbo.Diagnosticos;
DROP TABLE IF EXISTS dbo.SignosVitales;
DROP TABLE IF EXISTS dbo.Consultas;
DROP TABLE IF EXISTS dbo.Citas;

DROP TABLE IF EXISTS dbo.Enfermedades_Sintomas;
DROP TABLE IF EXISTS dbo.RecomendacionesMedicas;

DROP TABLE IF EXISTS dbo.DoctorHospitalEspecialidad;
DROP TABLE IF EXISTS dbo.DoctorEspecialidad;

DROP TABLE IF EXISTS dbo.ContactosEmergencia;
DROP TABLE IF EXISTS dbo.Pacientes;
DROP TABLE IF EXISTS dbo.Doctores;

DROP TABLE IF EXISTS dbo.Hospitales;
DROP TABLE IF EXISTS dbo.Especialidades;

DROP TABLE IF EXISTS dbo.Medicamentos;
DROP TABLE IF EXISTS dbo.Sintomas;
DROP TABLE IF EXISTS dbo.Enfermedades;

DROP TABLE IF EXISTS dbo.Comunidades;
DROP TABLE IF EXISTS dbo.Municipios;
DROP TABLE IF EXISTS dbo.Departamentos;

DROP TABLE IF EXISTS dbo.Usuarios;
DROP TABLE IF EXISTS dbo.Roles;
GO


/* =========================================================
   2. ROLES
   ========================================================= */

CREATE TABLE dbo.Roles
(
    IdRol INT IDENTITY(1,1) NOT NULL,
    Nombre NVARCHAR(30) NOT NULL,

    CONSTRAINT PK_Roles
        PRIMARY KEY (IdRol),

    CONSTRAINT UQ_Roles_Nombre
        UNIQUE (Nombre)
);
GO


/* =========================================================
   3. USUARIOS
   ========================================================= */

CREATE TABLE dbo.Usuarios
(
    IdUsuario INT IDENTITY(1,1) NOT NULL,
    IdRol INT NOT NULL,
    Correo NVARCHAR(150) NOT NULL,
    ContrasenaHash NVARCHAR(255) NOT NULL,
    FechaRegistro DATETIME2 NOT NULL
        CONSTRAINT DF_Usuarios_FechaRegistro
        DEFAULT SYSDATETIME(),
    Estado BIT NOT NULL
        CONSTRAINT DF_Usuarios_Estado
        DEFAULT 1,

    CONSTRAINT PK_Usuarios
        PRIMARY KEY (IdUsuario),

    CONSTRAINT UQ_Usuarios_Correo
        UNIQUE (Correo),

    CONSTRAINT FK_Usuarios_Roles
        FOREIGN KEY (IdRol)
        REFERENCES dbo.Roles(IdRol)
);
GO


/* =========================================================
   4. DEPARTAMENTOS
   ========================================================= */

CREATE TABLE dbo.Departamentos
(
    IdDepartamento INT IDENTITY(1,1) NOT NULL,
    Nombre NVARCHAR(100) NOT NULL,

    CONSTRAINT PK_Departamentos
        PRIMARY KEY (IdDepartamento),

    CONSTRAINT UQ_Departamentos_Nombre
        UNIQUE (Nombre)
);
GO


/* =========================================================
   5. MUNICIPIOS
   ========================================================= */

CREATE TABLE dbo.Municipios
(
    IdMunicipio INT IDENTITY(1,1) NOT NULL,
    IdDepartamento INT NOT NULL,
    Nombre NVARCHAR(100) NOT NULL,

    CONSTRAINT PK_Municipios
        PRIMARY KEY (IdMunicipio),

    CONSTRAINT UQ_Municipios_Departamento_Nombre
        UNIQUE (IdDepartamento, Nombre),

    CONSTRAINT FK_Municipios_Departamentos
        FOREIGN KEY (IdDepartamento)
        REFERENCES dbo.Departamentos(IdDepartamento)
);
GO


/* =========================================================
   6. COMUNIDADES
   ========================================================= */

CREATE TABLE dbo.Comunidades
(
    IdComunidad INT IDENTITY(1,1) NOT NULL,
    IdMunicipio INT NOT NULL,
    Nombre NVARCHAR(150) NOT NULL,

    CONSTRAINT PK_Comunidades
        PRIMARY KEY (IdComunidad),

    CONSTRAINT UQ_Comunidades_Municipio_Nombre
        UNIQUE (IdMunicipio, Nombre),

    CONSTRAINT FK_Comunidades_Municipios
        FOREIGN KEY (IdMunicipio)
        REFERENCES dbo.Municipios(IdMunicipio)
);
GO


/* =========================================================
   7. PACIENTES
   ========================================================= */

CREATE TABLE dbo.Pacientes
(
    IdPaciente INT IDENTITY(1,1) NOT NULL,

    IdUsuario INT NULL,

    PrimerNombre NVARCHAR(50) NOT NULL,
    SegundoNombre NVARCHAR(50) NULL,
    PrimerApellido NVARCHAR(50) NOT NULL,
    SegundoApellido NVARCHAR(50) NULL,

    Cedula NVARCHAR(20) NULL,
    NumeroINSS NVARCHAR(30) NULL,

    FechaNacimiento DATE NOT NULL,
    Genero NVARCHAR(30) NULL,

    Telefono NVARCHAR(30) NULL,

    IdComunidad INT NOT NULL,
    Direccion NVARCHAR(300) NULL,

    TipoSangre NVARCHAR(5) NULL,

    Alergias NVARCHAR(1000) NULL,
    Antecedentes NVARCHAR(2000) NULL,

    Estado BIT NOT NULL
        CONSTRAINT DF_Pacientes_Estado
        DEFAULT 1,

    CONSTRAINT PK_Pacientes
        PRIMARY KEY (IdPaciente),

    CONSTRAINT FK_Pacientes_Usuarios
        FOREIGN KEY (IdUsuario)
        REFERENCES dbo.Usuarios(IdUsuario),

    CONSTRAINT FK_Pacientes_Comunidades
        FOREIGN KEY (IdComunidad)
        REFERENCES dbo.Comunidades(IdComunidad),

    CONSTRAINT CK_Pacientes_Genero
        CHECK
        (
            Genero IS NULL
            OR Genero IN
            (
                N'Femenino',
                N'Masculino',
                N'Otro',
                N'Prefiere no indicar'
            )
        ),

    CONSTRAINT CK_Pacientes_TipoSangre
        CHECK
        (
            TipoSangre IS NULL
            OR TipoSangre IN
            (
                N'A+',
                N'A-',
                N'B+',
                N'B-',
                N'AB+',
                N'AB-',
                N'O+',
                N'O-'
            )
        )
);
GO

/* Un usuario puede estar asociado como máximo a un paciente,
   pero puede haber muchos pacientes sin usuario. */
CREATE UNIQUE INDEX UX_Pacientes_IdUsuario
ON dbo.Pacientes(IdUsuario)
WHERE IdUsuario IS NOT NULL;
GO

/* La cédula puede ser NULL, pero no se permite duplicarla. */
CREATE UNIQUE INDEX UX_Pacientes_Cedula
ON dbo.Pacientes(Cedula)
WHERE Cedula IS NOT NULL;
GO

/* El INSS puede ser NULL, pero no se permite duplicarlo. */
CREATE UNIQUE INDEX UX_Pacientes_NumeroINSS
ON dbo.Pacientes(NumeroINSS)
WHERE NumeroINSS IS NOT NULL;
GO


/* =========================================================
   8. CONTACTOS DE EMERGENCIA
   ========================================================= */

CREATE TABLE dbo.ContactosEmergencia
(
    IdContactoEmergencia INT IDENTITY(1,1) NOT NULL,
    IdPaciente INT NOT NULL,

    PrimerNombre NVARCHAR(50) NOT NULL,
    SegundoNombre NVARCHAR(50) NULL,
    PrimerApellido NVARCHAR(50) NOT NULL,
    SegundoApellido NVARCHAR(50) NULL,

    Parentesco NVARCHAR(80) NOT NULL,
    Telefono NVARCHAR(30) NOT NULL,
    Cedula NVARCHAR(20) NULL,

    CONSTRAINT PK_ContactosEmergencia
        PRIMARY KEY (IdContactoEmergencia),

    CONSTRAINT FK_ContactosEmergencia_Pacientes
        FOREIGN KEY (IdPaciente)
        REFERENCES dbo.Pacientes(IdPaciente)
);
GO


/* =========================================================
   9. DOCTORES
   ========================================================= */

CREATE TABLE dbo.Doctores
(
    IdDoctor INT IDENTITY(1,1) NOT NULL,

    IdUsuario INT NULL,

    PrimerNombre NVARCHAR(50) NOT NULL,
    SegundoNombre NVARCHAR(50) NULL,
    PrimerApellido NVARCHAR(50) NOT NULL,
    SegundoApellido NVARCHAR(50) NULL,

    Cedula NVARCHAR(20) NOT NULL,
    NumeroLicencia NVARCHAR(50) NOT NULL,

    Telefono NVARCHAR(30) NULL,

    Foto VARBINARY(MAX) NULL,
    FotoNombre NVARCHAR(255) NULL,
    FotoMimeType NVARCHAR(100) NULL,

    Estado BIT NOT NULL
        CONSTRAINT DF_Doctores_Estado
        DEFAULT 1,

    CONSTRAINT PK_Doctores
        PRIMARY KEY (IdDoctor),

    CONSTRAINT FK_Doctores_Usuarios
        FOREIGN KEY (IdUsuario)
        REFERENCES dbo.Usuarios(IdUsuario),

    CONSTRAINT UQ_Doctores_Cedula
        UNIQUE (Cedula),

    CONSTRAINT UQ_Doctores_NumeroLicencia
        UNIQUE (NumeroLicencia)
);
GO

CREATE UNIQUE INDEX UX_Doctores_IdUsuario
ON dbo.Doctores(IdUsuario)
WHERE IdUsuario IS NOT NULL;
GO


/* =========================================================
   10. ESPECIALIDADES
   ========================================================= */

CREATE TABLE dbo.Especialidades
(
    IdEspecialidad INT IDENTITY(1,1) NOT NULL,
    Nombre NVARCHAR(100) NOT NULL,
    Descripcion NVARCHAR(500) NULL,
    Estado BIT NOT NULL
        CONSTRAINT DF_Especialidades_Estado
        DEFAULT 1,

    CONSTRAINT PK_Especialidades
        PRIMARY KEY (IdEspecialidad),

    CONSTRAINT UQ_Especialidades_Nombre
        UNIQUE (Nombre)
);
GO


/* =========================================================
   11. DOCTOR - ESPECIALIDAD
   ========================================================= */

CREATE TABLE dbo.DoctorEspecialidad
(
    IdDoctor INT NOT NULL,
    IdEspecialidad INT NOT NULL,

    CONSTRAINT PK_DoctorEspecialidad
        PRIMARY KEY (IdDoctor, IdEspecialidad),

    CONSTRAINT FK_DoctorEspecialidad_Doctor
        FOREIGN KEY (IdDoctor)
        REFERENCES dbo.Doctores(IdDoctor),

    CONSTRAINT FK_DoctorEspecialidad_Especialidad
        FOREIGN KEY (IdEspecialidad)
        REFERENCES dbo.Especialidades(IdEspecialidad)
);
GO


/* =========================================================
   12. HOSPITALES
   ========================================================= */

CREATE TABLE dbo.Hospitales
(
    IdHospital INT IDENTITY(1,1) NOT NULL,

    IdMunicipio INT NOT NULL,

    Nombre NVARCHAR(150) NOT NULL,
    Direccion NVARCHAR(300) NULL,
    Telefono NVARCHAR(30) NULL,

    Estado BIT NOT NULL
        CONSTRAINT DF_Hospitales_Estado
        DEFAULT 1,

    CONSTRAINT PK_Hospitales
        PRIMARY KEY (IdHospital),

    CONSTRAINT FK_Hospitales_Municipios
        FOREIGN KEY (IdMunicipio)
        REFERENCES dbo.Municipios(IdMunicipio),

    CONSTRAINT UQ_Hospitales_Municipio_Nombre
        UNIQUE (IdMunicipio, Nombre)
);
GO


/* =========================================================
   13. DOCTOR - HOSPITAL - ESPECIALIDAD
   ========================================================= */

CREATE TABLE dbo.DoctorHospitalEspecialidad
(
    IdDoctor INT NOT NULL,
    IdHospital INT NOT NULL,
    IdEspecialidad INT NOT NULL,

    CONSTRAINT PK_DoctorHospitalEspecialidad
        PRIMARY KEY
        (
            IdDoctor,
            IdHospital,
            IdEspecialidad
        ),

    CONSTRAINT FK_DHE_DoctorEspecialidad
        FOREIGN KEY
        (
            IdDoctor,
            IdEspecialidad
        )
        REFERENCES dbo.DoctorEspecialidad
        (
            IdDoctor,
            IdEspecialidad
        ),

    CONSTRAINT FK_DHE_Hospital
        FOREIGN KEY (IdHospital)
        REFERENCES dbo.Hospitales(IdHospital)
);
GO


/* =========================================================
   14. ENFERMEDADES
   ========================================================= */

CREATE TABLE dbo.Enfermedades
(
    IdEnfermedad INT IDENTITY(1,1) NOT NULL,
    NombreEnfermedad NVARCHAR(150) NOT NULL,
    Categoria NVARCHAR(100) NULL,
    Descripcion NVARCHAR(2000) NULL,

    Estado BIT NOT NULL
        CONSTRAINT DF_Enfermedades_Estado
        DEFAULT 1,

    CONSTRAINT PK_Enfermedades
        PRIMARY KEY (IdEnfermedad),

    CONSTRAINT UQ_Enfermedades_Nombre
        UNIQUE (NombreEnfermedad)
);
GO


/* =========================================================
   15. SINTOMAS
   ========================================================= */

CREATE TABLE dbo.Sintomas
(
    IdSintoma INT IDENTITY(1,1) NOT NULL,
    NombreSintoma NVARCHAR(150) NOT NULL,
    Descripcion NVARCHAR(500) NULL,

    Estado BIT NOT NULL
        CONSTRAINT DF_Sintomas_Estado
        DEFAULT 1,

    CONSTRAINT PK_Sintomas
        PRIMARY KEY (IdSintoma),

    CONSTRAINT UQ_Sintomas_Nombre
        UNIQUE (NombreSintoma)
);
GO


/* =========================================================
   16. ENFERMEDAD - SINTOMA
   ========================================================= */

CREATE TABLE dbo.Enfermedades_Sintomas
(
    IdEnfermedad INT NOT NULL,
    IdSintoma INT NOT NULL,

    CONSTRAINT PK_Enfermedades_Sintomas
        PRIMARY KEY
        (
            IdEnfermedad,
            IdSintoma
        ),

    CONSTRAINT FK_ES_Enfermedad
        FOREIGN KEY (IdEnfermedad)
        REFERENCES dbo.Enfermedades(IdEnfermedad)
        ON DELETE CASCADE,

    CONSTRAINT FK_ES_Sintoma
        FOREIGN KEY (IdSintoma)
        REFERENCES dbo.Sintomas(IdSintoma)
        ON DELETE CASCADE
);
GO


/* =========================================================
   17. RECOMENDACIONES MÉDICAS
   ========================================================= */

CREATE TABLE dbo.RecomendacionesMedicas
(
    IdRecomendacion INT IDENTITY(1,1) NOT NULL,
    IdEnfermedad INT NOT NULL,
    Descripcion NVARCHAR(1000) NOT NULL,

    Estado BIT NOT NULL
        CONSTRAINT DF_Recomendaciones_Estado
        DEFAULT 1,

    CONSTRAINT PK_RecomendacionesMedicas
        PRIMARY KEY (IdRecomendacion),

    CONSTRAINT FK_RecomendacionesMedicas_Enfermedades
        FOREIGN KEY (IdEnfermedad)
        REFERENCES dbo.Enfermedades(IdEnfermedad)
        ON DELETE CASCADE
);
GO


/* =========================================================
   18. MEDICAMENTOS
   ========================================================= */

CREATE TABLE dbo.Medicamentos
(
    IdMedicamento INT IDENTITY(1,1) NOT NULL,

    NombreMedicamento NVARCHAR(150) NOT NULL,
    PrincipioActivo NVARCHAR(150) NULL,
    Concentracion NVARCHAR(100) NULL,
    FormaFarmaceutica NVARCHAR(100) NULL,
    Fabricante NVARCHAR(150) NULL,

    Estado BIT NOT NULL
        CONSTRAINT DF_Medicamentos_Estado
        DEFAULT 1,

    CONSTRAINT PK_Medicamentos
        PRIMARY KEY (IdMedicamento)
);
GO


/* =========================================================
   19. CITAS
   ========================================================= */

CREATE TABLE dbo.Citas
(
    IdCita INT IDENTITY(1,1) NOT NULL,

    IdPaciente INT NOT NULL,
    IdDoctor INT NOT NULL,
    IdHospital INT NOT NULL,
    IdEspecialidad INT NOT NULL,

    FechaHoraProgramada DATETIME2 NOT NULL,

    Estado NVARCHAR(30) NOT NULL
        CONSTRAINT DF_Citas_Estado
        DEFAULT N'Pendiente',

    Motivo NVARCHAR(500) NOT NULL,

    FechaCreacion DATETIME2 NOT NULL
        CONSTRAINT DF_Citas_FechaCreacion
        DEFAULT SYSDATETIME(),

    CONSTRAINT PK_Citas
        PRIMARY KEY (IdCita),

    CONSTRAINT FK_Citas_Paciente
        FOREIGN KEY (IdPaciente)
        REFERENCES dbo.Pacientes(IdPaciente),

    CONSTRAINT FK_Citas_DoctorHospitalEspecialidad
        FOREIGN KEY
        (
            IdDoctor,
            IdHospital,
            IdEspecialidad
        )
        REFERENCES dbo.DoctorHospitalEspecialidad
        (
            IdDoctor,
            IdHospital,
            IdEspecialidad
        ),

    CONSTRAINT CK_Citas_Estado
        CHECK
        (
            Estado IN
            (
                N'Pendiente',
                N'Confirmada',
                N'Atendida',
                N'Cancelada',
                N'NoAsistio'
            )
        )
);
GO


/* =========================================================
   20. CONSULTAS
   ========================================================= */

CREATE TABLE dbo.Consultas
(
    IdConsulta INT IDENTITY(1,1) NOT NULL,

    IdCita INT NOT NULL,

    FechaHoraInicio DATETIME2 NOT NULL
        CONSTRAINT DF_Consultas_FechaHoraInicio
        DEFAULT SYSDATETIME(),

    FechaHoraFin DATETIME2 NULL,

    EstadoConsulta NVARCHAR(20) NOT NULL
        CONSTRAINT DF_Consultas_Estado
        DEFAULT N'En curso',

    PadecimientoActual NVARCHAR(2000) NULL,
    ExamenFisico NVARCHAR(2000) NULL,
    Observaciones NVARCHAR(2000) NULL,
    PlanSeguimiento NVARCHAR(2000) NULL,

    CONSTRAINT PK_Consultas
        PRIMARY KEY (IdConsulta),

    CONSTRAINT UQ_Consultas_IdCita
        UNIQUE (IdCita),

    CONSTRAINT FK_Consultas_Citas
        FOREIGN KEY (IdCita)
        REFERENCES dbo.Citas(IdCita),

    CONSTRAINT CK_Consultas_Estado
        CHECK
        (
            EstadoConsulta IN
            (
                N'En curso',
                N'Finalizada'
            )
        )
);
GO


/* =========================================================
   21. SIGNOS VITALES
   ========================================================= */

CREATE TABLE dbo.SignosVitales
(
    IdSignosVitales INT IDENTITY(1,1) NOT NULL,

    IdConsulta INT NOT NULL,

    PresionSistolica SMALLINT NULL,
    PresionDiastolica SMALLINT NULL,

    FrecuenciaCardiaca SMALLINT NULL,
    FrecuenciaRespiratoria SMALLINT NULL,

    Temperatura DECIMAL(4,1) NULL,
    SaturacionOxigeno DECIMAL(5,2) NULL,

    PesoKg DECIMAL(6,2) NULL,
    TallaCm DECIMAL(6,2) NULL,

    CONSTRAINT PK_SignosVitales
        PRIMARY KEY (IdSignosVitales),

    CONSTRAINT UQ_SignosVitales_IdConsulta
        UNIQUE (IdConsulta),

    CONSTRAINT FK_SignosVitales_Consultas
        FOREIGN KEY (IdConsulta)
        REFERENCES dbo.Consultas(IdConsulta)
);
GO


/* =========================================================
   22. DIAGNÓSTICOS
   ========================================================= */

CREATE TABLE dbo.Diagnosticos
(
    IdDiagnostico INT IDENTITY(1,1) NOT NULL,

    IdConsulta INT NOT NULL,
    IdEnfermedad INT NULL,

    TipoDiagnostico NVARCHAR(30) NOT NULL
        CONSTRAINT DF_Diagnosticos_Tipo
        DEFAULT N'Principal',

    Descripcion NVARCHAR(2000) NOT NULL,
    Observaciones NVARCHAR(2000) NULL,

    CONSTRAINT PK_Diagnosticos
        PRIMARY KEY (IdDiagnostico),

    CONSTRAINT FK_Diagnosticos_Consultas
        FOREIGN KEY (IdConsulta)
        REFERENCES dbo.Consultas(IdConsulta),

    CONSTRAINT FK_Diagnosticos_Enfermedades
        FOREIGN KEY (IdEnfermedad)
        REFERENCES dbo.Enfermedades(IdEnfermedad),

    CONSTRAINT CK_Diagnosticos_Tipo
        CHECK
        (
            TipoDiagnostico IN
            (
                N'Principal',
                N'Secundario',
                N'Presuntivo',
                N'Diferencial'
            )
        )
);
GO


/* =========================================================
   23. PRESCRIPCIONES
   ========================================================= */

CREATE TABLE dbo.Prescripciones
(
    IdPrescripcion INT IDENTITY(1,1) NOT NULL,

    IdConsulta INT NOT NULL,
    IdMedicamento INT NOT NULL,

    Dosis NVARCHAR(100) NULL,
    Frecuencia NVARCHAR(150) NULL,
    Duracion NVARCHAR(150) NULL,
    ViaAdministracion NVARCHAR(100) NULL,

    Indicaciones NVARCHAR(1000) NULL,

    PermiteSustitucion BIT NOT NULL
        CONSTRAINT DF_Prescripciones_PermiteSustitucion
        DEFAULT 0,

    FechaPrescripcion DATETIME2 NOT NULL
        CONSTRAINT DF_Prescripciones_Fecha
        DEFAULT SYSDATETIME(),

    CONSTRAINT PK_Prescripciones
        PRIMARY KEY (IdPrescripcion),

    CONSTRAINT FK_Prescripciones_Consultas
        FOREIGN KEY (IdConsulta)
        REFERENCES dbo.Consultas(IdConsulta),

    CONSTRAINT FK_Prescripciones_Medicamentos
        FOREIGN KEY (IdMedicamento)
        REFERENCES dbo.Medicamentos(IdMedicamento)
);
GO

/* =========================================================
   VERIFICACIÓN
   ========================================================= */

SELECT COUNT(*) AS TotalTablas
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_TYPE = 'BASE TABLE';
GO

SELECT TABLE_NAME
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_TYPE = 'BASE TABLE'
ORDER BY TABLE_NAME;
GO

SELECT COUNT(*) AS TotalClavesForaneas
FROM sys.foreign_keys;
GO
