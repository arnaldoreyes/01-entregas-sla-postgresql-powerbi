# Guía de la fase 01 — Ingesta (`01_raw`)

**Proyecto 1 · Entregas y SLA (Olist)**
**Qué queda en esta fase:** los scripts de creación y carga, y este documento. Nada de
limpieza ni de modelo todavía: eso es `02_staging` y `03_modeling`.

---

## 0. Resumen

Se cargan **8 de los 9 CSV** en un esquema `olist` con **8 tablas**: 550.759 filas en
total. El noveno archivo (geolocalización, 1.000.163 filas) se descarta a propósito
(§4). La carga no transforma nada: es una copia fiel del CSV con tipos y restricciones,
para poder auditar cualquier número contra el archivo original.

| Tabla | Filas | Origen |
|---|---:|---|
| `olist.clientes` | 99.441 | `olist_customers_dataset.csv` |
| `olist.pedidos` | 99.441 | `olist_orders_dataset.csv` |
| `olist.productos` | 32.951 | `olist_products_dataset.csv` |
| `olist.vendedores` | 3.095 | `olist_sellers_dataset.csv` |
| `olist.categoria_traduccion` | 71 | `product_category_name_translation.csv` |
| `olist.items_pedido` | 112.650 | `olist_order_items_dataset.csv` |
| `olist.pagos_pedido` | 103.886 | `olist_order_payments_dataset.csv` |
| `olist.resenas` | 99.224 | `olist_order_reviews_dataset.csv` |
| **Total** | **550.759** | |

Los 9 SHA-256 de `01_raw/entrada/` coinciden con `sources.md` (verificado antes de cargar).

---

## 1. Qué se hizo

1. `01_raw/01_crear_base.sql` — borra y crea la base `entregas` (UTF-8), el esquema
   `olist`, las 8 tablas, PK, FK, CHECK e índices.
2. `01_raw/02_cargar.sql` — vacía las tablas y carga los 8 CSV con `\copy`. Al final
   **verifica conteos y la suma de precios**; si algo no cuadra, aborta con excepción.
3. `01_raw/sources.md` — corregido el conteo de reseñas (ver §3.1).
4. `docs/guia-fase-01.md` — este documento.

Los dos scripts se probaron contra una instancia PostgreSQL 18 temporal antes de
entregarlos: corren de punta a punta, y el segundo se puede re-ejecutar sin recrear la
base.

---

## 2. Las decisiones, una por una

### 2.1 Una tabla por archivo, sin transformar

La capa `01_raw` debe parecerse al origen. Si se limpia aquí, se pierde la referencia
contra la que se audita el resto del proyecto. La limpieza (fechas a `date`, deduplicar
reseñas, traducir categorías) va en `02_staging`, donde queda documentada.

### 2.2 Nombres en español, CSV en inglés

Las columnas de la tabla están en español (`pedido_id`, `fecha_compra`) y el CSV en
inglés (`order_id`, `order_purchase_timestamp`). El puente es la **lista de columnas del
`\copy` + `HEADER true`**: PostgreSQL descarta la primera línea y carga por posición. No
se renombra el CSV ni se depende de que los nombres coincidan.

### 2.3 Tipos

| Dato | Tipo | Por qué |
|---|---|---|
| IDs (`order_id`, `product_id`…) | `text` | Son cadenas hex de 32 caracteres sin guiones: no son `uuid` válidos. `text` no impone longitud ni rellena con espacios. |
| CEP / código postal | `text` | Puede tener ceros a la izquierda y aquí no se usa para unir. |
| Fechas | `timestamp` (sin zona) | La fuente no trae offset. Usar `timestamptz` obligaría a inventar una zona; se hará explícito en staging si hace falta. |
| Dinero (`precio`, `flete`, `valor`) | `numeric(12,2)` | Exacto. `real`/`double` redondean y descuadran totales. |
| `item_id`, `pago_secuencial`, `cuotas`, `calificacion` | `smallint` | Rangos medidos: 1–21, 1–29, 0–24, 1–5. |
| `estado` (UF) | `varchar(2)` | `char(2)` rellena con espacios y confunde las comparaciones. |
| Peso y dimensiones | `integer` | Gramos y centímetros; nulos permitidos. |

### 2.4 Claves primarias: las naturales, no inventadas

- `clientes(cliente_id)`, `pedidos(pedido_id)`, `productos(producto_id)`,
  `vendedores(vendedor_id)`, `categoria_traduccion(categoria)`.
- `items_pedido(pedido_id, item_id)`: el grano es el ítem.
- `pagos_pedido(pedido_id, pago_secuencial)`: un pedido puede tener varios pagos.
- `resenas(resena_id, pedido_id)`: **ninguna columna sola es única**. `review_id` se
  repite en pedidos distintos y `pedido_id` se repite cuando hay 2–3 reseñas.

No se agregan claves subrogadas (`id serial`) en raw: no aportan y esconden el problema
de granularidad que hay que entender.

### 2.5 Claves foráneas: sí, y en orden de dependencias

