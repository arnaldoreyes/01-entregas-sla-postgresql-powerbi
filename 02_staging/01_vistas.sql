-- ============================================================
-- PASO 1 de 2 · Vistas de limpieza (staging)
-- Proyecto: Entregas y SLA (datos de Olist)
-- ============================================================
--
-- QUÉ HACE
--   Crea el esquema "staging" con 8 vistas que leen las tablas
--   crudas y las dejan listas para analizar: fechas convertidas a
--   día, reseñas sin repetir, categorías traducidas y banderas de
--   entrega (entregado, a tiempo, días de tránsito).
--
-- POR QUÉ VISTAS Y NO TABLAS
--   Una vista no guarda datos: se calcula cada vez que se consulta.
--   Así, si mañana se corrige algo en la carga, el análisis se
--   actualiza solo y nunca queda una copia vieja a medias. Además
--   se puede leer el cálculo, que es lo que hay que defender.
--
-- DÓNDE SE EJECUTA
--   En pgAdmin, con Query Tool sobre la base "entregas".
--
-- QUÉ QUEDA DESPUÉS
--   8 vistas en el esquema "staging". La revisión de conteos es el
--   paso 2 (02_verificacion.sql).
-- ============================================================

DROP SCHEMA IF EXISTS staging CASCADE;
CREATE SCHEMA staging;

BEGIN;

-- ------------------------------------------------------------
-- Vistas 1 y 2: clientes y vendedores
--   Solo se normaliza el estado (mayúsculas, sin espacios) y se
--   recorta la ciudad. Nada más: el resto se usa tal cual.
-- ------------------------------------------------------------
CREATE VIEW staging.clientes AS
SELECT
    cliente_id,
    cliente_unico_id,
    codigo_postal,
    trim(ciudad)       AS ciudad,
    upper(trim(estado)) AS estado
FROM olist.clientes;

CREATE VIEW staging.vendedores AS
SELECT
    vendedor_id,
    codigo_postal,
    trim(ciudad)        AS ciudad,
    upper(trim(estado)) AS estado
FROM olist.vendedores;

-- ------------------------------------------------------------
-- Vista 3: productos con categoría traducida
--   Si la categoría no tiene traducción (2 casos), se queda el
--   nombre en portugués. Si no hay categoría (610 casos), se
--   marca "sin_categoria". No se inventa ninguna.
-- ------------------------------------------------------------
CREATE VIEW staging.productos AS
SELECT
    p.producto_id,
    p.categoria                                   AS categoria_portugues,
    COALESCE(t.categoria_en, p.categoria, 'sin_categoria') AS categoria,
    (p.categoria IS NULL)                         AS sin_categoria,
    p.peso_g,
    p.largo_cm,
    p.alto_cm,
    p.ancho_cm,
    (p.peso_g IS NULL OR p.peso_g = 0)            AS peso_invalido
FROM olist.productos p
LEFT JOIN olist.categoria_traduccion t
       ON t.categoria = p.categoria;

-- ------------------------------------------------------------
-- Vista 4: pedidos con las banderas de entrega
--
--   en_universo  = el pedido entra al análisis (no es cancelado
--                  ni "unavailable"). Son 98.207.
--   entregado    = llegó de verdad: estado delivered Y fecha de
--                  entrega conocida. Son 96.470 (8 pedidos están
--                  delivered pero sin fecha; no se pueden medir).
--   a_tiempo     = la fecha de entrega (día) no pasa la fecha
--                  prometida (día). Se comparan DÍAS, no horas:
--                  la promesa es una fecha, no una hora.
--   dias_transito     = días entre compra y entrega.
--   dias_vs_promesa   = días de diferencia contra la promesa.
--                       Positivo = tarde; negativo = temprano.
--   Los tres cálculos quedan NULL si el pedido no se entregó.
-- ------------------------------------------------------------
CREATE VIEW staging.pedidos AS
SELECT
    p.pedido_id,
    p.cliente_id,
    p.estado_pedido,
    p.fecha_compra::date                  AS fecha_compra,
    p.fecha_aprobacion::date              AS fecha_aprobacion,
    p.fecha_entrega_transportista::date   AS fecha_entrega_transportista,
    p.fecha_entrega_cliente::date         AS fecha_entrega_cliente,
    p.fecha_estimada_entrega::date        AS fecha_estimada_entrega,
    (p.estado_pedido NOT IN ('canceled', 'unavailable')) AS en_universo,
    (p.estado_pedido = 'delivered' AND p.fecha_entrega_cliente IS NOT NULL) AS entregado,
    (p.estado_pedido = 'delivered' AND p.fecha_entrega_cliente IS NULL)     AS entregado_sin_fecha,
    CASE
        WHEN p.estado_pedido = 'delivered' AND p.fecha_entrega_cliente IS NOT NULL
        THEN (p.fecha_entrega_cliente::date - p.fecha_compra::date)
    END AS dias_transito,
    CASE
        WHEN p.estado_pedido = 'delivered' AND p.fecha_entrega_cliente IS NOT NULL
        THEN (p.fecha_entrega_cliente::date - p.fecha_estimada_entrega::date)
    END AS dias_vs_promesa,
    CASE
        WHEN p.estado_pedido = 'delivered' AND p.fecha_entrega_cliente IS NOT NULL
        THEN (p.fecha_entrega_cliente::date <= p.fecha_estimada_entrega::date)
    END AS a_tiempo
