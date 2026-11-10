# Guía de la fase 01 — Ingesta (`01_raw`)

**Proyecto 1 · Entregas y SLA (datos de Olist)**
Esta guía explica qué se hace en esta fase, cómo ejecutarlo en pgAdmin y por qué cada
decisión está tomada así. Está escrita para que la entienda alguien que nunca ha tocado
PostgreSQL, no solo un analista.

---

## 0. La idea en una frase

Los 9 archivos CSV de Olist se meten en una base de datos PostgreSQL llamada `entregas`,
en 8 tablas, sin cambiarles nada: tal como vienen. Son **550.759 filas**. El noveno
archivo (geolocalización) se deja fuera a propósito, y más abajo se explica por qué.

---

## 1. Qué se hace: tres pasos

| Paso | Archivo | ¿En qué base? | ¿Con qué? |
|---|---|---|---|
| 1 | `01_crear_base.sql` | `postgres` (la que viene de fábrica) | pgAdmin → Query Tool |
| 2 | `02_crear_tablas.sql` | `entregas` (la que crea el paso 1) | pgAdmin → Query Tool |
| 3 | `03_cargar.sql` | `entregas` | psql (ver §3) |

Cada paso hace una sola cosa. Si algo falla, se sabe exactamente en cuál fue.

---

## 2. Cómo ejecutar los pasos 1 y 2 en pgAdmin

### Antes de empezar

Los 8 CSV tienen que estar en la carpeta `01_raw/entrada/`. No están en Git porque pesan
120 MB; se descargan de Kaggle (ver `sources.md`). Los hashes ya fueron verificados.

### Paso 1 — crear la base

1. Abre **pgAdmin 4** y conéctate: doble clic en el servidor (aparece como
   `PostgreSQL 18` o el nombre que le hayas puesto). Te pide la contraseña.
2. En el árbol de la izquierda, busca **Databases** (Bases de datos) y haz **clic
   derecho sobre `postgres`** → **Query Tool**.
3. En la ventana que se abre, haz clic en el ícono de **carpeta (Open File)** y elige
   `01_raw/01_crear_base.sql`.
4. Pulsa el botón **▶ (Execute/Refresh)** o la tecla **F5**.
5. Abajo, en **Data Output**, debe aparecer:
   `Listo: la base entregas existe y está vacía. Sigue con el paso 2.`
6. Refresca el árbol: clic derecho sobre **Databases** → **Refresh**. Ahora ves
   `entregas`.

> Si aparece el error `CREATE DATABASE cannot run inside a transaction block`, activa
> el **autocommit** (el ícono de un rayo, junto al botón de ejecutar) y vuelve a correr
> el archivo.

### Paso 2 — crear las tablas

1. Clic derecho sobre la base **`entregas`** → **Query Tool**.
2. Abre `01_raw/02_crear_tablas.sql` con el ícono de carpeta.
3. **F5**.
4. Al final debe aparecer una lista con **8 tablas**: `categoria_traduccion`,
   `clientes`, `items_pedido`, `pagos_pedido`, `pedidos`, `productos`, `resenas`,
   `vendedores`.

Las tablas quedan vacías: los datos entran en el paso 3.

---

## 3. Paso 3 — cargar los datos (la única parte que no es con clics)

**Por qué no se puede en pgAdmin:** cuando escribes algo en Query Tool, pgAdmin se lo
manda al *servidor* de PostgreSQL, y el servidor corre en Windows con otra cuenta
(`NetworkService`) que **no puede leer tu carpeta de Documentos**. El comando que carga
archivos desde tu propio computador se llama `\copy` y lo ejecuta `psql`, una herramienta
de PostgreSQL que corre en tu sesión, con tus permisos.

**Cómo se hace:**

1. Abre **PowerShell** en la carpeta del proyecto. La forma fácil: abre la carpeta
   `01-entregas-sla-postgresql-powerbi` en el Explorador de Windows, haz **clic derecho
   en un espacio vacío** → **Abrir en Terminal** (o "Abrir ventana de PowerShell aquí").
2. Pega esta línea y pulsa Enter:

