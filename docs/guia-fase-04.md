# Guía de la fase 04 — Tablero en Power BI

**Proyecto 1 · Entregas y SLA (datos de Olist)**

Esta fase la construyes tú en Power BI. Aquí está el plano: qué tablas cargar, cómo
relacionarlas, qué medidas pegar y qué debe mostrar cada página. Al final, la lista de
números para comprobar que el tablero cuadra con SQL.

---

## 1. Qué se construye

Cuatro páginas:

| Página | Responde |
|---|---|
| 1. Resumen | ¿Cómo vamos? OTIF, pedidos, ingreso, ticket |
| 2. Entregas | ¿Cuánto tardamos y dónde se concentra el retraso? |
| 3. Costos | ¿Cuánto pesa el flete y qué lo explica? |
| 4. Satisfacción | ¿Qué pasa con la calificación cuando llega tarde? |

---

## 2. Antes de abrir Power BI

La base tiene que estar completa: `01_raw` cargado, `02_staging` y `03_modeling`
ejecutados. Se cargan **6 tablas** del esquema `modelo`:

- `dim_tiempo`
- `dim_cliente`
- `dim_producto`
- `dim_estado_entrega`
- `hecho_pedidos`
- `hecho_items`

No se cargan `feriados` (ya está resuelto en `dim_tiempo`) ni las vistas `vw_*` (son para
revisar, no para el modelo).

---

## 3. Conectar Power BI con PostgreSQL

1. **Inicio → Obtener datos → Más → Base de datos → PostgreSQL**.
2. Servidor: `localhost`. Base de datos: `entregas`.
3. Modo de conectividad: **Importar** (son 112.650 filas; Importar es más rápido y el
   tablero queda ágil. Se actualiza con “Actualizar” cuando cambien los datos).
4. Credenciales: pestaña **Base de datos**, usuario `postgres` y tu contraseña.
5. En el navegador, abre el esquema **modelo** y marca las 6 tablas.
6. **Transformar datos** y revisa los tipos:
   - `fecha` y `fecha_compra` → **Fecha**.
   - `precio`, `flete`, `ingreso`, `ingreso_pedido`, `flete_pedido` → **Número decimal**.
   - Los `*_id` → **Texto**.
   - `calificacion`, `dias_*`, `n_items` → **Número entero**.
7. **Cerrar y aplicar**.

> **Nombres de tabla:** el conector de PostgreSQL puede importar las tablas con el
> esquema delante (`modelo hecho_pedidos`, con un espacio). Las medidas de esta guía usan
> el nombre limpio (`hecho_pedidos`). Antes de crear medidas, renombra las 6 tablas en el
> panel Datos: clic derecho → **Cambiar nombre**, y quita el prefijo `modelo `. Las
> relaciones se conservan.

> **Si Power BI se queja de Npgsql:** significa que le falta el conector de PostgreSQL.
> Se instala una vez (Npgsql 4.1.9, x64) y se reinicia Power BI. Es un problema del
> conector, no de la base.
>
> **Si da error de SSL:** en Opciones avanzadas de la conexión, agrega
> `SSL Mode=Disable`. La base local no usa SSL.

---

## 4. Relaciones del modelo (paso a paso)

### 4.1 Primero se borran todas

Power BI creó relaciones automáticamente al cargar. Algunas pueden estar mal (por ejemplo,
entre las dos tablas de hechos) o inactivas. Para no adivinar, se borran todas y se crean
las 7 a mano.

1. En la cinta de opciones, pestaña **Inicio** → **Administrar relaciones**.
2. En la ventana aparece la lista de relaciones existentes.
3. Seleccionar una → **Eliminar**. Repetir hasta que la lista quede vacía.
4. **Cerrar**.

### 4.2 Se crean las 7, una por una

En la misma ventana **Administrar relaciones** → **Nueva**:

- Tabla 1: la tabla de hechos, con su columna.
- Tabla 2: la dimensión, con su columna.
- Cardinalidad: **Varios a uno (*:1)**.
- Dirección del filtro cruzado: **Única**.
- **Aceptar**.

