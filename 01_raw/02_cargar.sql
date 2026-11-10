-- =====================================================================
-- Proyecto 1 — Entregas y SLA (Olist)
-- Fase 01_raw · Script 02 de 02: carga de los CSV
--
-- Qué hace este script
--   1. Vacía las tablas (permite re-ejecutarlo sin recrear la base).
--   2. Carga los 8 CSV usados con \copy, en orden de dependencias.
--   3. Carga la traducción de categorías con una tabla temporal para
--      limpiar el BOM y validar el conteo antes de insertar.
--   4. Verifica conteos y la suma de precios; si algo no cuadra, aborta.
--
-- Cómo se corre (desde la raíz del repo, que es donde están las rutas):
--   & "C:\Program Files\PostgreSQL\18\bin\psql.exe" -U postgres -d entregas -W -f 01_raw\02_cargar.sql
--
-- Los CSV NO están en Git: viven en 01_raw\entrada\ (ignorada).
-- =====================================================================

\set ON_ERROR_STOP on
SET client_encoding = 'UTF8';

\echo '== 02_cargar | vaciando tablas =='

-- Se listan las 8 tablas en un solo TRUNCATE para que las FK no estorben.
TRUNCATE olist.clientes, olist.pedidos, olist.productos, olist.vendedores,
         olist.categoria_traduccion, olist.items_pedido, olist.pagos_pedido,
         olist.resenas;

-- ---------------------------------------------------------------------
-- Categorías: el archivo empieza con BOM (EF BB BF) y no trae encabezado
-- entre comillas. Se carga primero en una temporal SIN HEADER para que el
-- BOM caiga en un campo de texto y poder limpiarlo con chr(65279), en vez
-- de depender de cómo lo trate la versión de psql.
-- ---------------------------------------------------------------------
\echo '== Cargando categorias (temporal + limpieza de BOM) =='

CREATE TEMP TABLE tmp_categoria_traduccion (
    categoria    text,
    categoria_en text
);

\copy tmp_categoria_traduccion FROM '01_raw/entrada/product_category_name_translation.csv' WITH (FORMAT csv, HEADER false, ENCODING 'UTF8')

INSERT INTO olist.categoria_traduccion (categoria, categoria_en)
SELECT replace(categoria, chr(65279), ''),
       categoria_en
  FROM tmp_categoria_traduccion
 WHERE replace(categoria, chr(65279), '') <> 'product_category_name';

DROP TABLE tmp_categoria_traduccion;

-- ---------------------------------------------------------------------
-- Orden de carga: primero las tablas sin FK, después las que dependen.
-- Cada \copy lleva la lista de columnas en el orden del CSV y HEADER true:
-- PostgreSQL descarta la primera línea, así que los nombres en inglés del
-- CSV no chocan con los nombres en español de la tabla.
-- ---------------------------------------------------------------------
\echo '== Cargando clientes =='
\copy olist.clientes (cliente_id, cliente_unico_id, codigo_postal, ciudad, estado) FROM '01_raw/entrada/olist_customers_dataset.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')

\echo '== Cargando pedidos =='
\copy olist.pedidos (pedido_id, cliente_id, estado_pedido, fecha_compra, fecha_aprobacion, fecha_entrega_transportista, fecha_entrega_cliente, fecha_estimada_entrega) FROM '01_raw/entrada/olist_orders_dataset.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')

\echo '== Cargando productos =='
\copy olist.productos (producto_id, categoria, largo_nombre, largo_descripcion, fotos, peso_g, largo_cm, alto_cm, ancho_cm) FROM '01_raw/entrada/olist_products_dataset.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')

\echo '== Cargando vendedores =='
\copy olist.vendedores (vendedor_id, codigo_postal, ciudad, estado) FROM '01_raw/entrada/olist_sellers_dataset.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')

