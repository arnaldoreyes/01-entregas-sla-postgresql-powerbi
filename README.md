# Entregas y SLA — análisis de operaciones logísticas

Análisis de **99.441 pedidos** de un marketplace brasileño real (2016–2018) para medir
el desempeño de las entregas: cuánto tardan, cuántas llegan fuera de plazo, cuánto cuesta
el flete y qué relación tiene el retraso con la satisfacción del cliente.

**Stack:** PostgreSQL 18 · Power BI Desktop
**Perfil:** Analista BI / Analista de Datos de Operaciones

> **Estado:** en construcción. Las preguntas de negocio están definidas; los hallazgos se
> agregan a medida que cada fase se valida. Ningún número de este README se publica sin
> haber sido contrastado contra la fuente en `05_validation/`.

---

## El problema de negocio

Un marketplace cobra por conectar vendedores con compradores, pero la experiencia que el
cliente recuerda no es la compra: es la entrega. Una entrega tarde no se recupera con un
correo de disculpa; se recupera con una reseña de una estrella.

La operación necesita responder tres cosas:

1. **¿Estamos cumpliendo la promesa?** La fecha estimada que se muestra al comprar es un
   compromiso. Cumplirlo (o no) es el indicador central de la operación logística.
2. **¿El retraso es parejo o está concentrado?** Si el problema está en dos estados y no
   en veintisiete, la acción es distinta a "mejorar la logística".
3. **¿Cuánto cuesta?** El flete es un costo variable que come margen; hay que saber
   cuánto pesa y si el cliente lo está pagando.

## Preguntas de negocio

| # | Pregunta | Indicador | Estado |
|---|---|---|---|
| 01 | ¿Cuál es el desempeño de entrega (OTIF) y cómo evoluciona mes a mes? | % pedidos a tiempo y completos | Pendiente |
| 02 | ¿Cuántos días tarda realmente una entrega, medido en días hábiles? | Días de tránsito (mediana y p90) | Pendiente |
| 03 | ¿Qué regiones concentran los retrasos y cuánto pesan en el total? | % retraso por estado · volumen | Pendiente |
| 04 | ¿Cuánto cuesta el flete y qué proporción del ingreso representa? | Flete / ingreso · flete por pedido | Pendiente |
| 05 | ¿Qué pasa con la calificación del cliente cuando el pedido llega tarde? | Reseña promedio a tiempo vs. tarde | Pendiente |
| 06 | ¿El peso y el tamaño del paquete explican el costo del flete? | Flete vs. peso · costo por kg | Pendiente |

**Pregunta de cierre (la que va al CV):** ¿qué acción concreta tomaría la operación con
estos datos, y cuánto mejoraría el indicador?

---

## Modelo de datos

Esquema estrella sobre PostgreSQL: **dos tablas de hechos** que comparten las dimensiones
de cliente, producto, tiempo y estado de entrega.

- `modelo.hecho_pedidos` (99.441): un pedido por fila — OTIF, días de tránsito y
  calificación.
- `modelo.hecho_items` (112.650): un ítem por fila — precio, flete, ingreso y categoría.

```
dim_cliente ─┬─ hecho_pedidos ─┬─ dim_tiempo
             │                 └─ dim_estado_entrega
             └─ hecho_items ───┴─ dim_producto
```

Son dos hechos porque el ingreso vive en el ítem (un pedido puede tener varios productos)
y el OTIF en el pedido (es uno por compra). Separados, cada indicador se mide en su grano
correcto.

El detalle de cada tabla, su clave y las trampas de cada campo está en
[`docs/diccionario-datos.md`](docs/diccionario-datos.md).

## Pipeline

```
01_raw/          DDL de las tablas + carga con \copy desde los CSV de Olist
02_staging/      Vistas stg_*: tipado, nulos, normalización y bitácora de limpieza
03_modeling/     Esquema estrella, tabla calendario y vistas vw_* que lee Power BI
04_presentation/ Modelo .pbix, medidas DAX y capturas del tablero
05_validation/   Cuadre de totales del tablero contra SQL + checklist de calidad
```

Cada fase se entrega en su rama (`feat/p1-01-raw`, `feat/p1-02-staging`, …) y entra por
Pull Request. El PR explica qué se hizo y qué número de control se verificó.

---

## Hallazgos

> Se completan al cerrar cada fase. Formato de cada hallazgo: **pregunta → magnitud →
> causa → decisión**, con la captura del tablero y la consulta que lo respalda.

---

## Limitaciones (declaradas, no escondidas)

**El transportista no es un dato real de Olist.** El dataset no publica qué transportista
llevó cada pedido. Cualquier columna de transportista es derivada por región; por eso las
conclusiones de SLA se hacen **por estado**, no por transportista, para no confundir el
efecto de la geografía con el de la empresa de reparto. En una entrevista esto se dice
así: *"detecté que el transportista estaba confundido con la región y no saqué
conclusiones causales de ahí"*.

Otras limitaciones se documentan en [`docs/diccionario-datos.md`](docs/diccionario-datos.md).

---

## Cómo reproducirlo

Requisitos: PostgreSQL 18 con pgAdmin 4, y los 9 CSV de Olist en `01_raw/entrada/`
(no están en Git por tamaño: se descargan de Kaggle; ver `01_raw/sources.md`).

**Paso 1 — crear la base.** En pgAdmin: clic derecho en **Databases** → **Create** →
**Database…**. Nombre `entregas`, **Encoding** UTF8.

**Paso 2 — crear las tablas.** Clic derecho sobre `entregas` → **Query Tool** → ejecutar
`01_raw/02_crear_tablas.sql`.

**Paso 3 — cargar los datos.** Una línea en PowerShell, desde la carpeta del proyecto:

```powershell
& "C:\Program Files\PostgreSQL\18\bin\psql.exe" -U postgres -d entregas -W -f 01_raw\03_cargar.sql
```

Pide la contraseña y carga los 8 CSV. Este paso usa `psql` porque pgAdmin no puede leer
archivos de tu computador (el servidor corre con otra cuenta de Windows).

Al terminar, el script verifica los 8 conteos y la suma de precios (13.591.643,70).

**Paso 4 — limpieza.** Query Tool sobre `entregas`: `02_staging/01_vistas.sql` y luego
`02_staging/02_verificacion.sql`.

**Paso 5 — modelo.** `03_modeling/01_estrella.sql` y `03_modeling/02_verificacion.sql`.

Los hashes SHA-256 de los CSV están en [`01_raw/sources.md`](01_raw/sources.md).

---

## Fuente y créditos

| Campo | Detalle |
|---|---|
| Dataset | Brazilian E-Commerce Public Dataset by Olist |
| Enlace | https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce |
| Autor | Francisco Magioli (publicado por Olist) |
| Licencia | CC BY-NC-SA 4.0 |
| Periodo | septiembre 2016 – octubre 2018 |
| Uso | Educativo y no comercial |

Los datos comerciales están anonimizados por el publicador. El uso es educativo y sin
fines comerciales; el dataset conserva su licencia original.
