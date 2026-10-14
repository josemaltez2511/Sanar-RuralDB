/* ==============================================================================
   SANAR RURAL - DATOS SEMILLA BASE E IDEMPOTENTES (CATÁLOGOS MAESTROS DE REFERENCIA)
   Motor: Microsoft SQL Server 2022
   Archivo: database/02_Seed.sql

   PRINCIPIOS Y REGLAS DE INTEGRIDAD:
     1. Totalmente idempotente: puede ejecutarse repetidamente sin duplicar registros
        ni generar violaciones de restricciones únicas (UQ_Roles_Nombre, UQ_Departamentos_Nombre, etc.).
     2. Catálogo de transición de 5 roles:
        - 4 definitivos: Paciente, Doctor, Personal_administrativo, Admin.
        - 1 histórico de transición: Administrativo.
     3. Catálogos geográficos y sanitarios de referencia:
        - Departamentos, Municipios y Comunidades rurales representativas.
        - Sedes hospitalarias y centros de salud primarios.
        - Especialidades médicas troncales.
        - Catálogo clínico integral: Enfermedades, Síntomas, Relaciones patológicas,
          Recomendaciones médicas y Medicamentos esenciales de atención primaria.
     4. Separación estricta: este archivo contiene exclusivamente datos maestros y de catálogo.
        Los datos transaccionales y de prueba ficticia (usuarios demo, citas, consultas)
        se gestionan en database/05_Seed_Demo.sql.
   ============================================================================== */

/* ==============================================================================
   VALIDACIÓN ESTRICTA DEL CONTEXTO DE BASE DE DATOS
   Evita cambios implícitos de contexto. Exige selección explícita de SanarRuralDB o SanarRuralDB_Dev.
   ============================================================================== */
IF DB_NAME() NOT IN (N'SanarRuralDB', N'SanarRuralDB_Dev')
BEGIN
    DECLARE @MensajeContexto NVARCHAR(500) =
        N'ERROR DE CONTEXTO: Este script debe ejecutarse explícitamente en "SanarRuralDB" o "SanarRuralDB_Dev". ' +
        N'Contexto actual detectado: ' + QUOTENAME(DB_NAME()) + N'. Seleccione la base de datos correcta antes de ejecutar.';
    RAISERROR(@MensajeContexto, 16, 1);
    SET NOEXEC ON;
END;
GO

SET NOCOUNT ON;
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

/* ==============================================================================
   1. ROLES (CATÁLOGO DE TRANSICIÓN)
   ============================================================================== */
INSERT INTO dbo.Roles (Nombre)
SELECT v.Nombre
FROM (VALUES
    (N'Paciente'),
    (N'Doctor'),
    (N'Personal_administrativo'),
    (N'Admin'),
    (N'Administrativo') -- Rol histórico conservado temporalmente para la fase de transición
) AS v(Nombre)
WHERE NOT EXISTS (
    SELECT 1 FROM dbo.Roles r WHERE r.Nombre = v.Nombre
);
GO


/* ==============================================================================
   2. DEPARTAMENTOS Y REGIONES AUTÓNOMAS (17 DIVISIONES DE PRIMER NIVEL)
   ============================================================================== */
/* NOTA DE INTEGRIDAD Y LIMITACIÓN SEMÁNTICA:
   La tabla física se denomina dbo.Departamentos en el esquema de base de datos,
   pero almacena tanto los 15 departamentos como las 2 regiones autónomas de Nicaragua
   (17 divisiones político-administrativas de primer nivel).
   Para no forzar un rediseño del esquema ni romper contratos de código existentes,
   se preserva el nombre de la tabla y se documenta para que la capa de presentación (UI)
   pueda rotular el selector como «Departamento / Región autónoma». */
INSERT INTO dbo.Departamentos (Nombre)
SELECT v.Nombre
FROM (VALUES
    (N'Boaco'),
    (N'Carazo'),
    (N'Chinandega'),
    (N'Chontales'),
    (N'Estelí'),
    (N'Granada'),
    (N'Jinotega'),
    (N'León'),
    (N'Madriz'),
    (N'Managua'),
    (N'Masaya'),
    (N'Matagalpa'),
    (N'Nueva Segovia'),
    (N'Rivas'),
    (N'Río San Juan'),
    (N'Región Autónoma de la Costa Caribe Norte'),
    (N'Región Autónoma de la Costa Caribe Sur')
) AS v(Nombre)
WHERE NOT EXISTS (
    SELECT 1 FROM dbo.Departamentos d WHERE d.Nombre = v.Nombre
);
GO