\echo '== Cargando items de pedido =='
\copy olist.items_pedido (pedido_id, item_id, producto_id, vendedor_id, fecha_limite_envio, precio, flete) FROM '01_raw/entrada/olist_order_items_dataset.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')

\echo '== Cargando pagos =='
\copy olist.pagos_pedido (pedido_id, pago_secuencial, tipo_pago, cuotas, valor) FROM '01_raw/entrada/olist_order_payments_dataset.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')

\echo '== Cargando resenas =='
\copy olist.resenas (resena_id, pedido_id, calificacion, titulo, comentario, fecha_creacion, fecha_respuesta) FROM '01_raw/entrada/olist_order_reviews_dataset.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')

-- ---------------------------------------------------------------------
-- Verificación. Si un conteo o la suma no coinciden, el script falla y
-- no se sigue: es preferible un error ruidoso a un número silencioso.
-- Los valores están medidos sobre los archivos de 01_raw/entrada/
-- (ver docs/guia-fase-01.md).
-- ---------------------------------------------------------------------
\echo '== Verificando conteos y suma de precios =='

DO $$
DECLARE
    n integer;
BEGIN
    SELECT count(*) INTO n FROM olist.clientes;
    IF n <> 99441 THEN RAISE EXCEPTION 'clientes: se esperaban 99441 filas, hay %', n; END IF;

    SELECT count(*) INTO n FROM olist.pedidos;
    IF n <> 99441 THEN RAISE EXCEPTION 'pedidos: se esperaban 99441 filas, hay %', n; END IF;

    SELECT count(*) INTO n FROM olist.productos;
    IF n <> 32951 THEN RAISE EXCEPTION 'productos: se esperaban 32951 filas, hay %', n; END IF;

    SELECT count(*) INTO n FROM olist.vendedores;
    IF n <> 3095 THEN RAISE EXCEPTION 'vendedores: se esperaban 3095 filas, hay %', n; END IF;

    SELECT count(*) INTO n FROM olist.categoria_traduccion;
    IF n <> 71 THEN RAISE EXCEPTION 'categoria_traduccion: se esperaban 71 filas, hay %', n; END IF;

    SELECT count(*) INTO n FROM olist.items_pedido;
    IF n <> 112650 THEN RAISE EXCEPTION 'items_pedido: se esperaban 112650 filas, hay %', n; END IF;

    SELECT count(*) INTO n FROM olist.pagos_pedido;
    IF n <> 103886 THEN RAISE EXCEPTION 'pagos_pedido: se esperaban 103886 filas, hay %', n; END IF;

    SELECT count(*) INTO n FROM olist.resenas;
    IF n <> 99224 THEN RAISE EXCEPTION 'resenas: se esperaban 99224 filas, hay %', n; END IF;

    IF (SELECT sum(precio) FROM olist.items_pedido) <> 13591643.70 THEN
        RAISE EXCEPTION 'items_pedido: la suma de precio no es 13591643.70 (¿filas truncadas?)';
    END IF;
END
$$;

\echo '== Carga terminada: conteos y suma de precios verificados =='

SELECT 'clientes'            AS tabla, count(*) AS filas FROM olist.clientes
UNION ALL SELECT 'pedidos',              count(*) FROM olist.pedidos
UNION ALL SELECT 'productos',            count(*) FROM olist.productos
UNION ALL SELECT 'vendedores',           count(*) FROM olist.vendedores
UNION ALL SELECT 'categoria_traduccion', count(*) FROM olist.categoria_traduccion
UNION ALL SELECT 'items_pedido',         count(*) FROM olist.items_pedido
UNION ALL SELECT 'pagos_pedido',         count(*) FROM olist.pagos_pedido
UNION ALL SELECT 'resenas',              count(*) FROM olist.resenas
ORDER BY 1;

SELECT sum(precio)          AS suma_precio,
       sum(flete)           AS suma_flete,
       sum(precio + flete)  AS suma_precio_mas_flete
  FROM olist.items_pedido;
