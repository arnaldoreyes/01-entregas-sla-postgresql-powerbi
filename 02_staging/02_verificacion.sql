-- ============================================================
-- PASO 2 de 2 · Verificación de la limpieza
-- Proyecto: Entregas y SLA (datos de Olist)
-- ============================================================
--
-- QUÉ HACE
--   Revisa, uno por uno, los números que la fase de staging debe
--   dejar. Devuelve una sola tabla: control / valor.
--
--   Si un valor no coincide con docs/bitacora-limpieza.md, algo
--   cambió en los datos o en las vistas: hay que revisarlo antes
--   de seguir al modelo.
--
-- DÓNDE SE EJECUTA
--   En pgAdmin, con Query Tool sobre la base "entregas", después
--   de correr 01_vistas.sql.
-- ============================================================

SELECT control, valor
FROM (
    SELECT 1 AS orden, 'pedidos en total' AS control,
           count(*)::text AS valor
      FROM staging.pedidos

    UNION ALL
    SELECT 2, 'pedidos en el universo (sin cancelados ni no disponibles)',
           count(*)::text
      FROM staging.pedidos WHERE en_universo

    UNION ALL
    SELECT 3, 'pedidos entregados (con fecha real)',
           count(*)::text
      FROM staging.pedidos WHERE entregado

    UNION ALL
    SELECT 4, 'entregados marcados delivered pero sin fecha',
           count(*)::text
      FROM staging.pedidos WHERE entregado_sin_fecha

    UNION ALL
    SELECT 5, 'pedidos del universo sin entrega confirmada',
           count(*)::text
      FROM staging.pedidos WHERE en_universo AND NOT entregado

    UNION ALL
    SELECT 6, 'entregados a tiempo',
           count(*)::text
      FROM staging.pedidos WHERE a_tiempo

    UNION ALL
    SELECT 7, 'entregados tarde',
           count(*)::text
      FROM staging.pedidos WHERE a_tiempo IS FALSE

    UNION ALL
    SELECT 8, 'OTIF % (a tiempo y completos / universo)',
           round(100.0 * count(*) FILTER (WHERE a_tiempo) / count(*), 2)::text
      FROM staging.pedidos WHERE en_universo

    UNION ALL
    SELECT 9, '% a tiempo sobre entregados',
           round(100.0 * count(*) FILTER (WHERE a_tiempo) / count(*), 2)::text
      FROM staging.pedidos WHERE entregado

    UNION ALL
    SELECT 10, 'días de tránsito: mediana',
           percentile_cont(0.5) WITHIN GROUP (ORDER BY dias_transito)::text
      FROM staging.pedidos WHERE entregado

    UNION ALL
    SELECT 11, 'días de tránsito: p90',
           percentile_cont(0.9) WITHIN GROUP (ORDER BY dias_transito)::text
      FROM staging.pedidos WHERE entregado

    UNION ALL
    SELECT 12, 'días de tránsito: promedio',
           round(avg(dias_transito), 2)::text
      FROM staging.pedidos WHERE entregado

    UNION ALL
    SELECT 13, 'reseñas después de deduplicar (una por pedido)',
           count(*)::text
      FROM staging.resenas

    UNION ALL
    SELECT 14, 'calificación promedio por pedido (deduplicada)',
           round(avg(calificacion), 4)::text
      FROM staging.resenas

    UNION ALL
    SELECT 15, 'calificación promedio cruda (con repetidas)',
           round(avg(calificacion), 4)::text
      FROM olist.resenas

    UNION ALL
    SELECT 16, 'pedidos con más de una reseña',
           count(*)::text
      FROM (
          SELECT pedido_id
            FROM olist.resenas
           GROUP BY pedido_id
          HAVING count(*) > 1
      ) x

    UNION ALL
    SELECT 17, 'ítems de pedido',
           count(*)::text
      FROM staging.items

    UNION ALL
    SELECT 18, 'ingreso total (precio + flete)',
           sum(ingreso)::text
      FROM staging.items

    UNION ALL
    SELECT 19, 'pedidos con pago / suma de pagos',
           count(*)::text || ' / ' || sum(total_pagado)::text
      FROM staging.pagos

    UNION ALL
    SELECT 20, 'productos sin categoría',
           count(*)::text
      FROM staging.productos WHERE sin_categoria

    UNION ALL
    SELECT 21, 'productos en las 2 categorías sin traducción',
           count(*)::text
      FROM staging.productos
     WHERE categoria_portugues IS NOT NULL
       AND categoria = categoria_portugues

    UNION ALL
    SELECT 22, 'ítems con peso nulo o cero',
           count(*)::text
      FROM staging.items WHERE peso_invalido

    UNION ALL
    SELECT 23, 'pedidos sin ningún ítem',
           count(*)::text
      FROM staging.pedidos p
     WHERE NOT EXISTS (
           SELECT 1 FROM olist.items_pedido i WHERE i.pedido_id = p.pedido_id
     )
) controles
ORDER BY orden;