/* ==============================================================================
   3. MUNICIPIOS (153 MUNICIPIOS DE NICARAGUA)
   ============================================================================== */
INSERT INTO dbo.Municipios (IdDepartamento, Nombre)
SELECT d.IdDepartamento, v.Municipio
FROM (VALUES
    -- Boaco (6 municipios)
    (N'Boaco', N'Boaco'),
    (N'Boaco', N'Camoapa'),
    (N'Boaco', N'San José de los Remates'),
    (N'Boaco', N'San Lorenzo'),
    (N'Boaco', N'Santa Lucía'),
    (N'Boaco', N'Teustepe'),

    -- Carazo (8 municipios)
    (N'Carazo', N'Diriamba'),
    (N'Carazo', N'Dolores'),
    (N'Carazo', N'El Rosario'),
    (N'Carazo', N'Jinotepe'),
    (N'Carazo', N'La Conquista'),
    (N'Carazo', N'La Paz de Carazo'),
    (N'Carazo', N'San Marcos'),
    (N'Carazo', N'Santa Teresa'),

    -- Chinandega (13 municipios)
    (N'Chinandega', N'Chichigalpa'),
    (N'Chinandega', N'Chinandega'),
    (N'Chinandega', N'Cinco Pinos'),
    (N'Chinandega', N'Corinto'),
    (N'Chinandega', N'El Realejo'),
    (N'Chinandega', N'El Viejo'),
    (N'Chinandega', N'Posoltega'),
    (N'Chinandega', N'Puerto Morazán'),
    (N'Chinandega', N'San Francisco del Norte'),
    (N'Chinandega', N'San Pedro del Norte'),
    (N'Chinandega', N'Santo Tomás del Norte'),
    (N'Chinandega', N'Somotillo'),
    (N'Chinandega', N'Villanueva'),

    -- Chontales (10 municipios)
    (N'Chontales', N'Acoyapa'),
    (N'Chontales', N'Comalapa'),
    (N'Chontales', N'El Coral'),
    (N'Chontales', N'Juigalpa'),
    (N'Chontales', N'La Libertad'),
    (N'Chontales', N'San Francisco de Cuapa'),
    (N'Chontales', N'San Pedro de Lóvago'),
    (N'Chontales', N'Santo Domingo'),
    (N'Chontales', N'Santo Tomás'),
    (N'Chontales', N'Villa Sandino'),

    -- Estelí (6 municipios)
    (N'Estelí', N'Condega'),
    (N'Estelí', N'Estelí'),
    (N'Estelí', N'La Trinidad'),
    (N'Estelí', N'Pueblo Nuevo'),
    (N'Estelí', N'San Juan de Limay'),
    (N'Estelí', N'San Nicolás'),

    -- Granada (4 municipios)
    (N'Granada', N'Diriá'),
    (N'Granada', N'Diriomo'),
    (N'Granada', N'Granada'),
    (N'Granada', N'Nandaime'),

    -- Jinotega (8 municipios)
    (N'Jinotega', N'El Cuá'),
    (N'Jinotega', N'Jinotega'),
    (N'Jinotega', N'La Concordia'),
    (N'Jinotega', N'San José de Bocay'),
    (N'Jinotega', N'San Rafael del Norte'),
    (N'Jinotega', N'San Sebastián de Yalí'),
    (N'Jinotega', N'Santa María de Pantasma'),
    (N'Jinotega', N'Wiwilí de Jinotega'),

    -- León (10 municipios)
    (N'León', N'Achuapa'),
    (N'León', N'El Jicaral'),
    (N'León', N'El Sauce'),
    (N'León', N'La Paz Centro'),
    (N'León', N'Larreynaga'),
    (N'León', N'León'),
    (N'León', N'Nagarote'),
    (N'León', N'Quezalguaque'),
    (N'León', N'Santa Rosa del Peñón'),
    (N'León', N'Telica'),

    -- Madriz (9 municipios)
    (N'Madriz', N'Las Sabanas'),
    (N'Madriz', N'Palacagüina'),
    (N'Madriz', N'San José de Cusmapa'),
    (N'Madriz', N'San Juan de Río Coco'),
    (N'Madriz', N'San Lucas'),
    (N'Madriz', N'Somoto'),
    (N'Madriz', N'Telpaneca'),
    (N'Madriz', N'Totogalpa'),
    (N'Madriz', N'Yalagüina'),

    -- Managua (9 municipios)
    (N'Managua', N'Ciudad Sandino'),
    (N'Managua', N'El Crucero'),
    (N'Managua', N'Managua'),
    (N'Managua', N'Mateare'),
    (N'Managua', N'San Francisco Libre'),
    (N'Managua', N'San Rafael del Sur'),
    (N'Managua', N'Ticuantepe'),
    (N'Managua', N'Tipitapa'),
    (N'Managua', N'Villa El Carmen'),

    -- Masaya (9 municipios)
    (N'Masaya', N'Catarina'),
    (N'Masaya', N'La Concepción'),
    (N'Masaya', N'Masatepe'),
    (N'Masaya', N'Masaya'),
    (N'Masaya', N'Nandasmo'),
    (N'Masaya', N'Nindirí'),
    (N'Masaya', N'Niquinohomo'),
    (N'Masaya', N'San Juan de Oriente'),
    (N'Masaya', N'Tisma'),

    -- Matagalpa (13 municipios)
    (N'Matagalpa', N'Ciudad Darío'),
    (N'Matagalpa', N'El Tuma - La Dalia'),
    (N'Matagalpa', N'Esquipulas'),
    (N'Matagalpa', N'Matagalpa'),
    (N'Matagalpa', N'Matiguás'),
    (N'Matagalpa', N'Muy Muy'),
    (N'Matagalpa', N'Rancho Grande'),
    (N'Matagalpa', N'Río Blanco'),
    (N'Matagalpa', N'San Dionisio'),
    (N'Matagalpa', N'San Isidro'),
    (N'Matagalpa', N'San Ramón'),
    (N'Matagalpa', N'Sébaco'),
    (N'Matagalpa', N'Terrabona'),

    -- Nueva Segovia (12 municipios)
    (N'Nueva Segovia', N'Ciudad Antigua'),
    (N'Nueva Segovia', N'Dipilto'),
    (N'Nueva Segovia', N'El Jícaro'),
    (N'Nueva Segovia', N'Jalapa'),
    (N'Nueva Segovia', N'Macuelizo'),
    (N'Nueva Segovia', N'Mozonte'),
    (N'Nueva Segovia', N'Murra'),
    (N'Nueva Segovia', N'Ocotal'),
    (N'Nueva Segovia', N'Quilalí'),
    (N'Nueva Segovia', N'San Fernando'),
    (N'Nueva Segovia', N'Santa María'),
    (N'Nueva Segovia', N'Wiwilí de Nueva Segovia'),

    -- Río San Juan (6 municipios)
    (N'Río San Juan', N'El Almendro'),
    (N'Río San Juan', N'El Castillo'),
    (N'Río San Juan', N'Morrito'),
    (N'Río San Juan', N'San Carlos'),
    (N'Río San Juan', N'San Juan de Nicaragua'),
    (N'Río San Juan', N'San Miguelito'),

    -- Rivas (10 municipios)
    (N'Rivas', N'Altagracia'),
    (N'Rivas', N'Belén'),
    (N'Rivas', N'Buenos Aires'),
    (N'Rivas', N'Cárdenas'),
    (N'Rivas', N'Moyogalpa'),
    (N'Rivas', N'Potosí'),
    (N'Rivas', N'Rivas'),
    (N'Rivas', N'San Jorge'),
    (N'Rivas', N'San Juan del Sur'),
    (N'Rivas', N'Tola'),

    -- Región Autónoma de la Costa Caribe Norte (8 municipios)
    (N'Región Autónoma de la Costa Caribe Norte', N'Bonanza'),
    (N'Región Autónoma de la Costa Caribe Norte', N'Mulukukú'),
    (N'Región Autónoma de la Costa Caribe Norte', N'Prinzapolka'),
    (N'Región Autónoma de la Costa Caribe Norte', N'Puerto Cabezas'),
    (N'Región Autónoma de la Costa Caribe Norte', N'Rosita'),
    (N'Región Autónoma de la Costa Caribe Norte', N'Siuna'),
    (N'Región Autónoma de la Costa Caribe Norte', N'Waslala'),
    (N'Región Autónoma de la Costa Caribe Norte', N'Waspam'),

    -- Región Autónoma de la Costa Caribe Sur (12 municipios)
    (N'Región Autónoma de la Costa Caribe Sur', N'Bluefields'),
    (N'Región Autónoma de la Costa Caribe Sur', N'Bocana de Paiwas'),
    (N'Región Autónoma de la Costa Caribe Sur', N'Corn Island'),
    (N'Región Autónoma de la Costa Caribe Sur', N'Desembocadura de Río Grande'),
    (N'Región Autónoma de la Costa Caribe Sur', N'El Ayote'),
    (N'Región Autónoma de la Costa Caribe Sur', N'El Rama'),
    (N'Región Autónoma de la Costa Caribe Sur', N'El Tortuguero'),
    (N'Región Autónoma de la Costa Caribe Sur', N'Kukra Hill'),
    (N'Región Autónoma de la Costa Caribe Sur', N'La Cruz de Río Grande'),
    (N'Región Autónoma de la Costa Caribe Sur', N'Laguna de Perlas'),
    (N'Región Autónoma de la Costa Caribe Sur', N'Muelle de los Bueyes'),
    (N'Región Autónoma de la Costa Caribe Sur', N'Nueva Guinea')
) AS v(Departamento, Municipio)
INNER JOIN dbo.Departamentos d ON d.Nombre = v.Departamento
WHERE NOT EXISTS (
    SELECT 1 FROM dbo.Municipios m
    WHERE m.IdDepartamento = d.IdDepartamento AND m.Nombre = v.Municipio
);
GO


