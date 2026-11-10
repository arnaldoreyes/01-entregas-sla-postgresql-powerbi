-- ============================================================
-- PASO 1 de 2 · Modelo estrella
-- Proyecto: Entregas y SLA (datos de Olist)
-- ============================================================
--
-- QUÉ HACE
--   Crea el esquema "modelo" con las tablas que va a leer
--   Power BI: un calendario, tres dimensiones y dos tablas de
--   hechos. También deja dos vistas planas para revisar rápido.
--
-- UN ESQUEMA ESTRELLA, EN UNA FRASE
--   Las dimensiones son los "cómo" (quién, qué, cuándo, cómo
--   salió la entrega) y los hechos son los "cuánto" (dinero,
--   días, cantidad). Power BI une unos con otros por las llaves.
--
-- POR QUÉ DOS TABLAS DE HECHOS Y NO UNA
--   El ingreso y la categoría viven en el ítem (un pedido puede
--   tener varios productos). El OTIF, los días de tránsito y la
--   calificación viven en el pedido (son uno solo por compra).
--   Si se meten en la misma tabla, el OTIF se calcula sobre ítems
--   y un pedido con cinco productos pesa cinco veces. Separados,
--   cada indicador se mide en su grano correcto.
--
-- DÓNDE SE EJECUTA
--   En pgAdmin, con Query Tool sobre la base "entregas",
--   después de correr 02_staging/01_vistas.sql.
-- ============================================================

DROP SCHEMA IF EXISTS modelo CASCADE;
CREATE SCHEMA modelo;

BEGIN;

-- ------------------------------------------------------------
-- Calendario
--   Un calendario propio evita depender del reloj del sistema y
--   permite marcar fines de semana y feriados. Arranca el
--   2016-09-01 (el mes de la primera compra) y termina el
--   2018-10-31 (el mes de la última), para no mostrar meses
--   vacíos en el tablero.
-- ------------------------------------------------------------
CREATE TABLE modelo.dim_tiempo (
    fecha          date     PRIMARY KEY,
    anio           smallint NOT NULL,
    mes            smallint NOT NULL,
    nombre_mes     text     NOT NULL,
    trimestre      smallint NOT NULL,
    anio_mes       text     NOT NULL,
    dia_semana     smallint NOT NULL,
    nombre_dia     text     NOT NULL,
    es_fin_semana  boolean  NOT NULL,
    es_feriado     boolean  NOT NULL,
    es_habil       boolean  NOT NULL
);

COMMENT ON TABLE modelo.dim_tiempo IS
    'Un día por fila, del 2016-09-01 al 2018-10-31. es_habil = lunes a viernes que no sea feriado nacional.';

-- Feriados nacionales de Brasil en el periodo. No se incluyen
-- carnaval ni corpus christi porque son puntos facultativos y
-- discutibles; se documenta como decisión.
CREATE TABLE modelo.feriados (
    fecha  date PRIMARY KEY,
    nombre text NOT NULL
);

INSERT INTO modelo.feriados (fecha, nombre) VALUES
    -- 2016
    ('2016-01-01', 'Confraternização Universal'),
    ('2016-03-25', 'Sexta-feira Santa'),
    ('2016-04-21', 'Tiradentes'),
    ('2016-05-01', 'Dia do Trabalho'),
    ('2016-09-07', 'Independência do Brasil'),
    ('2016-10-12', 'Nossa Senhora Aparecida'),
    ('2016-11-02', 'Finados'),
    ('2016-11-15', 'Proclamação da República'),
    ('2016-12-25', 'Natal'),
    -- 2017
    ('2017-01-01', 'Confraternização Universal'),
    ('2017-04-14', 'Sexta-feira Santa'),
    ('2017-04-21', 'Tiradentes'),
    ('2017-05-01', 'Dia do Trabalho'),
    ('2017-09-07', 'Independência do Brasil'),
    ('2017-10-12', 'Nossa Senhora Aparecida'),
    ('2017-11-02', 'Finados'),
    ('2017-11-15', 'Proclamação da República'),
    ('2017-12-25', 'Natal'),
    -- 2018
    ('2018-01-01', 'Confraternização Universal'),
    ('2018-03-30', 'Sexta-feira Santa'),
    ('2018-04-21', 'Tiradentes'),
    ('2018-05-01', 'Dia do Trabalho'),
    ('2018-09-07', 'Independência do Brasil'),
    ('2018-10-12', 'Nossa Senhora Aparecida'),
    ('2018-11-02', 'Finados'),
    ('2018-11-15', 'Proclamação da República'),
    ('2018-12-25', 'Natal');

