# Diccionario de datos — Proyecto 1

**Entregas y SLA (Olist)** · PostgreSQL 18

Qué significa cada tabla y cada columna, de dónde sale y qué trampa tiene. Está ordenado
en el mismo orden en que se construye: crudo → staging → modelo.

---

## 1. Tablas crudas — esquema `olist`

Son copia fiel de los CSV. No se transforma nada; las trampas se resuelven después.

### `olist.clientes` — 99.441 filas

| Columna | Tipo | Qué es | Ojo |
|---|---|---|---|
| `cliente_id` | text | Cuenta del cliente | **PK**. No se repite |
| `cliente_unico_id` | text | Persona | 96.096 distintos: una persona puede tener varias cuentas |
| `codigo_postal` | text | CEP | Texto, para no perder ceros |
| `ciudad` | text | Ciudad | — |
| `estado` | varchar(2) | UF (SP, RJ…) | Es la unidad del análisis de SLA |

### `olist.pedidos` — 99.441 filas

| Columna | Tipo | Qué es | Ojo |
|---|---|---|---|
| `pedido_id` | text | Compra | **PK** |
| `cliente_id` | text | Quién compró | **FK** a `clientes` |
| `estado_pedido` | text | 8 estados | `canceled` y `unavailable` quedan fuera del universo |
| `fecha_compra` | timestamp | Cuándo se compró | Not null |
| `fecha_aprobacion` | timestamp | Cuándo se aprobó el pago | 160 nulos |
| `fecha_entrega_transportista` | timestamp | Cuándo salió | 1.783 nulos |
| `fecha_entrega_cliente` | timestamp | Cuándo llegó | 2.965 nulos; **8 son `delivered` sin fecha** |
| `fecha_estimada_entrega` | timestamp | Promesa al cliente | Not null |

### `olist.items_pedido` — 112.650 filas

| Columna | Tipo | Qué es | Ojo |
|---|---|---|---|
| `pedido_id` | text | Pedido | **PK compuesta** con `item_id` |
| `item_id` | smallint | Número de ítem dentro del pedido | 1 a 21 |
| `producto_id` | text | Producto | **FK** a `productos` |
| `vendedor_id` | text | Vendedor | **FK** a `vendedores` |
| `fecha_limite_envio` | timestamp | Fecha límite de despacho | — |
| `precio` | numeric(12,2) | Precio del producto | — |
| `flete` | numeric(12,2) | Costo de envío | El ingreso total es `precio + flete` |

### `olist.pagos_pedido` — 103.886 filas

| Columna | Tipo | Qué es | Ojo |
|---|---|---|---|
| `pedido_id` | text | Pedido | **PK compuesta** |
| `pago_secuencial` | smallint | Número de pago | 1 a 29 |
| `tipo_pago` | text | Tarjeta, boleto, cupón… | — |
| `cuotas` | smallint | Cuotas | 0 a 24 |
| `valor` | numeric(12,2) | Monto | Incluye flete y cupones |

### `olist.resenas` — 99.224 filas

| Columna | Tipo | Qué es | Ojo |
|---|---|---|---|
| `resena_id` | text | Reseña | **PK compuesta** con `pedido_id` |
| `pedido_id` | text | Pedido | **FK**; 547 pedidos tienen 2 o 3 reseñas |
| `calificacion` | smallint | 1 a 5 | — |
| `titulo` | text | Título | 87.656 nulos |
| `comentario` | text | Texto libre | 58.247 nulos; trae comas y saltos de línea |
| `fecha_creacion` | timestamp | Cuándo se escribió | — |
| `fecha_respuesta` | timestamp | Cuándo respondió Olist | Se usa para deduplicar |

### `olist.productos` — 32.951 filas

| Columna | Tipo | Qué es | Ojo |
|---|---|---|---|
| `producto_id` | text | Producto | **PK** |
| `categoria` | text | Categoría en portugués | 610 nulos |
| `largo_nombre` | integer | Largo del nombre | 610 nulos |
| `largo_descripcion` | integer | Largo de la descripción | 610 nulos |
| `fotos` | integer | Número de fotos | 610 nulos |
| `peso_g` | integer | Peso en gramos | 2 nulos y 4 en cero |
| `largo_cm`, `alto_cm`, `ancho_cm` | integer | Medidas | 2 nulos |

### `olist.vendedores` — 3.095 filas

| Columna | Tipo | Qué es |
|---|---|---|
| `vendedor_id` | text | **PK** |
| `codigo_postal` | text | CEP |
| `ciudad` | text | Ciudad |
| `estado` | varchar(2) | UF |

### `olist.categoria_traduccion` — 71 filas

| Columna | Tipo | Qué es |
|---|---|---|
| `categoria` | text | **PK**, nombre en portugués |
| `categoria_en` | text | Nombre en inglés |

Faltan 2 categorías: `pc_gamer` y `portateis_cozinha_e_preparadores_de_alimentos`.

---

## 2. Vistas de limpieza — esquema `staging`