/* ==============================================================================
   4. COMUNIDADES
   ============================================================================== */
INSERT INTO dbo.Comunidades (IdMunicipio, Nombre)
SELECT m.IdMunicipio, v.Comunidad
FROM (VALUES
    -- Tisma
    (N'Masaya', N'Tisma', N'Las Cortezas'),
    (N'Masaya', N'Tisma', N'El Carmen'),
    (N'Masaya', N'Tisma', N'Monte Verde'),
    -- Masaya
    (N'Masaya', N'Masaya', N'Monimbó'),
    (N'Masaya', N'Masaya', N'San Jerónimo'),
    -- Nindirí
    (N'Masaya', N'Nindirí', N'Veracruz'),
    -- Tipitapa
    (N'Managua', N'Tipitapa', N'Las Banderas'),
    -- Granada
    (N'Granada', N'Granada', N'Malacatoya')
) AS v(Departamento, Municipio, Comunidad)
INNER JOIN dbo.Departamentos d ON d.Nombre = v.Departamento
INNER JOIN dbo.Municipios m ON m.IdDepartamento = d.IdDepartamento AND m.Nombre = v.Municipio
WHERE NOT EXISTS (
    SELECT 1 FROM dbo.Comunidades c
    WHERE c.IdMunicipio = m.IdMunicipio AND c.Nombre = v.Comunidad
);
GO


