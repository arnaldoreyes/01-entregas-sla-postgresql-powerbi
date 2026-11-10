-- ============================================================
-- PASO 1 de 3 · Crear la base de datos vacía
-- Proyecto: Entregas y SLA (datos de Olist)
-- ============================================================
--
-- QUÉ HACE
--   Borra la base "entregas" si ya existía y la vuelve a crear,
--   vacía. Es como estrenar un cuaderno nuevo: la tapa existe,
--   pero todavía no hay hojas escritas.
--
-- DÓNDE SE EJECUTA
--   En pgAdmin, conectado a la base "postgres" (la que PostgreSQL
--   trae de fábrica). Tiene que ser ahí y no en "entregas", porque
--   una base de datos no se puede crear desde dentro de sí misma.
--
-- QUÉ QUEDA DESPUÉS
--   En el panel de la izquierda de pgAdmin aparece "entregas".
--   Todavía no tiene tablas: eso lo hace el paso 2.
-- ============================================================

-- "IF EXISTS" significa: si la base no existe, no te quejes.
-- "WITH (FORCE)" cierra las conexiones abiertas antes de borrarla
-- (por ejemplo, una pestaña de pgAdmin que la tenga abierta).
DROP DATABASE IF EXISTS entregas WITH (FORCE);

-- UTF8: el formato de texto que entiende los acentos del portugués
-- ("São Paulo", "Roraima"). LOCALE 'C': evita un choque típico de
-- Windows entre el idioma del sistema y UTF8. No afecta los números
-- ni las fechas; solo cómo se ordena el texto, y aquí no ordenamos.
CREATE DATABASE entregas
    WITH TEMPLATE = template0
         ENCODING = 'UTF8'
         LOCALE   = 'C';

-- Un mensaje para confirmar que el paso terminó bien.
SELECT 'Listo: la base entregas existe y está vacía. Sigue con el paso 2.' AS resultado;
