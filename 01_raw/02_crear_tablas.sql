-- ============================================================
-- PASO 1 de 2 · Crear la base y las tablas
-- Proyecto: Entregas y SLA (datos de Olist)
-- ============================================================
--
-- QUÉ HACE
--   Crea el esquema "olist" y las 8 tablas donde van a vivir los
--   datos de Olist. Todavía no carga ni una fila: solo construye
--   los muebles y las reglas de dónde va cada cosa.
--
-- DÓNDE SE EJECUTA
--   En pgAdmin, en dos momentos:
--
--   a) Primero se crea la base (una sola vez):
--      clic derecho en "Databases" → Create → Database…
--      Nombre: entregas. En "Encoding" elige UTF8. Guardar.
--
--   b) Después, clic derecho sobre "entregas" → Query Tool,
--      abrir este archivo y pulsar F5.
--
-- QUÉ QUEDA DESPUÉS
--   8 tablas vacías. La carga de los datos es el paso 2: se hace
--   con el botón "cargar_datos.bat".
--
-- TRES PALABRAS QUE APARECEN MUCHO
--   Tabla        = una hoja de cálculo con filas y columnas.
--   Llave primaria (PRIMARY KEY) = la columna que no se repite y
--                  que identifica cada fila, como la cédula de una
--                  persona. PostgreSQL no deja repetirla.
--   Llave foránea (FOREIGN KEY) = un candado entre dos tablas:
--                  "este pedido tiene que pertenecer a un cliente
--                  que exista". Si el cliente no existe, no entra.
-- ============================================================

-- Un "esquema" es una carpeta dentro de la base para agrupar las
-- tablas del proyecto y no mezclarlas con las del sistema.
-- Se borra si ya existía para que el paso se pueda repetir.

-- Todo el archivo va dentro de una transacción: o se crean las 8
-- tablas completas, o no se crea ninguna. Si algo falla a mitad de
-- camino, PostgreSQL deshace todo y no queda un esquema a medias.
BEGIN;

-- Si la base se creó sin UTF8, los acentos del portugués se
-- guardarían mal ("São Paulo" quedaría roto). Mejor detenerse aquí
-- con un mensaje claro que descubrirlo tres fases después.
DO $$
BEGIN
    IF current_setting('server_encoding') <> 'UTF8' THEN
        RAISE EXCEPTION 'La base no esta en UTF8 (esta en %). Borrala en pgAdmin y creala otra vez eligiendo Encoding = UTF8.', current_setting('server_encoding');
    END IF;
END
$$;

DROP SCHEMA IF EXISTS olist CASCADE;
CREATE SCHEMA olist;

-- ------------------------------------------------------------
-- Tabla 1: clientes
--   Cada fila es una cuenta de cliente. Son 99.441.
--   Ojo: 99.441 cuentas no son 99.441 personas. La misma persona
--   puede comprar varias veces; para eso está cliente_unico_id
--   (son 96.096 personas distintas).
-- ------------------------------------------------------------
CREATE TABLE olist.clientes (
    cliente_id        text       NOT NULL,
    cliente_unico_id  text       NOT NULL,
    codigo_postal     text       NOT NULL,
    ciudad            text       NOT NULL,
    estado            varchar(2) NOT NULL,
    CONSTRAINT pk_clientes PRIMARY KEY (cliente_id)
);

COMMENT ON TABLE olist.clientes IS
    'Una fila por cuenta de cliente. La persona (cliente_unico_id) puede repetirse.';
COMMENT ON COLUMN olist.clientes.codigo_postal IS
    'Se guarda como texto y no como número porque un código postal puede empezar por cero.';

-- ------------------------------------------------------------
-- Tabla 2: pedidos
--   Cada fila es una compra. Son 99.441.
--   Tres fechas pueden venir vacías: eso se guarda como NULL,
--   que significa "no hay dato". NULL no es cero.
-- ------------------------------------------------------------
CREATE TABLE olist.pedidos (
    pedido_id                    text      NOT NULL,
    cliente_id                   text      NOT NULL,
    estado_pedido                text      NOT NULL,
    fecha_compra                 timestamp NOT NULL,
    fecha_aprobacion             timestamp,
    fecha_entrega_transportista  timestamp,
    fecha_entrega_cliente        timestamp,
    fecha_estimada_entrega       timestamp NOT NULL,
    CONSTRAINT pk_pedidos PRIMARY KEY (pedido_id),
    CONSTRAINT fk_pedidos_cliente FOREIGN KEY (cliente_id)
        REFERENCES olist.clientes (cliente_id),
    CONSTRAINT ck_pedidos_estado CHECK (estado_pedido IN (
        'delivered', 'invoiced', 'shipped', 'processing',
        'unavailable', 'canceled', 'created', 'approved'
    ))
);

