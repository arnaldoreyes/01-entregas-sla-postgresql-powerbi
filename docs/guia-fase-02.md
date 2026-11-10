# Guía de la fase 02 — Limpieza (`02_staging`)

**Proyecto 1 · Entregas y SLA (datos de Olist)**

Esta es la fase donde los datos crudos se vuelven analizables: fechas comparables,
reseñas sin repetir, categorías legibles y banderas de entrega. No se borra ni se inventa
nada; se calcula y se marca.

---

## 1. Qué se hizo

Dos archivos, dos pasos, todo en pgAdmin:

| Paso | Archivo | Qué deja |
|---|---|---|
| 1 | `02_staging/01_vistas.sql` | Esquema `staging` con 8 vistas |
| 2 | `02_staging/02_verificacion.sql` | Tabla de 23 controles con los números |

Las vistas:

| Vista | Grano | Filas |
|---|---|---:|
| `staging.clientes` | Un cliente | 99.441 |
| `staging.vendedores` | Un vendedor | 3.095 |
| `staging.productos` | Un producto, con categoría traducida | 32.951 |
| `staging.pedidos` | Un pedido, con banderas de entrega | 99.441 |
| `staging.resenas` | Un pedido, con una sola reseña | 98.673 |
| `staging.pagos` | Un pedido, con sus pagos resumidos | 99.440 |
| `staging.items` | Un ítem, con todo lo del pedido | 112.650 |
| `staging.pedidos_resumen` | Un pedido, con su reseña | 99.441 |

---

## 2. Por qué vistas y no tablas

Una vista no guarda datos: es una consulta con nombre. Se calcula cada vez que se abre.
Tres ventajas para este proyecto:

1. **Trazabilidad.** Se puede leer el cálculo y compararlo con la tabla cruda. Si el
   tablero da un número raro, se abre la vista y se ve de dónde sale.
2. **Sin copias viejas.** Si se corrige algo en la carga, la vista lo refleja sola. Una
   tabla de staging se queda con el dato viejo y nadie se entera.
3. **Menos espacio y menos pasos.** No hay que "refrescar" nada.

El costo es que algunas consultas son más lentas. Con 112.650 filas es irrelevante: el
motor lo resuelve en menos de un segundo. Si el proyecto creciera a millones de filas, se
podría materializar; hoy no hace falta.

---

## 3. Las definiciones operativas

Estas definiciones son las que después usan el modelo y el tablero. Están escritas para
que no se improvisen en cada consulta.

| Término | Definición | Número |
|---|---|---:|
| **Universo** | Pedidos con estado distinto de `canceled` y `unavailable` | 98.207 |
| **Entregado** | Estado `delivered` **y** fecha de entrega conocida | 96.470 |
| **A tiempo** | Fecha de entrega (día) ≤ fecha prometida (día) | 89.936 |
| **Tarde** | Fecha de entrega (día) > fecha prometida (día) | 6.534 |
| **Días de tránsito** | Fecha de entrega − fecha de compra, en días | mediana 10 |
| **Días vs. promesa** | Fecha de entrega − fecha prometida (con signo) | — |
| **OTIF** | Entregados a tiempo y completos ÷ universo | **91,58 %** |
| **% a tiempo** | Entregados a tiempo ÷ entregados | **93,23 %** |

“Completo” se define como: el pedido tiene al menos un ítem registrado. En estos datos
**todos los pedidos entregados tienen ítems** (0 casos de entregado sin ítems), así que
el OTIF queda igual a “entregado a tiempo”.

---

## 4. Decisiones y descartes

### 4.1 Se comparan días, no horas

La promesa es una fecha. Si se comparan `timestamp`, un pedido entregado a las 18:00 del
día prometido contra una promesa a las 00:00 saldría “tarde” sin serlo. Se convierte todo
a `date` y se compara día contra día.

### 4.2 El denominador del OTIF es el universo

1.729 pedidos están en curso (`shipped`, `invoiced`, `processing`, `created`,
`approved`). En un corte histórico, un pedido que nunca se entregó es un incumplimiento:
entra al denominador. Por eso el OTIF es 91,58 % y no 93,23 %. La segunda cifra también
se reporta, porque mide otra cosa: qué pasa entre los que sí llegaron.

**Descartado:** medir el OTIF solo sobre entregados. Infla el indicador y esconde los
pedidos que se quedaron en el camino.

### 4.3 La reseña que se queda