| # | Tabla 1 (hecho) | Columna | Tabla 2 (dimensión) | Columna |
|---:|---|---|---|---|
| 1 | `hecho_pedidos` | `cliente_id` | `dim_cliente` | `cliente_id` |
| 2 | `hecho_pedidos` | `fecha_compra` | `dim_tiempo` | `fecha` |
| 3 | `hecho_pedidos` | `estado_entrega_id` | `dim_estado_entrega` | `estado_entrega_id` |
| 4 | `hecho_items` | `producto_id` | `dim_producto` | `producto_id` |
| 5 | `hecho_items` | `cliente_id` | `dim_cliente` | `cliente_id` |
| 6 | `hecho_items` | `fecha_compra` | `dim_tiempo` | `fecha` |
| 7 | `hecho_items` | `estado_entrega_id` | `dim_estado_entrega` | `estado_entrega_id` |

**No se crea ninguna relación entre `hecho_pedidos` y `hecho_items`.** Power BI puede
sugerirla por `pedido_id`; hay que rechazarla.

### 4.3 Cómo debe quedar cada relación

Al hacer doble clic sobre una línea del diagrama se abre **Editar relación**. Debe decir:

| Campo | Valor |
|---|---|
| Cardinalidad | **Varios a uno (*:1)** |
| Dirección del filtro cruzado | **Única** |
| Activa esta relación | **Marcada** |
| Asumir integridad referencial | Desmarcada |

Si una línea se ve **punteada**, está inactiva: se abre, se marca “Activa” y se acepta.
Las 7 tienen que quedar como líneas **sólidas**.

> **Si al marcarla activa Power BI da un error de ambigüedad**, es porque existe otra
> relación que crea un camino alternativo (por ejemplo, una relación entre los dos
> hechos, o una relación de más entre las mismas tablas). Se revisa la lista de
> **Administrar relaciones**, se elimina la que sobra y se reintenta. Con las 7 de la
> tabla no hay ambigüedad posible.

### 4.4 Distribución del diagrama

En la vista **Modelo**, arrastrar las tablas hasta que queden así (las dimensiones
alrededor, los hechos al centro):

```
                    dim_tiempo
                        │
   dim_cliente ── hecho_pedidos ── dim_producto
                        │
                   hecho_items
                        │
                dim_estado_entrega
```

Con esa distribución las 7 líneas se ven sin cruzarse y se detecta de un vistazo si falta
alguna.

### 4.5 Apagar la autodetección

Para que Power BI no vuelva a crear la relación entre los dos hechos al actualizar:

**Archivo → Opciones y configuración → Opciones → Archivo actual → Carga de datos** →
desmarcar **“Detectar nuevas relaciones automáticamente después de cargar los datos”**.

### 4.6 Marcar el calendario como tabla de fechas

Clic derecho sobre `dim_tiempo` → **Marcar como tabla de fechas** → columna `fecha`.
Aparece un ícono de calendario junto al nombre. Sin esto, las funciones de tiempo
(acumulados, año anterior) no funcionan bien.

### 4.7 Verificación

En la vista **Modelo** deben verse **7 líneas sólidas**, cada una con un **1** del lado de
la dimensión y un **\*** del lado del hecho, y la flecha apuntando hacia el hecho. Si hay
8 líneas o alguna punteada, algo quedó mal.

Opcional: ocultar en la vista de informe las columnas de códigos (`*_id`) para que el
panel de campos quede limpio.

---

## 5. Las medidas

Están todas en [`04_presentation/medidas.dax`](../04_presentation/medidas.dax), con
comentario de qué hace cada una. Son **26 medidas**, todas en una tabla aparte llamada
`_Medidas`:

1. **Crear la tabla:** Inicio → **Introducir datos** (en algunas versiones aparece como
   “Escribir datos”) → nombre `_Medidas`, una columna `Lugar` con un guion en la primera
   fila. Crear. Esa tabla no se relaciona con nada: queda fuera del diagrama estrella.