/* ==============================================================================
   5. ESPECIALIDADES MÉDICAS
   ============================================================================== */
INSERT INTO dbo.Especialidades (Nombre, Descripcion)
SELECT v.Nombre, v.Descripcion
FROM (VALUES
    (N'Medicina General', N'Atención médica integral primaria y primer nivel de atención preventiva.'),
    (N'Pediatría', N'Atención médica especializada para el crecimiento y desarrollo infantil y adolescente.'),
    (N'Medicina Interna', N'Prevención, diagnóstico y tratamiento integral de patologías crónicas y agudas en adultos.'),
    (N'Cardiología', N'Prevención, diagnóstico y tratamiento de enfermedades cardiovasculares e hipertensión.'),
    (N'Ginecología y Obstetricia', N'Atención integral de la salud femenina, control prenatal y salud reproductiva.'),
    (N'Cirugía General', N'Evaluación clínica y resolución quirúrgica de patologías abdominales y de partes blandas.'),
    (N'Odontología', N'Atención preventiva, profiláctica y terapéutica de la salud bucodental comunitaria.'),
    (N'Nutrición', N'Orientación nutricional comunitaria, manejo de malnutrición y dietoterapia clínica.')
) AS v(Nombre, Descripcion)
WHERE NOT EXISTS (
    SELECT 1 FROM dbo.Especialidades e WHERE e.Nombre = v.Nombre
);
GO