```powershell
& "C:\Program Files\PostgreSQL\18\bin\psql.exe" -U postgres -d entregas -W -f 01_raw\03_cargar.sql
```

3. Te pide la contraseña de `postgres`. Escríbela (no se ve en pantalla, es normal).
4. Espera: la carga tarda unos segundos. Al final ves una tabla con las 8 tablas y sus
   conteos, y los tres totales de dinero.

**Qué significa cada pedazo del comando** (para que no sea una receta mágica):

| Pedazo | Qué es |
|---|---|
| `&` y las comillas | Ejecutar un programa cuya ruta tiene espacios. |
| `psql.exe` | La herramienta de PostgreSQL que lee archivos y ejecuta SQL. |
| `-U postgres` | El usuario con el que se conecta. |
| `-d entregas` | La base de datos donde carga. |
| `-W` | Pide la contraseña al ejecutar. No se guarda en ningún archivo. |
| `-f 01_raw\03_cargar.sql` | El archivo que va a ejecutar. |

> **Alternativa dentro de pgAdmin:** algunos pgAdmin traen **Tools → PSQL Tool**, una
> consola de psql dentro de la misma ventana. Si la tienes, puedes usarla en lugar de
> PowerShell; hace lo mismo.
>
> **No** intentes correr el paso 3 en Query Tool: `\copy` no es SQL y PostgreSQL
> responderá con un error de sintaxis.

---

## 4. Cómo saber que salió bien

Al final del paso 3, la pantalla muestra esto (los números son la verificación):

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
| **Total** | **550.759** |

| Total de dinero | Valor |
|---|---:|
| Suma de precios | **13.591.643,70** |
| Suma de fletes | 2.251.909,54 |
| Precio + flete | 15.843.553,24 |

El propio archivo compara estos valores y **se detiene con un error si alguno no
coincide**. Es preferible un error visible a un total equivocado que nadie nota.

Para verlo por tu cuenta en pgAdmin, en Query Tool sobre `entregas`:

```sql
SELECT count(*) FROM olist.pedidos;          -- 99.441
SELECT sum(precio) FROM olist.items_pedido;  -- 13.591.643,70
```

---

## 5. Las decisiones, explicadas sin jerga

### 5.1 Una tabla por archivo, sin tocar los datos

La capa `01_raw` es una copia fiel del origen. Si aquí se limpia o se corrige, se pierde
la referencia contra la que se audita todo lo demás. La limpieza va en `02_staging`,
donde queda escrita y justificada.

### 5.2 Los nombres están en español

`pedido_id`, `fecha_compra`, `precio`… Los CSV vienen en inglés (`order_id`,
`order_purchase_timestamp`, `price`). La traducción se hace al cargar, columna por
columna, sin renombrar los archivos originales.

### 5.3 Los tipos de dato

- **IDs como texto**: son cadenas de 32 caracteres sin guiones; no son un `uuid` válido.
- **Dinero como `numeric(12,2)`**: guarda exactamente dos decimales. Con `float` (coma
  flotante) las sumas de 112.650 precios se desvían centavos y el tablero no cuadra.
- **Fechas sin zona horaria**: el archivo no dice en qué zona se registraron. Poner una
  sería inventar; se usa `timestamp` tal cual.
- **Peso y medidas como enteros**: gramos y centímetros, sin decimales.

### 5.4 Las llaves

Una **llave primaria** es la columna que no se repite, como una cédula. Una **llave
foránea** es un candado entre tablas: impide guardar un ítem de un pedido que no existe.

Hay tres tablas donde una sola columna no alcanza:

| Tabla | Llave | Por qué |
|---|---|---|
| `items_pedido` | `(pedido_id, item_id)` | Un pedido tiene varios productos. |
| `pagos_pedido` | `(pedido_id, pago_secuencial)` | Un pedido puede pagarse en varias partes. |
| `resenas` | `(resena_id, pedido_id)` | El mismo `review_id` aparece en pedidos distintos. |

### 5.5 Los vacíos son `NULL`, no cero

`NULL` significa "no hay dato". Si un pedido no tiene fecha de entrega, no tardó 0 días:
no se sabe cuánto tardó. Rellenarlo con 0 hundiría el promedio de días de tránsito.

