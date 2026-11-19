-- ============================================================
-- PASO 1 · Cuadre del tablero contra SQL
-- Proyecto 1 — Entregas y SLA
-- ============================================================
--
-- QUÉ HACE
--   Recalcula en SQL cada número que muestra el tablero y lo
--   compara con el valor esperado. Devuelve una fila por control
--   con el estado: OK o REVISAR.
--
-- DÓNDE SE EJECUTA
--   En pgAdmin, Query Tool sobre la base "entregas".
--
-- CÓMO SE LEE
--   Si todas las filas dicen OK, el tablero cuadra con la base.
--   Si alguna dice REVISAR, ese número del tablero está mal y no
--   se publica hasta corregirlo.
-- ============================================================

WITH control AS (

    SELECT 'Pedidos en total' AS control,
           (SELECT count(*) FROM modelo.hecho_pedidos)::numeric AS valor,
           99441::numeric AS esperado

    UNION ALL
    SELECT 'Pedidos en el universo',
           (SELECT count(*) FROM modelo.hecho_pedidos WHERE en_universo)::numeric,
           98207

    UNION ALL
    SELECT 'Pedidos entregados con fecha',
           (SELECT count(*) FROM modelo.hecho_pedidos WHERE entregado)::numeric,
           96470

    UNION ALL
    SELECT 'Pedidos a tiempo',
           (SELECT count(*) FROM modelo.hecho_pedidos WHERE a_tiempo)::numeric,
           89936

    UNION ALL
    SELECT 'Pedidos tarde',
           (SELECT count(*) FROM modelo.hecho_pedidos WHERE a_tiempo IS FALSE)::numeric,
           6534

    UNION ALL
    SELECT 'OTIF %',
           (SELECT round(100.0 * count(*) FILTER (WHERE a_tiempo) / count(*), 2)
              FROM modelo.hecho_pedidos WHERE en_universo)::numeric,
           91.58

    UNION ALL
    SELECT '% tarde',
           (SELECT round(100.0 * count(*) FILTER (WHERE a_tiempo IS FALSE) / count(*), 2)
              FROM modelo.hecho_pedidos WHERE entregado)::numeric,
           6.77

    UNION ALL
    SELECT 'Días de tránsito: mediana',
           (SELECT percentile_cont(0.5) WITHIN GROUP (ORDER BY dias_transito)
              FROM modelo.hecho_pedidos WHERE entregado)::numeric,
           10

    UNION ALL
    SELECT 'Días de tránsito: p90',
           (SELECT percentile_cont(0.9) WITHIN GROUP (ORDER BY dias_transito)
              FROM modelo.hecho_pedidos WHERE entregado)::numeric,
           23

    UNION ALL
    SELECT 'Reseñas (una por pedido)',
           (SELECT count(calificacion) FROM modelo.hecho_pedidos)::numeric,
           98673

    UNION ALL
    SELECT 'Calificación promedio del universo',
           (SELECT round(avg(calificacion), 4)
              FROM modelo.hecho_pedidos WHERE en_universo)::numeric,
           4.1162

    UNION ALL
    SELECT 'Calificación cuando llega a tiempo',
           (SELECT round(avg(calificacion), 4)
              FROM modelo.hecho_pedidos WHERE estado_entrega_id = 1)::numeric,
           4.2904

    UNION ALL
    SELECT 'Calificación cuando llega tarde',
           (SELECT round(avg(calificacion), 4)
              FROM modelo.hecho_pedidos WHERE estado_entrega_id = 2)::numeric,
           2.2705

    UNION ALL
    SELECT 'Brecha de calificación',
           (SELECT round(
                avg(calificacion) FILTER (WHERE estado_entrega_id = 1)
              - avg(calificacion) FILTER (WHERE estado_entrega_id = 2), 4)
              FROM modelo.hecho_pedidos)::numeric,
           2.0199

    UNION ALL
    SELECT '% de 1 estrella cuando llega a tiempo',
           (SELECT round(100.0 * count(*) FILTER (WHERE calificacion = 1) / count(*), 1)
              FROM modelo.hecho_pedidos
             WHERE estado_entrega_id = 1 AND calificacion IS NOT NULL)::numeric,
           6.6

    UNION ALL
    SELECT '% de 1 estrella cuando llega tarde',
           (SELECT round(100.0 * count(*) FILTER (WHERE calificacion = 1) / count(*), 1)
              FROM modelo.hecho_pedidos
             WHERE estado_entrega_id = 2 AND calificacion IS NOT NULL)::numeric,
           53.8

    UNION ALL
    SELECT 'Pedidos tarde en SP + RJ',
           (SELECT count(*)
              FROM modelo.hecho_pedidos h
              JOIN modelo.dim_cliente c USING (cliente_id)
             WHERE h.estado_entrega_id = 2 AND c.estado IN ('SP', 'RJ'))::numeric,
           3315

    UNION ALL
    SELECT 'Ingreso total (precio + flete)',
           (SELECT round(sum(ingreso), 2) FROM modelo.hecho_items)::numeric,
           15843553.24

    UNION ALL
    SELECT 'Flete total',
           (SELECT round(sum(flete), 2) FROM modelo.hecho_items)::numeric,
           2251909.54

    UNION ALL
    SELECT '% tarde en AL',
           (SELECT round(100.0 * count(*) FILTER (WHERE h.estado_entrega_id = 2) / count(*), 2)
              FROM modelo.hecho_pedidos h
              JOIN modelo.dim_cliente c USING (cliente_id)
             WHERE c.estado = 'AL' AND h.entregado)::numeric,
           21.41

    UNION ALL
    SELECT '% tarde en MA',
           (SELECT round(100.0 * count(*) FILTER (WHERE h.estado_entrega_id = 2) / count(*), 2)
              FROM modelo.hecho_pedidos h
              JOIN modelo.dim_cliente c USING (cliente_id)
             WHERE c.estado = 'MA' AND h.entregado)::numeric,
           17.43

    UNION ALL
    SELECT '% tarde en SE',
           (SELECT round(100.0 * count(*) FILTER (WHERE h.estado_entrega_id = 2) / count(*), 2)
              FROM modelo.hecho_pedidos h
              JOIN modelo.dim_cliente c USING (cliente_id)
             WHERE c.estado = 'SE' AND h.entregado)::numeric,
           15.22
)

SELECT control,
       valor,
       esperado,
       CASE
           WHEN abs(valor - esperado) <= 0.01 THEN 'OK'
           ELSE 'REVISAR'
       END AS estado
  FROM control
 ORDER BY estado DESC, control;
