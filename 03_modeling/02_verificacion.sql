-- ============================================================
-- PASO 2 de 2 · Verificación del modelo
-- Proyecto: Entregas y SLA (datos de Olist)
-- ============================================================
--
-- QUÉ HACE
--   Comprueba que el modelo estrella tenga las filas que debe,
--   que el dinero cuadre por los dos caminos (pedidos e ítems) y
--   que ningún ítem haya quedado sin producto.
--
-- DÓNDE SE EJECUTA
--   En pgAdmin, con Query Tool sobre "entregas", después de
--   03_modeling/01_estrella.sql.
-- ============================================================

SELECT control, valor
FROM (
    SELECT 1 AS orden, 'días en el calendario' AS control,
           count(*)::text AS valor
      FROM modelo.dim_tiempo

    UNION ALL
    SELECT 2, 'días hábiles en el calendario',
           count(*)::text
      FROM modelo.dim_tiempo WHERE es_habil

    UNION ALL
    SELECT 3, 'feriados cargados',
           count(*)::text
      FROM modelo.feriados

    UNION ALL
    SELECT 4, 'rango del calendario',
           min(fecha)::text || ' a ' || max(fecha)::text
      FROM modelo.dim_tiempo

    UNION ALL
    SELECT 5, 'clientes en la dimensión',
           count(*)::text
      FROM modelo.dim_cliente

    UNION ALL
    SELECT 6, 'productos en la dimensión',
           count(*)::text
      FROM modelo.dim_producto

    UNION ALL
    SELECT 7, 'filas en hecho_pedidos (un pedido por fila)',
           count(*)::text
      FROM modelo.hecho_pedidos

    UNION ALL
    SELECT 8, 'filas en hecho_items (un ítem por fila)',
           count(*)::text
      FROM modelo.hecho_items

    UNION ALL
    SELECT 9, 'ítems sumados desde hecho_pedidos',
           sum(n_items)::text
      FROM modelo.hecho_pedidos

    UNION ALL
    SELECT 10, 'ingreso desde hecho_pedidos',
           sum(ingreso_pedido)::text
      FROM modelo.hecho_pedidos

    UNION ALL
    SELECT 11, 'ingreso desde hecho_items',
           sum(ingreso)::text
      FROM modelo.hecho_items

    UNION ALL
    SELECT 12, 'pedidos con calificación',
           count(calificacion)::text
      FROM modelo.hecho_pedidos

    UNION ALL
    SELECT 13, 'OTIF %',
           round(100.0 * count(*) FILTER (WHERE a_tiempo) / count(*), 2)::text
      FROM modelo.hecho_pedidos WHERE en_universo

    UNION ALL
    SELECT 14, 'pedidos a tiempo',
           count(*)::text
      FROM modelo.hecho_pedidos WHERE estado_entrega_id = 1

    UNION ALL
    SELECT 15, 'pedidos tarde',
           count(*)::text
      FROM modelo.hecho_pedidos WHERE estado_entrega_id = 2

    UNION ALL
    SELECT 16, 'pedidos sin entrega',
           count(*)::text
      FROM modelo.hecho_pedidos WHERE estado_entrega_id = 3

    UNION ALL
    SELECT 17, 'pedidos entregados sin fecha',
           count(*)::text
      FROM modelo.hecho_pedidos WHERE estado_entrega_id = 4

    UNION ALL
    SELECT 18, 'pedidos fuera del universo',
           count(*)::text
      FROM modelo.hecho_pedidos WHERE estado_entrega_id = 5

    UNION ALL
    SELECT 19, 'días de tránsito: mediana (calendario)',
           percentile_cont(0.5) WITHIN GROUP (ORDER BY dias_transito)::text
      FROM modelo.hecho_pedidos WHERE entregado

    UNION ALL
    SELECT 20, 'días de tránsito: mediana (hábiles)',
           percentile_cont(0.5) WITHIN GROUP (ORDER BY dias_habiles)::text
      FROM modelo.hecho_pedidos WHERE entregado

    UNION ALL
    SELECT 21, 'pedidos sin ningún ítem',
           count(*)::text
      FROM modelo.hecho_pedidos WHERE n_items = 0

    UNION ALL
    SELECT 22, 'ítems sin producto en la dimensión (debe ser 0)',
           count(*)::text
      FROM modelo.hecho_items i
     WHERE NOT EXISTS (
           SELECT 1 FROM modelo.dim_producto p WHERE p.producto_id = i.producto_id
     )
) controles
ORDER BY orden;