/* ==============================================================================
   6. HOSPITALES Y CENTROS DE SALUD
   ============================================================================== */
INSERT INTO dbo.Hospitales (IdMunicipio, Nombre, Direccion, Telefono, Estado)
SELECT m.IdMunicipio, v.Nombre, v.Direccion, v.Telefono, 1
FROM (VALUES
    (N'Masaya', N'Tisma', N'Hospital Primario Tisma', N'Costado sur del parque central, Tisma', N'2522-1100'),
    (N'Masaya', N'Masaya', N'Hospital Departamental Hilario Sánchez Vásquez', N'Entrada principal a Masaya, Km 28 Carretera a Granada', N'2522-2200'),
    (N'Masaya', N'Nindirí', N'Centro de Salud Enrique Cisne', N'De la iglesia Santa Ana 2 cuadras al norte, Nindirí', N'2522-3300'),
    (N'Managua', N'Tipitapa', N'Hospital Primario Yolanda Mayorga', N'Km 21 Carretera Panamericana Norte, Tipitapa', N'2295-4400')
) AS v(Departamento, Municipio, Nombre, Direccion, Telefono)
INNER JOIN dbo.Departamentos d ON d.Nombre = v.Departamento
INNER JOIN dbo.Municipios m ON m.IdDepartamento = d.IdDepartamento AND m.Nombre = v.Municipio
WHERE NOT EXISTS (
    SELECT 1 FROM dbo.Hospitales h
    WHERE h.IdMunicipio = m.IdMunicipio AND h.Nombre = v.Nombre
);
GO


/* ==============================================================================
   7. ENFERMEDADES COMUNES
   ============================================================================== */
INSERT INTO dbo.Enfermedades (NombreEnfermedad, Categoria, Descripcion, Estado)
SELECT v.NombreEnfermedad, v.Categoria, v.Descripcion, 1
FROM (VALUES
    (N'Hipertensión Arterial', N'Cardiovascular', N'Enfermedad crónica caracterizada por elevación persistente de la presión arterial sistémica.'),
    (N'Diabetes Mellitus Tipo 2', N'Endocrina y Metabólica', N'Trastorno metabólico caracterizado por hiperglucemia debida a resistencia a la insulina.'),
    (N'Infección Respiratoria Aguda', N'Respiratoria', N'Afección viral o bacteriana de las vías respiratorias superiores e inferiores de instauración rápida.'),
    (N'Dengue Clásico', N'Infecciosa y Vectorial', N'Infección vírica transmitida por la picadura del mosquito hembra infectado del género Aedes.'),
    (N'Parasitosis Intestinal', N'Gastrointestinal', N'Infección por helmintos o protozoarios intestinales común en zonas rurales sin saneamiento integral.'),
    (N'Gastroenteritis Aguda', N'Gastrointestinal', N'Inflamación de la mucosa gástrica e intestinal con diarrea, vómitos y riesgo de deshidratación.'),
    (N'Neumonía Adquirida en la Comunidad', N'Respiratoria', N'Infección del parénquima pulmonar con afectación alveolar y compromiso respiratorio.'),
    (N'Dermatitis de Contacto', N'Dermatológica', N'Inflamación de la piel inducida por exposición a sustancias irritantes o alérgenos locales.')
) AS v(NombreEnfermedad, Categoria, Descripcion)
WHERE NOT EXISTS (
    SELECT 1 FROM dbo.Enfermedades enf WHERE enf.NombreEnfermedad = v.NombreEnfermedad
);
GO