Se cargan primero clientes, productos y vendedores; después pedidos; después ítems,
pagos y reseñas. Las 7 FK se crean en el DDL y se validan al insertar. Si un pedido
tuviera un `customer_id` inexistente, la carga falla: es lo que se quiere.

**Excepción:** `productos.categoria` **no** tiene FK a `categoria_traduccion`. Hay 73
categorías en productos y 71 traducciones: `pc_gamer` y
`portateis_cozinha_e_preparadores_de_alimentos` no están traducidas. Una FK obligaría a
inventar una fila o a borrar productos. Se resuelve en staging con `COALESCE`.

### 2.6 CHECK: que el dato no entre mal

- `estado_pedido` ∈ los 8 estados medidos.
- `calificacion` entre 1 y 5.
- Precio, flete, valor, cuotas, ítem y secuencia de pago ≥ 0 (o ≥ 1 donde corresponde).
- Peso y dimensiones ≥ 0 (el 0 existe y es un dato inválido que se reporta, no se borra).

### 2.7 Nulos: vacío es `NULL`, nunca `0`

En CSV, un campo vacío **sin comillas** entra como `NULL`. Eso es clave en
`fecha_entrega_cliente` (2.965 pedidos): un pedido sin entrega no tardó 0 días, no tiene
días de tránsito. Lo mismo con `fecha_aprobacion` (160) y
`fecha_entrega_transportista` (1.783).

Las columnas que se dejaron `NOT NULL` son las que no tienen un solo vacío en el
archivo (se midió columna por columna). Las que sí tienen van sin `NOT NULL`.

### 2.8 Encoding, BOM y comillas

- **UTF-8**: los 9 archivos son UTF-8 válido (se validó byte a byte). La base se crea en
  UTF-8 con locale `C` para evitar el choque típico de Windows entre `UTF8` y una locale
  de sistema.
- **BOM**: `product_category_name_translation.csv` empieza con `EF BB BF`. PostgreSQL
  **no lo elimina**: medido, el primer campo llega como `U+FEFF` (código 65279). Por eso
  ese archivo se carga sin `HEADER` en una tabla temporal y se limpia con
  `replace(categoria, chr(65279), '')`.
- **Comillas y saltos de línea**: el archivo de reseñas tiene **104.720 líneas físicas
  para 99.224 registros**: 5.495 saltos de línea dentro de comentarios entre comillas.
  Un `COPY` en modo texto rompería; `FORMAT csv` los respeta. Es la razón técnica por la
  que la carga es CSV y no texto plano.

---

## 3. Las trampas, con el número medido

Todos los números de esta tabla salen de la base ya cargada, no de una lectura previa.

### 3.1 Reseñas: 99.224, no 104.719

| Dato | Valor |
|---|---:|
| Registros (filas reales) | **99.224** |
| Líneas físicas del archivo | 104.720 (incluye encabezado) |
| Pedidos con reseña | 98.673 |
| `review_id` distintos | 98.410 |
| Pedidos con 2 o 3 reseñas | 547 |
| `review_id` repetidos en pedidos distintos | 789 |

El número 104.719 que circulaba era el **conteo de líneas** (104.720 − encabezado), no
de filas. La confusión es típica: `wc -l` cuenta líneas, no registros CSV.

### 3.2 Las demás

| Trampa | Medido | Decisión |
|---|---:|---|
| Pedidos sin fecha de entrega | 2.965 | `NULL`, no 0 |
| … de esos, marcados `delivered` | 8 | Se documentan; no se imputan |
| Pedidos con ítems | 98.666 | — |
| Pedidos **sin** ítems | **775** | No se pueden medir en ingreso; se reportan |
| Pedidos fuera del universo (`canceled`+`unavailable`) | 1.234 | Se excluyen del denominador, no de la tabla |
| Clientes únicos (`customer_unique_id`) | 96.096 | No confundir con 99.441 `cliente_id` |
| Productos sin categoría | 610 | `NULL`, se muestra "sin categoría" |
| Productos sin peso / con peso 0 | 2 / 4 | Se excluyen del flete por kg |
| Categorías sin traducción | 2 | `COALESCE` con el nombre en portugués |
| Pedidos con pago | 99.440 | 1 pedido sin fila de pago |
| Suma de pagos | 16.008.872,12 | No coincide con ítems: mide otra cosa |
| Suma de ítems (precio + flete) | 15.843.553,24 | El ingreso del README |

**Sobre pagos vs. ítems:** `pagos_pedido` tiene 103.886 filas para 99.440 pedidos y suma
16.008.872,12; `items_pedido` suma 15.843.553,24. No es un error de carga: el pago
incluye flete y cupones y puede repartirse en varias filas. **Nunca se suman las dos
tablas en la misma consulta**: multiplicaría filas (fan-out).

---

## 4. Qué se descartó y por qué

1. **`olist_geolocation_dataset.csv` (1.000.163 filas, 19.015 CEP).** No entra al
   modelo. La dimensión geográfica se arma con `estado` del cliente, que ya está en
   `clientes`. Cargarla sumaría un millón de filas sin cambiar ninguna conclusión de SLA.