2. **Ocultar la columna** `Lugar`: clic derecho → Ocultar en vista de informe. No
   conviene borrarla: si es la única columna de la tabla, Power BI puede eliminar la
   tabla y con ella las medidas.
3. **Crear cada medida** con clic derecho sobre `_Medidas` → **Nueva medida**.
4. En la barra de fórmula se escribe **la línea completa**, con el nombre y el igual, y
   se pulsa Enter:
   ```
   Pedidos = COUNTROWS ( hecho_pedidos )
   ```
5. El nombre de la medida es lo que va antes del `=`. Si Power BI muestra `Medida =`,
   se reemplaza toda la línea, no solo lo que está después del igual.

Así las medidas no se mezclan con las columnas de los hechos y nombres como `Ingreso` o
`Flete` no chocan con las columnas de `hecho_items`.

Las medidas que sostienen el tablero:

| Medida | Para qué |
|---|---|
| `OTIF %` | El indicador central |
| `Pedidos universo` | El denominador correcto |
| `% tarde` | Retraso entre los entregados |
| `Días tránsito mediana` / `p90` | Cuánto tarda de verdad |
| `Ingreso`, `Ticket promedio`, `Flete sobre ingreso` | Dinero |
| `Calificación a tiempo` / `tarde` / `Brecha` | Satisfacción |
| `Costo por kg` | Flete por peso |

---

## 6. Las páginas, visual por visual

### Página 1 — Resumen

- **6 tarjetas:** `OTIF %` (91,58 %), `Pedidos` (99.441), `Pedidos universo` (98.207),
  `Ingreso` (15.843.553,24), `Ticket promedio` (160,58), `% tarde` (6,77 %).
- **Gráfico de líneas:** eje `dim_tiempo[anio_mes]`, valor `OTIF %`. Muestra la evolución
  mes a mes.
- **Barras horizontales:** eje `dim_cliente[estado]`, valor `OTIF %`; agregar
  `Pedidos universo` como información sobre herramientas. Ordenar de menor a mayor: los
  estados con peor OTIF quedan arriba.
- **Segmentación:** `dim_tiempo[anio]`.
- **Cuadro de texto:** “OTIF = pedidos entregados a tiempo y completos ÷ pedidos del
  universo (sin cancelados ni no disponibles)”.

### Página 2 — Entregas

- **4 tarjetas:** mediana de tránsito (10 días), p90 (23), mediana de días hábiles (7),
  `% tarde` (6,77 %).
- **Barras horizontales:** eje `dim_cliente[estado]`, valor `% tarde`; ordenar de mayor a
  menor y mostrar etiquetas.
- **Histograma de días de tránsito:** seleccionar `hecho_pedidos[dias_transito]` →
  **Nuevo grupo** → intervalos de 5 días. Eje el grupo, valor `Pedidos`.
- **Tabla:** `estado`, `Pedidos`, `% tarde`, `Días tránsito mediana`.

### Página 3 — Costos

- **4 tarjetas:** `Flete` (2.251.909,54), `Flete sobre ingreso` (14,21 %),
  `Flete por pedido` (22,82), `Costo por kg`.
- **Barras:** `dim_producto[categoria]`, valor `Flete sobre ingreso`; top 10.
- **Dispersión:** eje X `Peso promedio por ítem`, eje Y `Flete promedio por ítem`,
  detalle `categoria`, tamaño `Ítems`. Muestra si más peso = más flete.
- **Tabla:** categoría, ítems, peso total, flete, costo por kg.

### Página 4 — Satisfacción

- **4 tarjetas:** `Calificación promedio` (4,12), `Calificación a tiempo` (4,29),
  `Calificación tarde` (2,27), `Brecha calificación` (2,02).
- **Columnas 100 % apiladas:** eje `dim_estado_entrega[descripcion]` (filtrar solo
  “a tiempo” y “tarde”), leyenda `hecho_pedidos[calificacion]`, valor `Pedidos`.
- **Barras:** `dim_cliente[estado]`, valor `Calificación promedio`.
- **Líneas:** `anio_mes`, valor `Calificación promedio`.

---

## 7. La verificación: el tablero debe dar esto