/* ==============================================================================
   8. SÍNTOMAS CLÍNICOS
   ============================================================================== */
INSERT INTO dbo.Sintomas (NombreSintoma, Descripcion, Estado)
SELECT v.NombreSintoma, v.Descripcion, 1
FROM (VALUES
    (N'Cefalea', N'Dolor de cabeza de intensidad variable, frontal, temporal u occipital.'),
    (N'Mareos', N'Sensación subjetiva de inestabilidad, aturdimiento o alteración del equilibrio.'),
    (N'Tinnitus', N'Percepción auditiva de zumbidos, timbres o ruidos sin fuente externa real.'),
    (N'Fiebre', N'Elevación patológica de la temperatura corporal por encima de 38.0 °C axilar.'),
    (N'Tos persistente', N'Expulsión súbita y ruidosa de aire con o sin expectoración mucosa.'),
    (N'Dolor abdominal', N'Molestia o espasmo doloroso referido en cualquier cuadrante abdominal.'),
    (N'Náuseas y vómitos', N'Sensación inminente de vomitar y expulsión retrógrada del contenido gástrico.'),
    (N'Diarrea acuosa', N'Aumento de frecuencia y disminución de consistencia en evacuaciones líquidas.'),
    (N'Dificultad respiratoria', N'Disnea o sensación subjetiva de falta de aire y trabajo respiratorio aumentado.'),
    (N'Prurito cutáneo', N'Sensación de picor cutáneo que provoca necesidad imperiosa de rascado.'),
    (N'Fatiga y astenia', N'Sensación generalizada de cansancio extremo, debilidad y falta de energía.')
) AS v(NombreSintoma, Descripcion)
WHERE NOT EXISTS (
    SELECT 1 FROM dbo.Sintomas s WHERE s.NombreSintoma = v.NombreSintoma
);
GO


/* ==============================================================================
   9. ENFERMEDADES - SÍNTOMAS (ASOCIACIÓN CLÍNICA)
   ============================================================================== */
INSERT INTO dbo.Enfermedades_Sintomas (IdEnfermedad, IdSintoma)
SELECT enf.IdEnfermedad, st.IdSintoma
FROM (VALUES
    (N'Hipertensión Arterial', N'Cefalea'),
    (N'Hipertensión Arterial', N'Mareos'),
    (N'Hipertensión Arterial', N'Tinnitus'),
    (N'Diabetes Mellitus Tipo 2', N'Fatiga y astenia'),
    (N'Diabetes Mellitus Tipo 2', N'Mareos'),
    (N'Infección Respiratoria Aguda', N'Fiebre'),
    (N'Infección Respiratoria Aguda', N'Tos persistente'),
    (N'Infección Respiratoria Aguda', N'Cefalea'),
    (N'Dengue Clásico', N'Fiebre'),
    (N'Dengue Clásico', N'Cefalea'),
    (N'Dengue Clásico', N'Fatiga y astenia'),
    (N'Parasitosis Intestinal', N'Dolor abdominal'),
    (N'Parasitosis Intestinal', N'Náuseas y vómitos'),
    (N'Gastroenteritis Aguda', N'Diarrea acuosa'),
    (N'Gastroenteritis Aguda', N'Dolor abdominal'),
    (N'Gastroenteritis Aguda', N'Náuseas y vómitos'),
    (N'Neumonía Adquirida en la Comunidad', N'Fiebre'),
    (N'Neumonía Adquirida en la Comunidad', N'Tos persistente'),
    (N'Neumonía Adquirida en la Comunidad', N'Dificultad respiratoria'),
    (N'Dermatitis de Contacto', N'Prurito cutáneo')
) AS v(NombreEnfermedad, NombreSintoma)
INNER JOIN dbo.Enfermedades enf ON enf.NombreEnfermedad = v.NombreEnfermedad
INNER JOIN dbo.Sintomas st ON st.NombreSintoma = v.NombreSintoma
WHERE NOT EXISTS (
    SELECT 1 FROM dbo.Enfermedades_Sintomas es
    WHERE es.IdEnfermedad = enf.IdEnfermedad AND es.IdSintoma = st.IdSintoma
);
GO