COMMENT ON TABLE olist.pedidos IS
    'Una fila por compra. estado_pedido dice en qué punto va; el análisis excluye canceled y unavailable.';
COMMENT ON COLUMN olist.pedidos.fecha_entrega_cliente IS
    'NULL = la entrega no está confirmada (2.965 pedidos). No se rellena con 0: significaría "llegó el mismo día".';
COMMENT ON COLUMN olist.pedidos.fecha_estimada_entrega IS
    'La fecha que se le prometió al cliente al comprar. Contra esta se mide el retraso.';

-- ------------------------------------------------------------
-- Tabla 3: categoria_traduccion
--   Traduce el nombre de la categoría del portugués al inglés.
--   Son 71 filas. Es una tabla de apoyo: no tiene datos de venta.
-- ------------------------------------------------------------
CREATE TABLE olist.categoria_traduccion (
    categoria    text NOT NULL,
    categoria_en text NOT NULL,
    CONSTRAINT pk_categoria_traduccion PRIMARY KEY (categoria)
);

COMMENT ON TABLE olist.categoria_traduccion IS
    'Traducción de 71 categorías. Faltan dos (pc_gamer y portateis_cozinha_e_preparadores_de_alimentos): por eso no hay candado desde productos.';

-- ------------------------------------------------------------
-- Tabla 4: productos
--   Cada fila es un producto. Son 32.951.
--   610 no tienen categoría y 2 no tienen peso: se dejan vacíos,
--   no se inventan.
-- ------------------------------------------------------------
CREATE TABLE olist.productos (
    producto_id        text    NOT NULL,
    categoria          text,
    largo_nombre       integer,
    largo_descripcion  integer,
    fotos              integer,
    peso_g             integer,
    largo_cm           integer,
    alto_cm            integer,
    ancho_cm           integer,
    CONSTRAINT pk_productos PRIMARY KEY (producto_id),
    CONSTRAINT ck_productos_peso  CHECK (peso_g   IS NULL OR peso_g   >= 0),
    CONSTRAINT ck_productos_largo CHECK (largo_cm IS NULL OR largo_cm >= 0),
    CONSTRAINT ck_productos_alto  CHECK (alto_cm  IS NULL OR alto_cm  >= 0),
    CONSTRAINT ck_productos_ancho CHECK (ancho_cm IS NULL OR ancho_cm >= 0)
);

COMMENT ON TABLE olist.productos IS
    'Una fila por producto. 610 sin categoría; 2 sin peso ni medidas. No se imputan.';
COMMENT ON COLUMN olist.productos.peso_g IS
    'Peso en gramos. 4 productos traen 0, que es un dato inválido: se excluyen del cálculo de flete por kilo.';

-- ------------------------------------------------------------
-- Tabla 5: vendedores
--   Cada fila es un vendedor. Son 3.095.
--   No hay columna de transportista: Olist no publica esa
--   información. No se inventa.
-- ------------------------------------------------------------
CREATE TABLE olist.vendedores (
    vendedor_id   text       NOT NULL,
    codigo_postal text       NOT NULL,
    ciudad        text       NOT NULL,
    estado        varchar(2) NOT NULL,
    CONSTRAINT pk_vendedores PRIMARY KEY (vendedor_id)
);

COMMENT ON TABLE olist.vendedores IS
    'Una fila por vendedor. Sin dato de transportista.';

-- ------------------------------------------------------------
-- Tabla 6: items_pedido  (el detalle de cada compra)
--   Cada fila es UN producto dentro de UN pedido. Son 112.650.
--   Por eso un pedido puede ocupar varias filas: si compraste
--   tres cosas, hay tres filas con el mismo pedido_id.
--   La llave es la pareja (pedido + número de ítem).
--
--   Aquí vive el dinero: precio y flete de cada ítem.
--   Para contar pedidos NO se usa COUNT(*), porque contaría
--   renglones; se usa COUNT(DISTINCT pedido_id).
-- ------------------------------------------------------------
CREATE TABLE olist.items_pedido (
    pedido_id          text          NOT NULL,
    item_id            smallint      NOT NULL,
    producto_id        text          NOT NULL,
    vendedor_id        text          NOT NULL,
    fecha_limite_envio timestamp     NOT NULL,
    precio             numeric(12,2) NOT NULL,
    flete              numeric(12,2) NOT NULL,
    CONSTRAINT pk_items_pedido PRIMARY KEY (pedido_id, item_id),
    CONSTRAINT fk_items_pedido FOREIGN KEY (pedido_id)
        REFERENCES olist.pedidos (pedido_id),
    CONSTRAINT fk_items_producto FOREIGN KEY (producto_id)
        REFERENCES olist.productos (producto_id),
    CONSTRAINT fk_items_vendedor FOREIGN KEY (vendedor_id)
        REFERENCES olist.vendedores (vendedor_id),
    CONSTRAINT ck_items_item   CHECK (item_id >= 1),
    CONSTRAINT ck_items_precio CHECK (precio >= 0),
    CONSTRAINT ck_items_flete  CHECK (flete  >= 0)
);