Cuando un pedido tiene 2 o 3 reseñas, se conserva la de `fecha_respuesta` más reciente.
Es la que refleja la última impresión del cliente. El desempate por `resena_id` evita que
el resultado cambie entre ejecuciones.

**Descartado:** promediar las reseñas del mismo pedido. Un pedido con tres reseñas
pesaría tres veces frente a uno con una.

### 4.4 Las categorías no se inventan

Si no hay traducción, se queda el nombre en portugués. Si no hay categoría, se etiqueta
`sin_categoria`. **Descartado:** asignar “otros” a todo lo que falta; borraría la
diferencia entre “no tiene categoría” y “no está traducida”.

### 4.5 Los pagos se resumen, no se usan para el ingreso

`staging.pagos` deja una fila por pedido (total pagado, cuotas, tipo principal) para poder
unirla sin multiplicar filas. El ingreso se mide en `staging.items` (`precio + flete`).
**Descartado:** sumar `pagos` y `items` en la misma consulta: son granos distintos y el
total saldría inflado.

### 4.6 El peso inválido se marca, no se corrige

2 productos sin peso y 4 con peso 0 afectan a 26 ítems. Se marcan con `peso_invalido` y
se excluyen del flete por kilo. **Descartado:** imputar el peso promedio; inventaría una
relación que después no se podría defender.

---

## 5. Los primeros hallazgos (medidos)

- **91,58 % de OTIF**: de 98.207 pedidos del universo, 89.936 llegaron a tiempo.
- **6.534 pedidos tarde** (6,77 % de los entregados).
- **Mediana de 10 días** de tránsito; **p90 de 23 días**. La cola es larga: el 10 % más
  lento tarda más del doble que la mediana.
- **Máximo de 210 días**: hay pedidos que tardaron siete meses. No es un error de carga;
  está en el dato y hay que decidir si se muestran o se tratan como atípicos en el
  tablero.

Estos números son la base de las preguntas 01, 02 y 03 del README. Todavía no se
desagregan por estado: eso es `03_modeling`.

---

## 6. Cinco preguntas de entrevista (con respuesta)

**1. “¿Por qué el OTIF da 91,58 % si el 93,23 % de los entregados llegó a tiempo?”**
Porque miden distinto. El 93,23 % es sobre los que se entregaron; el OTIF usa como
denominador todo el universo (98.207), incluidos los 1.729 pedidos que nunca tuvieron
entrega confirmada. Un pedido que no llegó no puede ser OTIF.

**2. “¿Por qué comparas fechas y no marcas de tiempo?”**
Porque la promesa es un día, no una hora. Comparar timestamps marcaría como tarde un
pedido entregado a las 18:00 del día prometido. Convertí todo a `date` y comparo día
contra día.

**3. “¿Cómo trataste las reseñas repetidas?”**
99.224 reseñas para 98.673 pedidos; 547 pedidos tienen 2 o 3. Me quedo con la de
`fecha_respuesta` más reciente. El promedio global casi no cambia (4,0864), pero cada
pedido pasa a pesar una sola vez, que es lo que importa al cruzar retraso con
satisfacción.

**4. “¿Por qué vistas y no tablas materializadas?”**
Porque necesito poder auditar cada número contra el crudo y no quedarme con copias
viejas. Con 112.650 filas el costo de calcular es despreciable; si el volumen creciera,
materializaría solo lo que el tablero consulta.

**5. “¿Qué limitación tiene este corte?”**
Que 1.729 pedidos no tienen desenlace: en la fecha del dataset seguían en tránsito o se
quedaron ahí. Los cuento como no OTIF y lo declaro. Lo correcto sería un análisis por
cohorte (pedidos con suficiente tiempo para haber llegado), y eso se puede hacer con la
fecha de compra.

---

## 7. Limitaciones anotadas

- **8 pedidos `delivered` sin fecha**: no se pueden medir; se marcan y se excluyen.
- **1.729 pedidos sin desenlace**: entran al denominador del OTIF como incumplimiento.
- **Días calendario, no hábiles**: los hábiles llegan con el calendario en `03_modeling`.
- **Peso inválido en 26 ítems**: se excluyen del análisis de flete por kilo.
- **Sin transportista real**: el SLA se analiza por estado, no por empresa de reparto.

**Lo que sigue:** `03_modeling` — esquema estrella, calendario con días hábiles y vistas
`vw_*` que lee Power BI.