INSERT INTO modelo.dim_tiempo
SELECT
    d::date AS fecha,
    extract(year  FROM d)::smallint AS anio,
    extract(month FROM d)::smallint AS mes,
    CASE extract(month FROM d)
        WHEN 1 THEN 'enero'   WHEN 2 THEN 'febrero' WHEN 3 THEN 'marzo'
        WHEN 4 THEN 'abril'   WHEN 5 THEN 'mayo'    WHEN 6 THEN 'junio'
        WHEN 7 THEN 'julio'   WHEN 8 THEN 'agosto'  WHEN 9 THEN 'septiembre'
        WHEN 10 THEN 'octubre' WHEN 11 THEN 'noviembre' WHEN 12 THEN 'diciembre'
    END AS nombre_mes,
    extract(quarter FROM d)::smallint AS trimestre,
    to_char(d, 'YYYY-MM') AS anio_mes,
    extract(isodow FROM d)::smallint AS dia_semana,
    CASE extract(isodow FROM d)
        WHEN 1 THEN 'lunes'    WHEN 2 THEN 'martes'  WHEN 3 THEN 'miércoles'
        WHEN 4 THEN 'jueves'   WHEN 5 THEN 'viernes' WHEN 6 THEN 'sábado'
        WHEN 7 THEN 'domingo'
    END AS nombre_dia,
    (extract(isodow FROM d) >= 6) AS es_fin_semana,
    EXISTS (SELECT 1 FROM modelo.feriados f WHERE f.fecha = d) AS es_feriado,
    (extract(isodow FROM d) <= 5
     AND NOT EXISTS (SELECT 1 FROM modelo.feriados f WHERE f.fecha = d)) AS es_habil
FROM generate_series('2016-09-01'::date, '2018-10-31'::date, '1 day') AS d;

-- ------------------------------------------------------------
-- Dimensión cliente
--   Un cliente por fila. Se guarda el estado porque el análisis
--   de SLA se hace por región (no hay transportista real).
-- ------------------------------------------------------------
CREATE TABLE modelo.dim_cliente AS
SELECT cliente_id, cliente_unico_id, ciudad, estado
FROM staging.clientes;

ALTER TABLE modelo.dim_cliente ADD PRIMARY KEY (cliente_id);

-- ------------------------------------------------------------
-- Dimensión producto
--   Un producto por fila, con la categoría ya traducida.
-- ------------------------------------------------------------
CREATE TABLE modelo.dim_producto AS
SELECT producto_id, categoria, categoria_portugues, peso_g, peso_invalido
FROM staging.productos;

ALTER TABLE modelo.dim_producto ADD PRIMARY KEY (producto_id);

-- ------------------------------------------------------------
-- Dimensión estado de entrega
--   Cinco estados posibles. Es la dimensión que hace que el OTIF
--   se pueda filtrar sin escribir la regla en cada consulta.
-- ------------------------------------------------------------
CREATE TABLE modelo.dim_estado_entrega (
    estado_entrega_id smallint PRIMARY KEY,
    descripcion       text NOT NULL
);

INSERT INTO modelo.dim_estado_entrega (estado_entrega_id, descripcion) VALUES
    (1, 'a tiempo'),
    (2, 'tarde'),
    (3, 'sin entrega'),
    (4, 'entregado sin fecha'),
    (5, 'fuera del universo');

-- ------------------------------------------------------------
-- Hecho de pedidos (un pedido por fila, 99.441)
--   Aquí viven el OTIF, los días de tránsito (calendario y
--   hábiles), la calificación y el ingreso total del pedido.
-- ------------------------------------------------------------
CREATE TABLE modelo.hecho_pedidos AS
SELECT
    p.pedido_id,
    p.cliente_id,
    p.fecha_compra,
    CASE
        WHEN NOT p.en_universo            THEN 5
        WHEN p.entregado_sin_fecha        THEN 4
        WHEN p.entregado AND p.a_tiempo   THEN 1
        WHEN p.entregado AND NOT p.a_tiempo THEN 2
        ELSE 3
    END::smallint AS estado_entrega_id,
    p.en_universo,
    p.entregado,
    p.a_tiempo,
    p.dias_transito,
    CASE WHEN p.entregado THEN (
        SELECT count(*)
          FROM modelo.dim_tiempo t
         WHERE t.fecha >  p.fecha_compra
           AND t.fecha <= p.fecha_entrega_cliente
           AND t.es_habil
    ) END AS dias_habiles,
    p.dias_vs_promesa,
    r.calificacion,
    COALESCE(i.ingreso_pedido, 0) AS ingreso_pedido,
    COALESCE(i.flete_pedido, 0)   AS flete_pedido,
    COALESCE(i.n_items, 0)        AS n_items
FROM staging.pedidos p
LEFT JOIN staging.resenas r ON r.pedido_id = p.pedido_id
LEFT JOIN (
    SELECT pedido_id,
           sum(ingreso) AS ingreso_pedido,
           sum(flete)   AS flete_pedido,
           count(*)     AS n_items
      FROM staging.items
     GROUP BY pedido_id
) i ON i.pedido_id = p.pedido_id;