No guardan datos: se calculan. Se pueden auditar contra el crudo.

| Vista | Grano | Filas | Qué agrega |
|---|---|---:|---|
| `staging.clientes` | Cliente | 99.441 | Estado en mayúsculas, ciudad recortada |
| `staging.vendedores` | Vendedor | 3.095 | Igual |
| `staging.productos` | Producto | 32.951 | Categoría traducida y `peso_invalido` |
| `staging.pedidos` | Pedido | 99.441 | Fechas a día, `entregado`, `a_tiempo`, `dias_transito`, `dias_vs_promesa` |
| `staging.resenas` | Pedido | 98.673 | Una reseña por pedido (la más reciente) |
| `staging.pagos` | Pedido | 99.440 | Pagos agrupados (total, cuotas, tipo principal) |
| `staging.items` | Ítem | 112.650 | Ítem + pedido + producto + cliente + vendedor + reseña |
| `staging.pedidos_resumen` | Pedido | 99.441 | Pedido + calificación deduplicada |

Definiciones que aplican a las vistas:

- `en_universo`: estado distinto de `canceled` y `unavailable`.
- `entregado`: `delivered` **y** fecha de entrega conocida.
- `a_tiempo`: fecha de entrega (día) ≤ fecha estimada (día).
- `dias_transito`: entrega − compra, en días calendario.
- `dias_vs_promesa`: entrega − estimada, con signo (positivo = tarde).

---

## 3. Modelo — esquema `modelo`

### `modelo.dim_tiempo` — 791 filas

| Columna | Tipo | Qué es |
|---|---|---|
| `fecha` | date | **PK**, del 2016-09-01 al 2018-10-31 |
| `anio`, `mes`, `trimestre` | smallint | Partes de la fecha |
| `nombre_mes`, `nombre_dia` | text | En español |
| `anio_mes` | text | `2018-05`, para ordenar |
| `dia_semana` | smallint | 1 = lunes … 7 = domingo |
| `es_fin_semana` | boolean | Sábado o domingo |
| `es_feriado` | boolean | Está en `feriados` |
| `es_habil` | boolean | Lunes a viernes y no feriado |

### `modelo.feriados` — 27 filas

| Columna | Tipo | Qué es |
|---|---|---|
| `fecha` | date | **PK** |
| `nombre` | text | Nombre del feriado nacional |

### `modelo.dim_cliente` — 99.441 filas

`cliente_id` (**PK**), `cliente_unico_id`, `ciudad`, `estado`.

### `modelo.dim_producto` — 32.951 filas

`producto_id` (**PK**), `categoria`, `categoria_portugues`, `peso_g`, `peso_invalido`.

### `modelo.dim_estado_entrega` — 5 filas

| ID | Descripción |
|---:|---|
| 1 | a tiempo |
| 2 | tarde |
| 3 | sin entrega |
| 4 | entregado sin fecha |
| 5 | fuera del universo |

### `modelo.hecho_pedidos` — 99.441 filas

| Columna | Tipo | Qué es |
|---|---|---|
| `pedido_id` | text | **PK** |
| `cliente_id` | text | **FK** a `dim_cliente` |
| `fecha_compra` | date | **FK** a `dim_tiempo` |
| `estado_entrega_id` | smallint | **FK** a `dim_estado_entrega` |
| `en_universo`, `entregado`, `a_tiempo` | boolean | Banderas |
| `dias_transito` | integer | Días calendario (NULL si no se entregó) |
| `dias_habiles` | integer | Días hábiles (NULL si no se entregó) |
| `dias_vs_promesa` | integer | Positivo = tarde |
| `calificacion` | smallint | Reseña deduplicada (NULL si no tiene) |
| `ingreso_pedido`, `flete_pedido` | numeric(12,2) | Suma de sus ítems |
| `n_items` | integer | Cantidad de ítems |

### `modelo.hecho_items` — 112.650 filas

| Columna | Tipo | Qué es |
|---|---|---|
| `pedido_id`, `item_id` | text, smallint | **PK compuesta** |
| `producto_id` | text | **FK** a `dim_producto` |
| `cliente_id` | text | **FK** a `dim_cliente` |
| `fecha_compra` | date | **FK** a `dim_tiempo` |
| `estado_entrega_id` | smallint | **FK** a `dim_estado_entrega` |
| `precio`, `flete`, `ingreso` | numeric(12,2) | Dinero |
| `cantidad` | smallint | 1 por fila |

### Vistas

- `modelo.vw_pedidos`: hecho de pedidos con nombres de cliente, tiempo y estado.
- `modelo.vw_items`: hecho de ítems con categoría, cliente, tiempo y estado.

---

## 4. Reglas que no cambian

1. El ingreso se suma en `hecho_items` (`precio + flete`), una sola vez.
2. Los pedidos se cuentan en `hecho_pedidos`, nunca con `COUNT(*)` sobre ítems.
3. `NULL` significa “sin dato”, no cero.
4. Las dos tablas de hechos no se suman en la misma consulta.