/* ==============================================================================
   10. RECOMENDACIONES MÉDICAS
   ============================================================================== */
INSERT INTO dbo.RecomendacionesMedicas (IdEnfermedad, Descripcion, Estado)
SELECT enf.IdEnfermedad, v.Descripcion, 1
FROM (VALUES
    (N'Hipertensión Arterial', N'Reducir consumo de sal a menos de 5g/día, evitar grasas saturadas y realizar 30 min de caminata diaria.'),
    (N'Hipertensión Arterial', N'Monitorear la presión arterial en ayunas dos veces por semana y acudir si supera 140/90 mmHg.'),
    (N'Diabetes Mellitus Tipo 2', N'Mantener dieta fraccionada baja en azúcares refinados, rica en fibra vegetal y realizar control glucémico periódico.'),
    (N'Infección Respiratoria Aguda', N'Mantener hidratación oral continua con agua hervida, reposo relativo y lavado frecuente de manos con jabón.'),
    (N'Dengue Clásico', N'Ingerir abundantes líquidos orales (suero, agua de coco), guardar reposo absoluto bajo mosquitero y no automedicarse con aspirina ni AINEs.'),
    (N'Parasitosis Intestinal', N'Hervir el agua de consumo, lavar minuciosamente frutas y vegetales, y desparasitar a todo el núcleo familiar conviviente.'),
    (N'Gastroenteritis Aguda', N'Iniciar terapia de rehidratación oral con SRO tras cada evacuación líquida y mantener alimentación blanda según tolerancia.'),
    (N'Neumonía Adquirida en la Comunidad', N'Cumplir estrictamente el esquema antibiótico prescrito y vigilar signos de alarma como dificultad respiratoria o cianosis.'),
    (N'Dermatitis de Contacto', N'Evitar el contacto directo con químicos o plantas irritantes, usar guantes de protección y aplicar cremas emolientes.')
) AS v(NombreEnfermedad, Descripcion)
INNER JOIN dbo.Enfermedades enf ON enf.NombreEnfermedad = v.NombreEnfermedad
WHERE NOT EXISTS (
    SELECT 1 FROM dbo.RecomendacionesMedicas rm
    WHERE rm.IdEnfermedad = enf.IdEnfermedad AND rm.Descripcion = v.Descripcion
);
GO


/* ==============================================================================
   11. MEDICAMENTOS ESENCIALES
   ============================================================================== */
INSERT INTO dbo.Medicamentos (NombreMedicamento, PrincipioActivo, Concentracion, FormaFarmaceutica, Fabricante, Estado)
SELECT v.NombreMedicamento, v.PrincipioActivo, v.Concentracion, v.FormaFarmaceutica, v.Fabricante, 1
FROM (VALUES
    (N'Enalapril 20mg', N'Maleato de Enalapril', N'20 mg', N'Tableta oral', N'Laboratorios Ramos', 1),
    (N'Losartán 50mg', N'Losartán Potásico', N'50 mg', N'Tableta oral', N'Laboratorios Ramos', 1),
    (N'Metformina 850mg', N'Clorhidrato de Metformina', N'850 mg', N'Tableta oral', N'Laboratorios Ramos', 1),
    (N'Acetaminofén 500mg', N'Paracetamol', N'500 mg', N'Tableta oral', N'Laboratorios Ramos', 1),
    (N'Amoxicilina 500mg', N'Amoxicilina Trihidrato', N'500 mg', N'Cápsula oral', N'Laboratorios Ramos', 1),
    (N'Sales de Rehidratación Oral (SRO)', N'Glucosa anhidra, Cloruro de sodio, Citrato trisódico, Cloruro de potasio', N'Sobre para 1 Litro', N'Polvo para solución oral', N'MINSA', 1),
    (N'Albendazol 400mg', N'Albendazol', N'400 mg', N'Tableta masticable', N'Laboratorios Ramos', 1),
    (N'Salbutamol 100mcg Aerosol', N'Sulfato de Salbutamol', N'100 mcg / dosis', N'Aerosol para inhalación', N'Laboratorios Rarpe', 1),
    (N'Loratadina 10mg', N'Loratadina', N'10 mg', N'Tableta oral', N'Laboratorios Ramos', 1),
    (N'Hidrocortisona Crema 1%', N'Acetato de Hidrocortisona', N'1 % (10 mg/g)', N'Crema tópica', N'Laboratorios Rarpe', 1)
) AS v(NombreMedicamento, PrincipioActivo, Concentracion, FormaFarmaceutica, Fabricante, Estado)
WHERE NOT EXISTS (
    SELECT 1 FROM dbo.Medicamentos med WHERE med.NombreMedicamento = v.NombreMedicamento
);
GO

