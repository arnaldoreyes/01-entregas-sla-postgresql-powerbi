-- =====================================================================
-- Proyecto 1 — Entregas y SLA (Olist)
-- Fase 01_raw · Script 01 de 02: creación de la base y las tablas
--
-- Qué hace este script
--   1. Borra (si existe) y crea la base `entregas` en UTF-8.
--   2. Crea el esquema `olist` y las 8 tablas de la ingesta.
--   3. Define claves primarias, claves foráneas, tipos y restricciones.
--   4. Deja índices en las columnas que después se usan para unir.
--
-- Cómo se corre (desde la raíz del repo):
--   & "C:\Program Files\PostgreSQL\18\bin\psql.exe" -U postgres -d postgres -W -f 01_raw\01_crear_base.sql
--
-- La contraseña NO está escrita aquí: la pide psql con -W. La va a pedir
-- dos veces (una para conectarse a `postgres` y otra al reconectar a
-- `entregas`). Si prefieres que la pida una sola vez, define PGPASSWORD
-- solo en esa terminal (nunca en un archivo del repo).
-- =====================================================================

\set ON_ERROR_STOP on

\echo '== 01_raw | creando la base entregas =='

-- DROP ... WITH (FORCE) cierra las conexiones abiertas (pgAdmin, por
-- ejemplo) antes de borrar. Disponible desde PostgreSQL 13.
DROP DATABASE IF EXISTS entregas WITH (FORCE);

-- template0 + UTF8 + locale C:
--   * template0 permite fijar una codificación distinta a la del clúster.
--   * UTF8 porque los CSV traen acentos portugueses (São Paulo, Roraima).
--   * locale C evita el error típico de Windows "encoding UTF8 does not
--     match locale" y no nos hace falta ordenar texto alfabéticamente:
--     los estados son códigos de 2 letras y el orden lo hará Power BI.
CREATE DATABASE entregas
    WITH TEMPLATE  = template0
         ENCODING  = 'UTF8'
         LOCALE    = 'C';

\connect entregas

SET client_encoding = 'UTF8';

CREATE SCHEMA olist;

-- ---------------------------------------------------------------------
-- 1. Clientes
--    El CSV tiene 99.441 filas, una por `customer_id`. Ojo: hay 96.096
--    `customer_unique_id` distintos; `customer_id` identifica la cuenta
--    en un pedido, no a la persona. La llave de negocio es el único.
-- ---------------------------------------------------------------------
CREATE TABLE olist.clientes (
    cliente_id        text      NOT NULL,
    cliente_unico_id  text      NOT NULL,
    codigo_postal     text      NOT NULL,
    ciudad            text      NOT NULL,
    estado            varchar(2) NOT NULL,
    CONSTRAINT pk_clientes PRIMARY KEY (cliente_id)
);

COMMENT ON TABLE olist.clientes IS
    'Un registro por customer_id del CSV (99.441). No confundir con cliente_unico_id: 96.096 personas distintas.';
COMMENT ON COLUMN olist.clientes.codigo_postal IS
    'Se guarda como texto: el CEP brasileño puede tener ceros a la izquierda y aquí no se usa para unir.';

-- ---------------------------------------------------------------------
-- 2. Pedidos
--    Una fila por pedido (99.441). Las tres fechas que pueden venir
--    vacías se dejan NULL: un pedido sin entrega no es "0 días".
-- ---------------------------------------------------------------------
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
    'Una fila por pedido. order_status trae 8 valores; el análisis excluye canceled y unavailable.';
COMMENT ON COLUMN olist.pedidos.fecha_entrega_cliente IS
    'NULL = sin entrega confirmada (2.965 filas, de las cuales 8 están marcadas delivered). No convertir a 0.';
COMMENT ON COLUMN olist.pedidos.fecha_estimada_entrega IS
    'Promesa de entrega que se le mostró al cliente. Es el denominador del SLA.';

-- ---------------------------------------------------------------------
-- 3. Categorías (traducción)
--    Tabla de apoyo: 71 filas. Hay 73 categorías en productos y 2 sin
--    traducción, por eso NO se pone FK desde productos.categoria.
-- ---------------------------------------------------------------------
CREATE TABLE olist.categoria_traduccion (
    categoria    text NOT NULL,
    categoria_en text NOT NULL,
    CONSTRAINT pk_categoria_traduccion PRIMARY KEY (categoria)
);

