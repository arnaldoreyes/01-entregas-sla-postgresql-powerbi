-- ============================================================
-- PASO 2 de 2 · Cargar los datos de los CSV
-- Proyecto: Entregas y SLA (datos de Olist)
-- ============================================================
--
-- QUÉ HACE
--   Toma los 8 archivos CSV de la carpeta "entrada" y los mete,
--   fila por fila, en las tablas creadas en el paso 2. Al final
--   cuenta las filas y suma los precios: si algo no cuadra, se
--   detiene y avisa.
--
-- DÓNDE SE EJECUTA
--   Con doble clic en "cargar_datos.bat". Ese botón abre psql,
--   la herramienta que sí puede leer los archivos de tu
--   computador. pgAdmin no puede: le ordena al servidor, y el
--   servidor corre con otra cuenta de Windows que no tiene acceso
--   a tu carpeta de Documentos.
--
--   Importante: NO ejecutar este archivo en Query Tool. Query
--   Tool no entiende los comandos que empiezan con "\" y devuelve
--   un error de sintaxis.
--
-- QUÉ QUEDA DESPUÉS
--   550.759 filas repartidas en las 8 tablas, con los conteos
--   verificados.
--
-- NOTA: las rutas de los archivos son relativas a la carpeta del
-- proyecto (la que contiene 01_raw). No son rutas absolutas.
-- ============================================================

\set ON_ERROR_STOP on
SET client_encoding = 'UTF8';

-- Toda la carga va en una sola transacción: si un archivo falla a
-- mitad de camino, se deshace todo y la base queda como estaba.
-- Así no quedan 5 tablas cargadas y 3 vacías sin que nadie lo note.
BEGIN;

-- ------------------------------------------------------------
-- Vaciar las tablas antes de cargar.
-- Sirve para poder repetir este paso sin duplicar filas: si ya
-- había datos, se borran y se vuelven a cargar desde cero.
-- ------------------------------------------------------------
TRUNCATE olist.clientes, olist.pedidos, olist.productos, olist.vendedores,
         olist.categoria_traduccion, olist.items_pedido, olist.pagos_pedido,
         olist.resenas;

-- ------------------------------------------------------------
-- Categorías: el archivo empieza con una marca invisible llamada
-- BOM. Esa marca se pega al primer nombre y lo vuelve distinto
-- ("categoria" no es lo mismo que "BOM+categoria").
-- Para poder limpiarla, primero se carga todo en una tabla
-- temporal (un borrador que se borra al terminar), se quita la
-- marca y recién ahí se guarda en la tabla buena.
-- ------------------------------------------------------------
CREATE TEMP TABLE tmp_categoria_traduccion (
    categoria    text,
    categoria_en text
);

\copy tmp_categoria_traduccion FROM '01_raw/entrada/product_category_name_translation.csv' WITH (FORMAT csv, HEADER false, ENCODING 'UTF8')

-- Se descarta la primera fila (es el título de las columnas) y se
-- limpia la marca invisible antes de insertar.
INSERT INTO olist.categoria_traduccion (categoria, categoria_en)
SELECT replace(categoria, chr(65279), ''),
       categoria_en
  FROM tmp_categoria_traduccion
 WHERE replace(categoria, chr(65279), '') <> 'product_category_name';

DROP TABLE tmp_categoria_traduccion;

-- ------------------------------------------------------------
-- Carga de las 7 tablas restantes.
--
-- El orden importa: primero los clientes, productos y vendedores;
-- después los pedidos; al final ítems, pagos y reseñas. Es como
-- armar un mueble: no se pueden atornillar las patas antes de
-- tener la tabla.
--
-- Cada línea dice de qué archivo toma los datos, en qué tabla los
-- guarda y en qué orden van las columnas. "HEADER true" significa
-- "la primera línea del archivo son los títulos, sáltala".
-- ------------------------------------------------------------
\copy olist.clientes (cliente_id, cliente_unico_id, codigo_postal, ciudad, estado) FROM '01_raw/entrada/olist_customers_dataset.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')

\copy olist.pedidos (pedido_id, cliente_id, estado_pedido, fecha_compra, fecha_aprobacion, fecha_entrega_transportista, fecha_entrega_cliente, fecha_estimada_entrega) FROM '01_raw/entrada/olist_orders_dataset.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')

\copy olist.productos (producto_id, categoria, largo_nombre, largo_descripcion, fotos, peso_g, largo_cm, alto_cm, ancho_cm) FROM '01_raw/entrada/olist_products_dataset.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')

\copy olist.vendedores (vendedor_id, codigo_postal, ciudad, estado) FROM '01_raw/entrada/olist_sellers_dataset.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')

\copy olist.items_pedido (pedido_id, item_id, producto_id, vendedor_id, fecha_limite_envio, precio, flete) FROM '01_raw/entrada/olist_order_items_dataset.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')

\copy olist.pagos_pedido (pedido_id, pago_secuencial, tipo_pago, cuotas, valor) FROM '01_raw/entrada/olist_order_payments_dataset.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')

\copy olist.resenas (resena_id, pedido_id, calificacion, titulo, comentario, fecha_creacion, fecha_respuesta) FROM '01_raw/entrada/olist_order_reviews_dataset.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')

-- ------------------------------------------------------------
-- Revisión final.
-- Compara lo que llegó con lo que se midió en los archivos.
-- Si un número no coincide, se detiene con un mensaje en rojo:
-- es mejor un error visible que un total equivocado sin avisar.
-- ------------------------------------------------------------
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
        RAISE EXCEPTION 'items_pedido: la suma de precio no es 13591643.70 (¿se cortó alguna fila?)';
    END IF;
END
$$;

-- Tabla resumen: una fila por tabla con su cantidad de registros.
SELECT 'clientes'            AS tabla, count(*) AS filas FROM olist.clientes
UNION ALL SELECT 'pedidos',              count(*) FROM olist.pedidos
UNION ALL SELECT 'productos',            count(*) FROM olist.productos
UNION ALL SELECT 'vendedores',           count(*) FROM olist.vendedores
UNION ALL SELECT 'categoria_traduccion', count(*) FROM olist.categoria_traduccion
UNION ALL SELECT 'items_pedido',         count(*) FROM olist.items_pedido
UNION ALL SELECT 'pagos_pedido',         count(*) FROM olist.pagos_pedido
UNION ALL SELECT 'resenas',              count(*) FROM olist.resenas
ORDER BY 1;

-- Los tres totales de dinero que después se usan en el tablero.
SELECT sum(precio)         AS suma_precio,
       sum(flete)          AS suma_flete,
       sum(precio + flete) AS suma_precio_mas_flete
  FROM olist.items_pedido;

COMMIT;