/* ==============================================================================
   12. COMPROBACIONES Y VERIFICACIONES DE INTEGRIDAD (POST-SEED)
   ============================================================================== */
DECLARE @TotalDeptos INT = (SELECT COUNT(*) FROM dbo.Departamentos);
DECLARE @TotalMpios INT = (SELECT COUNT(*) FROM dbo.Municipios);
DECLARE @MpiosCarazo INT = (
    SELECT COUNT(*)
    FROM dbo.Municipios m
    INNER JOIN dbo.Departamentos d ON m.IdDepartamento = d.IdDepartamento
    WHERE d.Nombre = N'Carazo'
);

PRINT N'------------------------------------------------------------------------------';
PRINT N'VERIFICACIÓN DE CATÁLOGOS GEOGRÁFICOS:';
PRINT N'  - Departamentos y Regiones Autónomas registrados: ' + CAST(@TotalDeptos AS NVARCHAR(10)) + N' (Esperados: 17)';
PRINT N'  - Municipios totales registrados:                ' + CAST(@TotalMpios AS NVARCHAR(10)) + N' (Esperados: 153)';
PRINT N'  - Municipios de Carazo registrados:              ' + CAST(@MpiosCarazo AS NVARCHAR(10)) + N' (Esperados: 8)';

-- Comprobación de duplicados en Departamentos
IF EXISTS (SELECT Nombre FROM dbo.Departamentos GROUP BY Nombre HAVING COUNT(*) > 1)
BEGIN
    RAISERROR(N'ALERTA DE INTEGRIDAD: Se detectaron nombres duplicados en dbo.Departamentos.', 16, 1);
END;

-- Comprobación de duplicados en Municipios por Departamento
IF EXISTS (SELECT IdDepartamento, Nombre FROM dbo.Municipios GROUP BY IdDepartamento, Nombre HAVING COUNT(*) > 1)
BEGIN
    RAISERROR(N'ALERTA DE INTEGRIDAD: Se detectaron municipios duplicados dentro del mismo departamento.', 16, 1);
END;

-- Verificación estricta de Carazo (los 8 municipios requeridos)
DECLARE @CarazoFaltantes INT = (
    SELECT COUNT(*)
    FROM (VALUES
        (N'Jinotepe'), (N'Diriamba'), (N'Dolores'), (N'El Rosario'),
        (N'La Paz de Carazo'), (N'La Conquista'), (N'San Marcos'), (N'Santa Teresa')
    ) AS esperados(Municipio)
    WHERE NOT EXISTS (
        SELECT 1
        FROM dbo.Municipios m
        INNER JOIN dbo.Departamentos d ON m.IdDepartamento = d.IdDepartamento
        WHERE d.Nombre = N'Carazo' AND m.Nombre = esperados.Municipio
    )
);

IF @CarazoFaltantes > 0
BEGIN
    RAISERROR(N'ALERTA DE INTEGRIDAD: Faltan municipios obligatorios en el departamento de Carazo.', 16, 1);
END;

IF @TotalDeptos < 17 OR @TotalMpios < 153 OR @MpiosCarazo <> 8
BEGIN
    RAISERROR(N'ALERTA DE INTEGRIDAD: Los conteos geográficos no cumplen los criterios oficiales (17 divisiones de 1er nivel, 153 municipios, 8 en Carazo).', 16, 1);
END;
GO

PRINT N'02_Seed.sql: Catálogos maestros de referencia cargados/verificados con éxito (17 departamentos/regiones y 153 municipios).';
GO

SET NOEXEC OFF;
GO