### 5.6 Las reglas que rechazan datos imposibles

`CHECK` es una regla que PostgreSQL aplica al guardar: una calificación solo puede ir de
1 a 5; un precio no puede ser negativo; un estado de pedido solo puede ser uno de los 8
que existen. Si el archivo trae otra cosa, la carga falla y avisa.

### 5.7 UTF-8, BOM y comillas

- **UTF-8** es el formato que representa bien los acentos del portugués.
- **BOM** es una marca invisible al inicio de un archivo. El de categorías la trae, y
  PostgreSQL no la quita sola: se limpia con `replace(texto, chr(65279), '')`.
- **Comillas**: los comentarios de las reseñas traen comas y saltos de línea dentro de
  comillas. Por eso la carga es `FORMAT csv`: en texto plano, una reseña se partiría en
  varias filas.

---

## 6. Las trampas del dataset (números medidos)

| Trampa | Número | Qué se hizo |
|---|---:|---|
| Reseñas: líneas vs. filas | 104.720 líneas / **99.224 filas** | Se cuentan registros, no líneas |
| Pedidos con 2 o 3 reseñas | 547 | Se deduplicará en staging |
| `review_id` repetido en pedidos distintos | 789 | PK compuesta |
| Pedidos sin fecha de entrega | 2.965 | `NULL`, no 0 |
| … de esos, marcados `delivered` | 8 | Se documentan, no se imputan |
| Pedidos sin ítems | 775 | No suman ingreso; se reportan |
| Fuera del universo (`canceled`+`unavailable`) | 1.234 | Se excluyen del denominador |
| Personas distintas (`cliente_unico_id`) | 96.096 | No confundir con 99.441 cuentas |
| Productos sin categoría | 610 | `NULL`, se muestra "sin categoría" |
| Productos sin peso / con peso 0 | 2 / 4 | Se excluyen del flete por kilo |
| Categorías sin traducción | 2 | `COALESCE` con el nombre en portugués |
| Pedidos con pago | 99.440 | 1 pedido sin fila de pago |
| Suma de pagos | 16.008.872,12 | No coincide con ítems: mide otra cosa |

**Pagos vs. ítems:** no es un error. El pago incluye flete y cupones, y puede venir en
varias filas. Por eso **nunca se suman las dos tablas en la misma consulta**.

---

## 7. Qué se descartó y por qué

1. **Geolocalización** (1.000.163 filas, 19.015 códigos postales). No cambia el análisis:
   el SLA se mide por estado, y el estado ya está en `clientes`. Cargarla sumaría un
   millón de filas sin aportar una sola conclusión.
2. **Candado de `productos.categoria` a la traducción.** Fallaría: hay 73 categorías y
   solo 71 traducciones. Se resuelve en staging con `COALESCE`.
3. **Fechas con zona horaria.** La fuente no la trae; no se inventa.
4. **`uuid` para los IDs.** Los valores no tienen ese formato.
5. **Cargar todo como texto y convertir después.** Se pierde el aviso temprano de un
   precio mal escrito o una fecha rara.
6. **Tablas temporales para “CSV con más columnas que la tabla”.** Se midió: ninguno de
   los 9 archivos trae más columnas que su tabla. La única temporal es la de categorías,
   por el BOM.
7. **`COPY` en modo texto.** Los saltos de línea dentro de comillas romperían la carga.

---

## 8. Cinco preguntas de entrevista (con respuesta)

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

## 9. Limitaciones que quedan anotadas

- **No hay transportista.** Olist no publica qué empresa repartió cada pedido. Cualquier
  columna de transportista sería derivada de la región; por eso el SLA se analiza por
  estado.
- **8 pedidos `delivered` sin fecha de entrega.** No se pueden medir en días de tránsito.
- **775 pedidos sin ítems.** Existen como pedido, pero no tienen detalle que sume ingreso.
- **Pagos ≠ ítems.** Miden cosas distintas; no se suman juntas.

**Lo que sigue:** `02_staging` — convertir fechas a día, deduplicar reseñas, traducir
categorías y dejar una bitácora con estos mismos conteos.