FROM olist.pedidos p;

-- ------------------------------------------------------------
-- Vista 5: una reseña por pedido
--   99.224 reseñas para 98.673 pedidos: 547 pedidos tienen 2 o 3.
--   Se queda la de fecha_respuesta más reciente (y si empatan, la
--   de resena_id mayor, para que el resultado sea siempre el mismo).
--   Sin esta deduplicación, el promedio de calificación queda
--   ponderado por los pedidos con reseña repetida.
-- ------------------------------------------------------------
CREATE VIEW staging.resenas AS
SELECT DISTINCT ON (pedido_id)
    pedido_id,
    resena_id,
    calificacion,
    titulo,
    comentario,
    fecha_creacion::date AS fecha_creacion,
    fecha_respuesta
FROM olist.resenas
ORDER BY pedido_id, fecha_respuesta DESC, resena_id DESC;

-- ------------------------------------------------------------
-- Vista 6: pagos resumidos por pedido
--   La tabla cruda tiene una fila por pago (103.886). Aquí se
--   agrupa a una fila por pedido para poder unirla sin multiplicar
--   filas. No se usa para el ingreso: el ingreso sale de los ítems.
-- ------------------------------------------------------------
CREATE VIEW staging.pagos AS
SELECT
    pedido_id,
    count(*)                                    AS pagos,
    sum(valor)                                  AS total_pagado,
    max(cuotas)                                 AS cuotas_max,
    (array_agg(tipo_pago ORDER BY valor DESC))[1] AS tipo_principal
FROM olist.pagos_pedido
GROUP BY pedido_id;

-- ------------------------------------------------------------
-- Vista 7: ítems con todo lo del pedido
--   Grano: un ítem. 112.650 filas. Aquí ya está el ingreso
--   (precio + flete), la categoría, el estado del cliente y del
--   vendedor, y las banderas de entrega.
--
--   OJO: la calificación se repite en cada ítem del mismo pedido.
--   Para promediar satisfacción se usa staging.resenas (una fila
--   por pedido), no esta vista.
-- ------------------------------------------------------------
CREATE VIEW staging.items AS
SELECT
    i.pedido_id,
    i.item_id,
    i.producto_id,
    i.vendedor_id,
    i.precio,
    i.flete,
    (i.precio + i.flete)          AS ingreso,
    p.fecha_compra,
    p.fecha_entrega_cliente,
    p.fecha_estimada_entrega,
    p.estado_pedido,
    p.en_universo,
    p.entregado,
    p.a_tiempo,
    p.dias_transito,
    p.dias_vs_promesa,
    pr.categoria,
    pr.peso_invalido,
    c.estado                      AS estado_cliente,
    v.estado                      AS estado_vendedor,
    r.calificacion
FROM olist.items_pedido i
JOIN staging.pedidos p      ON p.pedido_id   = i.pedido_id
JOIN staging.productos pr   ON pr.producto_id = i.producto_id
JOIN staging.clientes c     ON c.cliente_id  = p.cliente_id
JOIN staging.vendedores v   ON v.vendedor_id = i.vendedor_id
LEFT JOIN staging.resenas r ON r.pedido_id   = i.pedido_id;

-- ------------------------------------------------------------
-- Vista 8: pedidos con su reseña
--   Una fila por pedido (99.441), con la calificación ya
--   deduplicada. Es la vista natural para cruzar retraso con
--   satisfacción sin multiplicar filas.
-- ------------------------------------------------------------
CREATE VIEW staging.pedidos_resumen AS
SELECT
    p.*,
    r.calificacion,
    r.fecha_respuesta AS fecha_resena
FROM staging.pedidos p
LEFT JOIN staging.resenas r ON r.pedido_id = p.pedido_id;

COMMIT;

SELECT table_name AS "vista creada"
  FROM information_schema.views
 WHERE table_schema = 'staging'
 ORDER BY table_name;