2. **FK de `productos.categoria` a la traducción.** Fallaría con 2 categorías. Se
   resuelve con `COALESCE` en staging.
3. **`timestamptz`.** La fuente no trae zona horaria; asignarla sería inventar.
4. **`uuid` para los IDs.** Los valores no tienen el formato UUID (32 hex sin guiones).
5. **Cargar todo como `text` y castear después.** Se pierde la validación temprana: un
   precio con coma decimal o una fecha rara entrarían sin avisar.
6. **Tablas temporales para “CSV con más columnas que la tabla”.** Se midió: ninguno de
   los 9 archivos trae más columnas que su tabla (5, 8, 7, 5, 7, 9, 4, 2 y 5 campos, y
   todos los registros tienen exactamente esa cantidad). La única temporal que se usa es
   la de categorías, por el BOM y para validar el conteo antes de insertar.
7. **`COPY` en modo texto.** Los saltos de línea dentro de comillas lo romperían.

---

## 5. Números de control

Estos son los valores que debe devolver la base después de correr los dos scripts. El
propio `02_cargar.sql` los verifica y aborta si no coinciden.

```sql
SELECT 'clientes' AS tabla, count(*) FROM olist.clientes
UNION ALL SELECT 'pedidos', count(*) FROM olist.pedidos
UNION ALL SELECT 'productos', count(*) FROM olist.productos
UNION ALL SELECT 'vendedores', count(*) FROM olist.vendedores
UNION ALL SELECT 'categoria_traduccion', count(*) FROM olist.categoria_traduccion
UNION ALL SELECT 'items_pedido', count(*) FROM olist.items_pedido
UNION ALL SELECT 'pagos_pedido', count(*) FROM olist.pagos_pedido
UNION ALL SELECT 'resenas', count(*) FROM olist.resenas
ORDER BY 1;
```

| Control | Esperado |
|---|---:|
| `clientes` | 99.441 |
| `pedidos` | 99.441 |
| `productos` | 32.951 |
| `vendedores` | 3.095 |
| `categoria_traduccion` | 71 |
| `items_pedido` | 112.650 |
| `pagos_pedido` | 103.886 |
| `resenas` | 99.224 |
| `SUM(precio)` | **13.591.643,70** |
| `SUM(flete)` | 2.251.909,54 |
| `SUM(precio + flete)` | 15.843.553,24 |

---

## 6. Cinco preguntas de entrevista (con respuesta)

**1. “El archivo de reseñas tiene 104.719 líneas y 99.224 filas. ¿Por qué?”**
Porque los comentarios vienen entre comillas y algunos incluyen saltos de línea: un
registro ocupa varias líneas físicas. `wc -l` cuenta líneas, no registros. Se carga con
`FORMAT csv` y se cuenta con un parser que respeta comillas; si se hubiera cargado como
texto plano, se habrían partido reseñas.

**2. “¿Por qué `numeric` y no `float` para precios?”**
Porque `float` es binario y no representa exactamente valores como 0,10: al sumar
112.650 ítems el total se desvía. `numeric` es decimal exacto y el cuadre contra el
tablero da al centavo.

**3. “¿Por qué la PK de ítems es compuesta?”**
Porque el grano es el ítem, no el pedido: un pedido tiene N ítems y `pedido_id` solo se
repetiría. La pareja `(pedido_id, item_id)` identifica la fila. Consecuencia práctica:
para contar pedidos se usa `COUNT(DISTINCT pedido_id)`, no `COUNT(*)`.

**4. “¿Por qué la PK de reseñas no es `review_id`?”**
Porque 789 `review_id` aparecen en más de un pedido; la misma reseña se replicó. Y un
pedido puede tener hasta 3 reseñas. La única combinación única es
`(review_id, pedido_id)`. Para promediar satisfacción por pedido hay que deduplicar en
staging, quedándose con la respuesta más reciente.

**5. “¿Por qué no cargaste la geolocalización?”**
Porque no cambia el análisis: el SLA se mide por estado y el estado ya está en
`clientes`. Son 1.000.163 filas y 19.015 CEP para una precisión que el tablero no usa.
Cargarla habría inflado la base y la ingesta sin aportar una sola conclusión.

---

## 7. Limitaciones que quedan anotadas

- **No hay transportista.** Olist no publica qué empresa repartió cada pedido. Cualquier
  columna de transportista sería derivada de la región; por eso el SLA se analiza por
  estado.
- **8 pedidos `delivered` sin fecha de entrega.** No se pueden medir en días de tránsito;
  se excluyen y se reporta el conteo.
- **775 pedidos sin ítems.** Existen como pedido pero no tienen línea de detalle; no
  suman ingreso.
- **Pagos ≠ ítems.** Miden cosas distintas; no se suman juntas.

**Lo que sigue:** `02_staging` (tipado final, deduplicación de reseñas, traducción de
categorías y bitácora de limpieza con estos mismos conteos).