ALTER TABLE modelo.hecho_pedidos ADD PRIMARY KEY (pedido_id);
ALTER TABLE modelo.hecho_pedidos
    ADD CONSTRAINT fk_hecho_pedidos_cliente FOREIGN KEY (cliente_id)
        REFERENCES modelo.dim_cliente (cliente_id),
    ADD CONSTRAINT fk_hecho_pedidos_tiempo FOREIGN KEY (fecha_compra)
        REFERENCES modelo.dim_tiempo (fecha),
    ADD CONSTRAINT fk_hecho_pedidos_estado FOREIGN KEY (estado_entrega_id)
        REFERENCES modelo.dim_estado_entrega (estado_entrega_id);

-- ------------------------------------------------------------
-- Hecho de ítems (un ítem por fila, 112.650)
--   Aquí viven el ingreso, el flete y la cantidad. Es el grano
--   correcto para sumar dinero sin repetir pedidos.
-- ------------------------------------------------------------
CREATE TABLE modelo.hecho_items AS
SELECT
    i.pedido_id,
    i.item_id,
    i.producto_id,
    h.cliente_id,
    h.fecha_compra,
    h.estado_entrega_id,
    i.precio,
    i.flete,
    i.ingreso,
    1::smallint AS cantidad
FROM staging.items i
JOIN modelo.hecho_pedidos h ON h.pedido_id = i.pedido_id;

ALTER TABLE modelo.hecho_items ADD PRIMARY KEY (pedido_id, item_id);
ALTER TABLE modelo.hecho_items
    ADD CONSTRAINT fk_hecho_items_pedido FOREIGN KEY (pedido_id)
        REFERENCES modelo.hecho_pedidos (pedido_id),
    ADD CONSTRAINT fk_hecho_items_producto FOREIGN KEY (producto_id)
        REFERENCES modelo.dim_producto (producto_id),
    ADD CONSTRAINT fk_hecho_items_cliente FOREIGN KEY (cliente_id)
        REFERENCES modelo.dim_cliente (cliente_id),
    ADD CONSTRAINT fk_hecho_items_tiempo FOREIGN KEY (fecha_compra)
        REFERENCES modelo.dim_tiempo (fecha),
    ADD CONSTRAINT fk_hecho_items_estado FOREIGN KEY (estado_entrega_id)
        REFERENCES modelo.dim_estado_entrega (estado_entrega_id);

-- Índices para las uniones que hace Power BI.
CREATE INDEX idx_hecho_pedidos_cliente ON modelo.hecho_pedidos (cliente_id);
CREATE INDEX idx_hecho_pedidos_tiempo  ON modelo.hecho_pedidos (fecha_compra);
CREATE INDEX idx_hecho_items_producto  ON modelo.hecho_items (producto_id);
CREATE INDEX idx_hecho_items_cliente   ON modelo.hecho_items (cliente_id);
CREATE INDEX idx_hecho_items_tiempo    ON modelo.hecho_items (fecha_compra);

-- ------------------------------------------------------------
-- Vistas planas (para revisar y, si se quiere, conectar directo)
--   Son los hechos con los nombres de las dimensiones pegados.
--   Power BI puede usar el estrella o estas vistas; el estrella
--   es más eficiente, las vistas son más fáciles de leer.
-- ------------------------------------------------------------
CREATE VIEW modelo.vw_pedidos AS
SELECT
    h.pedido_id, h.fecha_compra, h.estado_entrega_id,
    e.descripcion AS estado_entrega,
    h.en_universo, h.entregado, h.a_tiempo,
    h.dias_transito, h.dias_habiles, h.dias_vs_promesa,
    h.calificacion, h.ingreso_pedido, h.flete_pedido, h.n_items,
    c.cliente_id, c.estado AS estado_cliente, c.ciudad AS ciudad_cliente,
    t.anio, t.mes, t.nombre_mes, t.anio_mes, t.trimestre,
    t.dia_semana, t.nombre_dia, t.es_habil
FROM modelo.hecho_pedidos h
JOIN modelo.dim_cliente  c ON c.cliente_id = h.cliente_id
JOIN modelo.dim_tiempo   t ON t.fecha = h.fecha_compra
JOIN modelo.dim_estado_entrega e ON e.estado_entrega_id = h.estado_entrega_id;

CREATE VIEW modelo.vw_items AS
SELECT
    i.pedido_id, i.item_id, i.producto_id, i.fecha_compra,
    e.descripcion AS estado_entrega,
    i.precio, i.flete, i.ingreso, i.cantidad,
    p.categoria, p.peso_g, p.peso_invalido,
    c.estado AS estado_cliente,
    t.anio, t.mes, t.anio_mes, t.trimestre
FROM modelo.hecho_items i
JOIN modelo.dim_producto p ON p.producto_id = i.producto_id
JOIN modelo.dim_cliente  c ON c.cliente_id = i.cliente_id
JOIN modelo.dim_tiempo   t ON t.fecha = i.fecha_compra
JOIN modelo.dim_estado_entrega e ON e.estado_entrega_id = i.estado_entrega_id;

COMMIT;

SELECT table_name AS "tabla creada"
  FROM information_schema.tables
 WHERE table_schema = 'modelo'
 ORDER BY table_name;