| Visual | Valor esperado |
|---|---:|
| OTIF % | **91,58 %** |
| Pedidos | 99.441 |
| Pedidos universo | 98.207 |
| Pedidos a tiempo | 89.936 |
| Pedidos tarde | 6.534 |
| % tarde | 6,77 % |
| Ingreso | **15.843.553,24** |
| Flete | 2.251.909,54 |
| Flete sobre ingreso | 14,21 % |
| Flete por pedido | 22,82 |
| Ticket promedio | 160,58 |
| Mediana tránsito | 10 |
| P90 tránsito | 23 |
| Mediana días hábiles | 7 |
| Calificación promedio | 4,1162 |
| Calificación a tiempo | 4,2904 |
| Calificación tarde | 2,2705 |
| Brecha | 2,0199 |

Si el tablero no da estos números, no se publica: se revisa la relación o la medida.

---

## 8. Decisiones y descartes

### 8.1 Importar, no DirectQuery

Con 112.650 filas, Importar tarda segundos y el tablero responde al instante. DirectQuery
consultaría la base en cada clic y haría el tablero lento sin ganar nada. **Descartado:**
DirectQuery; sobra para este volumen.

### 8.2 Los hechos no se relacionan entre sí

Se cruzan por las dimensiones compartidas. Si se unen por `pedido_id`, un filtro de
producto se propaga a los pedidos y el OTIF empieza a pesar por ítem. **Descartado:**
relación entre `hecho_items` y `hecho_pedidos`.

### 8.3 El OTIF no se abre por categoría

Un pedido puede tener productos de varias categorías. Si se filtra por categoría, el
OTIF no cambia (y es correcto que no cambie): ese indicador es del pedido, no del
producto. Si alguna vez lo piden, hay que definir un “OTIF por ítem”, que es otra métrica.

### 8.4 Mediana para los días, no promedio

Hay pedidos de hasta 210 días que arrastran el promedio. La mediana (10) describe mejor
la experiencia típica; el p90 (23) muestra la cola. Las dos van en el tablero.

---

## 9. Cinco preguntas de entrevista (con respuesta)

**1. “¿Por qué Importar y no DirectQuery?”**
Porque el volumen es pequeño (112.650 ítems) y el tablero tiene que responder rápido.
DirectQuery consultaría la base en cada interacción sin beneficio. Si los datos cambiaran
cada hora, lo revisaría.

**2. “¿Por qué no relacionaste las dos tablas de hechos?”**
Porque miden granos distintos. Un pedido puede tener cinco ítems; si se unen, un filtro
de producto llegaría al pedido y el OTIF contaría el pedido cinco veces. Se cruzan por
las dimensiones compartidas.

**3. “¿Por qué usas DIVIDE y no una barra?”**
Porque `DIVIDE` devuelve vacío cuando el denominador es cero, en vez de un error. En un
tablero que se filtra por año o por estado, hay combinaciones sin pedidos y la medida no
debe romperse.

**4. “¿Por qué la mediana de tránsito y no el promedio?”**
Porque hay pedidos de 210 días que suben el promedio a 12,5 y hacen ver la operación peor
de lo que es para el cliente típico. La mediana (10) y el p90 (23) describen mejor.

**5. “Si piden ‘solo São Paulo’, ¿qué tocas?”**
Nada del modelo: se filtra `dim_cliente[estado] = "SP"` y todas las medidas se recalculan.
Lo único que no cambiaría es el OTIF si el filtro fuera por categoría, porque ese
indicador es del pedido.

---

## 10. Limitaciones anotadas

- **Sin transportista real**: el análisis es por estado del cliente.
- **OTIF por pedido, no por ítem**: un pedido con varios productos cuenta una vez.
- **1.729 pedidos sin desenlace**: entran al denominador como incumplimiento.
- **Feriados solo nacionales**: los estatales y municipales no se descuentan.
- **Peso inválido en 26 ítems**: se excluyen del costo por kg.

**Lo que sigue:** `05_validation` — cuadre del tablero contra SQL, checklist y capturas.
