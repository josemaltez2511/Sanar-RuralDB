USE SanarRuralDB;
GO

/* =========================================================
   DATOS INICIALES - SANAR RURAL v1
   ========================================================= */

/* =========================
   1. ROLES
   ========================= */

INSERT INTO dbo.Roles (Nombre)
VALUES
    (N'Paciente'),
    (N'Doctor'),
    (N'Administrativo');
GO


/* =========================
   2. DEPARTAMENTO
   ========================= */

INSERT INTO dbo.Departamentos (Nombre)
VALUES
    (N'Masaya');
GO


/* =========================
   3. MUNICIPIO
   ========================= */

INSERT INTO dbo.Municipios
(
    IdDepartamento,
    Nombre
)
SELECT
    d.IdDepartamento,
    N'Tisma'
FROM dbo.Departamentos d
WHERE d.Nombre = N'Masaya';
GO


/* =========================
   4. COMUNIDAD
   ========================= */

INSERT INTO dbo.Comunidades
(
    IdMunicipio,
    Nombre
)
SELECT
    m.IdMunicipio,
    N'Las Cortezas'
FROM dbo.Municipios m
INNER JOIN dbo.Departamentos d
    ON d.IdDepartamento = m.IdDepartamento
WHERE d.Nombre = N'Masaya'
  AND m.Nombre = N'Tisma';
GO


/* =========================
   5. ESPECIALIDADES
   ========================= */

INSERT INTO dbo.Especialidades
(
    Nombre,
    Descripcion
)
VALUES
(
    N'Medicina General',
    N'Atención médica general y primer nivel de atención.'
),
(
    N'Pediatría',
    N'Atención médica especializada para niños y adolescentes.'
),
(
    N'Medicina Interna',
    N'Prevención, diagnóstico y tratamiento de enfermedades en adultos.'
),
(
    N'Cardiología',
    N'Prevención, diagnóstico y tratamiento de enfermedades cardiovasculares.'
),
(
    N'Ginecología y Obstetricia',
    N'Atención integral de la salud ginecológica y obstétrica.'
),
(
    N'Cirugía General',
    N'Atención y tratamiento de patologías que requieren manejo quirúrgico.'
);
GO