COMMENT ON TABLE olist.categoria_traduccion IS
    'Traducción portugués → inglés de 71 categorías. Faltan pc_gamer y portateis_cozinha_e_preparadores_de_alimentos.';

-- ---------------------------------------------------------------------
-- 4. Productos
--    32.951 filas. 610 sin categoría y con los tres campos de texto
--    nulos; 2 sin peso ni dimensiones.
-- ---------------------------------------------------------------------
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
    'Una fila por producto. categoria es NULL en 610 filas: no se imputa, se muestra como "sin categoría".';
COMMENT ON COLUMN olist.productos.peso_g IS
    'Gramos. 2 NULL y 4 con valor 0 (dato inválido): se excluyen del flete por kg y se reporta cuántos.';

-- ---------------------------------------------------------------------
-- 5. Vendedores
-- ---------------------------------------------------------------------
CREATE TABLE olist.vendedores (
    vendedor_id   text       NOT NULL,
    codigo_postal text       NOT NULL,
    ciudad        text       NOT NULL,
    estado        varchar(2) NOT NULL,
    CONSTRAINT pk_vendedores PRIMARY KEY (vendedor_id)
);

COMMENT ON TABLE olist.vendedores IS
    '3.095 vendedores en 23 estados. No hay columna de transportista: Olist no la publica.';

-- ---------------------------------------------------------------------
-- 6. Ítems del pedido (el grano más fino)
--    PK compuesta: un pedido tiene N ítems. Aquí se suma el dinero;
--    para contar pedidos hay que usar COUNT(DISTINCT pedido_id).
-- ---------------------------------------------------------------------
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
    'Grano: un ítem de un pedido (112.650 filas para 98.666 pedidos). El ingreso se suma aquí, una sola vez.';
COMMENT ON COLUMN olist.items_pedido.flete IS
    'Freight value en BRL. El ingreso del README es precio + flete; el "13,59 M" que cita AGENTS es solo precio.';

-- ---------------------------------------------------------------------
-- 7. Pagos
--    Un pedido puede pagar con varias formas/cuotas. El total pagado
--    incluye flete y cupones: no se suma junto con items_pedido.
-- ---------------------------------------------------------------------
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
    'Una fila por pago (103.886 para 99.440 pedidos). Unirla con items multiplica filas: nunca sumar ambas en la misma consulta.';

-- ---------------------------------------------------------------------
-- 8. Reseñas
--    No hay una sola columna que sea llave: review_id se repite en
--    pedidos distintos (789 casos) y un pedido puede tener hasta 3
--    reseñas (547 pedidos). La PK es la pareja.
-- ---------------------------------------------------------------------
CREATE TABLE olist.resenas (
    resena_id      text      NOT NULL,
    pedido_id      text      NOT NULL,
    calificacion   smallint  NOT NULL,
    titulo         text,
    comentario     text,
    fecha_creacion timestamp NOT NULL,
    fecha_respuesta timestamp NOT NULL,
    CONSTRAINT pk_resenas PRIMARY KEY (resena_id, pedido_id),
    CONSTRAINT fk_resenas_pedido FOREIGN KEY (pedido_id)
        REFERENCES olist.pedidos (pedido_id),
    CONSTRAINT ck_resenas_calificacion CHECK (calificacion BETWEEN 1 AND 5)
);

COMMENT ON TABLE olist.resenas IS
    '99.224 reseñas para 98.673 pedidos. Para promediar por pedido hay que deduplicar en staging (la respuesta más reciente).';
COMMENT ON COLUMN olist.resenas.comentario IS
    'Texto libre con saltos de línea y comas dentro de comillas: por eso la carga es CSV, no texto plano.';

-- ---------------------------------------------------------------------
-- Índices para las uniones que vienen en staging y modeling.
-- Las PK ya cubren pedido_id en items/pagos (prefijo de la PK).
-- ---------------------------------------------------------------------
CREATE INDEX idx_pedidos_cliente  ON olist.pedidos (cliente_id);
CREATE INDEX idx_clientes_unico   ON olist.clientes (cliente_unico_id);
CREATE INDEX idx_items_producto   ON olist.items_pedido (producto_id);
CREATE INDEX idx_items_vendedor   ON olist.items_pedido (vendedor_id);
CREATE INDEX idx_resenas_pedido   ON olist.resenas (pedido_id);

\echo '== Tablas creadas en el esquema olist =='

SELECT table_name AS tabla
  FROM information_schema.tables
 WHERE table_schema = 'olist'
 ORDER BY table_name;
