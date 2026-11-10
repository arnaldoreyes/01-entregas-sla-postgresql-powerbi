# Guía de la fase 01 — Ingesta (`01_raw`)

**Proyecto 1 · Entregas y SLA (datos de Olist)**

Esta fase es la plomería: dejar los datos crudos dentro de PostgreSQL, sin tocarlos. El
análisis de verdad empieza en `02_staging`. Aquí solo se documenta qué se cargó, qué
trampas trae el dataset y por qué las tablas están armadas así.

---

## 0. Qué se cargó

8 de los 9 CSV de Olist, en 8 tablas del esquema `olist`, **550.759 filas**. El noveno
(geolocalización) se descarta a propósito (§5). Los datos se copian tal como vienen: sin
corregir, sin imputar, sin cambiar fechas. Cada número de este documento sale de la base
ya cargada.

| Tabla | Filas | Qué representa |
|---|---:|---|
| `clientes` | 99.441 | Una cuenta de cliente por fila |
| `pedidos` | 99.441 | Una compra por fila |
| `productos` | 32.951 | Un producto por fila |
| `vendedores` | 3.095 | Un vendedor por fila |
| `categoria_traduccion` | 71 | Portugués → inglés |
| `items_pedido` | 112.650 | Un producto dentro de un pedido |
| `pagos_pedido` | 103.886 | Un pago (un pedido puede tener varios) |
| `resenas` | 99.224 | Una reseña (un pedido puede tener varias) |

---

## 1. Cómo se ejecuta (tres cosas, una sola vez)

**1. Crear la base.** En pgAdmin: clic derecho en **Databases** → **Create** →
**Database…**. Nombre `entregas`, en **Encoding** elige **UTF8**, guardar.

**2. Crear las tablas.** Clic derecho sobre `entregas` → **Query Tool**. Abrir
`01_raw/02_crear_tablas.sql` y pulsar **F5**. Al final lista las 8 tablas (vacías).

**3. Cargar los datos.** Doble clic en **`cargar_datos.bat`** (está en la carpeta del
proyecto). Pide la contraseña de `postgres` y carga todo. Al final muestra la tabla de
conteos.

> El paso 3 no se hace en Query Tool: `\copy` es un comando de psql, no de SQL, y
> pgAdmin responde con un error de sintaxis. El botón `.bat` abre psql por ti.

---

## 2. Qué debe salir

| Tabla | Filas |
|---|---:|
| `clientes` | 99.441 |
| `pedidos` | 99.441 |
| `productos` | 32.951 |
| `vendedores` | 3.095 |
| `categoria_traduccion` | 71 |
| `items_pedido` | 112.650 |
| `pagos_pedido` | 103.886 |
| `resenas` | 99.224 |

| Dinero | Valor |
|---|---:|
| Suma de precios | **13.591.643,70** |
| Suma de fletes | 2.251.909,54 |
| Precio + flete | 15.843.553,24 |

El paso 3 compara estos valores y **se detiene si alguno no coincide**. Es mejor un error
visible que un total equivocado que nadie nota.

---

## 3. Las decisiones que sí afectan el análisis

### 3.1 El grano: pedido, ítem y pago no son lo mismo

Es la decisión más importante de la fase. Un pedido puede tener varios productos y varios
pagos. Por eso una consulta que una las dos tablas multiplica filas y el total sale
inflado. Las llaves lo reflejan:

| Tabla | Llave | Por qué |
|---|---|---|
| `items_pedido` | `(pedido_id, item_id)` | Un pedido tiene N productos |
| `pagos_pedido` | `(pedido_id, pago_secuencial)` | Un pedido puede pagarse en partes |
| `resenas` | `(resena_id, pedido_id)` | Un pedido puede tener 2 o 3 reseñas |

Consecuencia práctica: **para contar pedidos se usa `COUNT(DISTINCT pedido_id)`**, nunca
`COUNT(*)` sobre ítems.

### 3.2 Los vacíos son `NULL`, no cero

`NULL` significa "no hay dato". 2.965 pedidos no tienen fecha de entrega: no tardaron 0
días, no se sabe. Si se rellena con 0, el promedio de días de tránsito se hunde y el
análisis miente. Lo mismo con las 160 fechas de aprobación vacías.

### 3.3 Dinero con `numeric`, no con `float`

`numeric(12,2)` guarda exactamente dos decimales. Con `float`, sumar 112.650 precios
arrastra centavos y el tablero no cuadra con SQL. Para un tablero que se compara contra
una consulta, esa diferencia es inaceptable.

### 3.4 Fechas sin zona horaria

El archivo no dice en qué zona se registraron las fechas. Poner una sería inventar. Se
guardan como `timestamp` tal cual, y en staging se convierten a `date` donde toca.

### 3.5 UTF-8 y BOM

La base se crea en UTF8 para que "São Paulo" no se rompa. El archivo de categorías
empieza con un BOM (una marca invisible) que PostgreSQL no quita solo; se limpia al
cargar. Los comentarios de reseñas traen comas y saltos de línea dentro de comillas: por
eso la carga es CSV, no texto plano.