COMMENT ON TABLE olist.items_pedido IS
    'Una fila por producto dentro de un pedido (112.650 para 98.666 pedidos). Aquí se suma el dinero, una sola vez.';
COMMENT ON COLUMN olist.items_pedido.precio IS
    'Precio del producto, sin flete, en reales. Se usa numeric y no float para que la suma dé exacta al centavo.';
COMMENT ON COLUMN olist.items_pedido.flete IS
    'Lo que costó enviar ese ítem, en reales. El ingreso total es precio + flete.';

-- ------------------------------------------------------------
-- Tabla 7: pagos_pedido
--   Cada fila es un pago. Un pedido puede pagarse con tarjeta y
--   cupón, o en varias cuotas: por eso son 103.886 pagos para
--   99.440 pedidos.
--   El total pagado incluye flete y cupones; por eso no coincide
--   con la suma de items_pedido y NO se suman juntas.
-- ------------------------------------------------------------
CREATE TABLE olist.pagos_pedido (
    pedido_id        text          NOT NULL,
    pago_secuencial  smallint      NOT NULL,
    tipo_pago        text          NOT NULL,
    cuotas           smallint      NOT NULL,
    valor            numeric(12,2) NOT NULL,
    CONSTRAINT pk_pagos_pedido PRIMARY KEY (pedido_id, pago_secuencial),
    CONSTRAINT fk_pagos_pedido FOREIGN KEY (pedido_id)
        REFERENCES olist.pedidos (pedido_id),
    CONSTRAINT ck_pagos_secuencial CHECK (pago_secuencial >= 1),
    CONSTRAINT ck_pagos_cuotas     CHECK (cuotas >= 0),
    CONSTRAINT ck_pagos_valor      CHECK (valor  >= 0)
);

COMMENT ON TABLE olist.pagos_pedido IS
    'Una fila por pago. No sumar junto con items_pedido: se multiplicarían las filas y el total saldría inflado.';

-- ------------------------------------------------------------
-- Tabla 8: resenas
--   Cada fila es una reseña. Son 99.224.
--   Ninguna columna sola es única:
--     · un pedido puede tener hasta 3 reseñas (547 casos);
--     · el mismo review_id aparece en pedidos distintos (789).
--   Por eso la llave es la pareja (reseña + pedido).
-- ------------------------------------------------------------
CREATE TABLE olist.resenas (
    resena_id       text      NOT NULL,
    pedido_id       text      NOT NULL,
    calificacion    smallint  NOT NULL,
    titulo          text,
    comentario      text,
    fecha_creacion  timestamp NOT NULL,
    fecha_respuesta timestamp NOT NULL,
    CONSTRAINT pk_resenas PRIMARY KEY (resena_id, pedido_id),
    CONSTRAINT fk_resenas_pedido FOREIGN KEY (pedido_id)
        REFERENCES olist.pedidos (pedido_id),
    CONSTRAINT ck_resenas_calificacion CHECK (calificacion BETWEEN 1 AND 5)
);

COMMENT ON TABLE olist.resenas IS
    '99.224 reseñas para 98.673 pedidos. Para promediar por pedido hay que quedarse con una sola reseña por pedido.';
COMMENT ON COLUMN olist.resenas.comentario IS
    'Texto libre. Algunos comentarios traen comas y saltos de línea dentro de comillas: por eso la carga se hace como CSV.';

-- ------------------------------------------------------------
-- Índices
--   Un índice es como el índice de un libro: no cambia el
--   contenido, pero encontrar algo es mucho más rápido.
--   Se crean solo en las columnas que después se usan para unir
--   o filtrar; llenar todo de índices haría la carga más lenta
--   sin ganar nada.
-- ------------------------------------------------------------
CREATE INDEX idx_pedidos_cliente ON olist.pedidos (cliente_id);
CREATE INDEX idx_clientes_unico  ON olist.clientes (cliente_unico_id);
CREATE INDEX idx_items_producto  ON olist.items_pedido (producto_id);
CREATE INDEX idx_items_vendedor  ON olist.items_pedido (vendedor_id);
CREATE INDEX idx_resenas_pedido  ON olist.resenas (pedido_id);

-- Confirmación para ver en pantalla.
SELECT table_name AS "tabla creada"
  FROM information_schema.tables
 WHERE table_schema = 'olist'
 ORDER BY table_name;

COMMIT;