---

## 4. Las trampas del dataset (números medidos)

| Trampa | Número | Qué implica |
|---|---:|---|
| Reseñas: líneas vs. filas | 104.720 líneas / **99.224 filas** | Contar registros, no líneas |
| Pedidos con 2 o 3 reseñas | 547 | Hay que deduplicar para promediar |
| `review_id` repetido en pedidos distintos | 789 | La llave es la pareja, no el id solo |
| Pedidos sin fecha de entrega | 2.965 | `NULL`, no 0 |
| … de esos, marcados `delivered` | 8 | Se documentan, no se imputan |
| Pedidos sin ítems | 775 | Existen, pero no suman ingreso |
| Fuera del universo (`canceled`+`unavailable`) | 1.234 | Cambian el denominador del OTIF |
| Personas distintas (`cliente_unico_id`) | 96.096 | No confundir con 99.441 cuentas |
| Productos sin categoría | 610 | `NULL`, se muestra "sin categoría" |
| Productos sin peso / con peso 0 | 2 / 4 | Se excluyen del flete por kilo |
| Categorías sin traducción | 2 | `COALESCE` con el nombre en portugués |
| Pedidos con pago | 99.440 | 1 pedido sin fila de pago |

**El caso de las reseñas, en detalle.** El archivo tiene 104.720 líneas físicas y 99.224
registros: los comentarios entre comillas incluyen saltos de línea, así que un registro
ocupa varias líneas. El número 104.719 que circulaba era el conteo de líneas. Además, 547
pedidos tienen 2 o 3 reseñas y 789 `review_id` se repiten en pedidos distintos: promediar
sin deduplicar deja el resultado ponderado por los pedidos con reseña repetida.

**Pagos vs. ítems.** Los pagos suman 16.008.872,12 y los ítems 15.843.553,24. No es un
error: el pago incluye flete y cupones y puede venir en varias filas. Son dos tablas con
granos distintos; **nunca se suman juntas**.

---

## 5. Qué se descartó y por qué

1. **Geolocalización** (1.000.163 filas, 19.015 códigos postales). No cambia el análisis:
   el SLA se mide por estado y el estado ya está en `clientes`. Un millón de filas para
   una precisión que el tablero no usa.
2. **Candado de `productos.categoria` a la traducción.** Fallaría: 73 categorías contra
   71 traducciones. Se resuelve en staging con `COALESCE`.
3. **Cargar todo como texto y convertir después.** Se pierde el aviso temprano de un
   precio mal escrito o una fecha rara.
4. **Tablas temporales para archivos con más columnas que la tabla.** Se midió: ninguno
   de los 9 CSV trae columnas de más. La única temporal es la de categorías, por el BOM.

---

## 6. Cinco preguntas de entrevista (con respuesta)

**1. “El archivo de reseñas tiene 104.719 líneas y 99.224 filas. ¿Por qué?”**
Porque los comentarios vienen entre comillas y algunos incluyen saltos de línea: un
registro ocupa varias líneas físicas. `wc -l` cuenta líneas, no registros. Cargarlo como
texto plano habría partido reseñas.

**2. “¿Por qué `numeric` y no `float` para precios?”**
Porque `float` es binario y no representa exacto valores como 0,10; al sumar 112.650
ítems el total se desvía. `numeric` es decimal exacto y el cuadre con el tablero da al
centavo.

**3. “¿Por qué la llave de ítems es compuesta?”**
Porque el grano es el ítem, no el pedido: un pedido tiene N ítems y `pedido_id` solo se
repetiría. Para contar pedidos se usa `COUNT(DISTINCT pedido_id)`, no `COUNT(*)`.

**4. “¿Por qué la llave de reseñas no es `review_id`?”**
Porque 789 `review_id` aparecen en más de un pedido, y un pedido puede tener hasta 3
reseñas. La única combinación única es `(review_id, pedido_id)`. Para promediar
satisfacción por pedido hay que deduplicar en staging.

**5. “¿Por qué no cargaste la geolocalización?”**
Porque no cambia el análisis: el SLA se mide por estado y el estado ya está en
`clientes`. Son 1.000.163 filas para una precisión que el tablero no usa.

---

## 7. Limitaciones que quedan anotadas

- **No hay transportista.** Olist no publica qué empresa repartió cada pedido. Cualquier
  columna de transportista sería derivada de la región; por eso el SLA se analiza por
  estado.
- **8 pedidos `delivered` sin fecha de entrega.** No se pueden medir en días de tránsito.
- **775 pedidos sin ítems.** Existen como pedido, pero no tienen detalle que sume ingreso.
- **Pagos ≠ ítems.** Miden cosas distintas; no se suman juntas.

---

## 8. Lo que sigue

`02_staging` es la fase donde empieza el trabajo de analista: convertir fechas a día,
deduplicar reseñas, traducir categorías, marcar retrasos y dejar una bitácora con los
conteos antes y después de cada limpieza. Ahí está el peso del proyecto.
