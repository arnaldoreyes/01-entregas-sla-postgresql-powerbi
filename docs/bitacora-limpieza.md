# Bitácora de limpieza — fase 02 (`02_staging`)

**Proyecto 1 · Entregas y SLA (datos de Olist)**

Qué se limpió, qué no, y con qué número se comprueba. Cada fila de esta bitácora se
puede reproducir con `02_staging/02_verificacion.sql`.

---

## 1. Resumen: antes y después

| Control | Antes (crudo) | Después (staging) | Qué se hizo |
|---|---:|---:|---|
| Pedidos | 99.441 | 99.441 | No se borra ninguno; se marcan |
| Pedidos en el universo | 99.441 | **98.207** | Se excluyen 1.234 `canceled` + `unavailable` |
| Pedidos entregados medibles | 96.478 | **96.470** | 8 `delivered` no tienen fecha de entrega |
| Pedidos sin entrega (en el universo) | — | 1.737 | 1.729 en curso + los 8 sin fecha |
| Entregados a tiempo | — | **89.936** | 93,23 % de los entregados |
| Entregados tarde | — | **6.534** | 6,77 % de los entregados |
| OTIF | — | **91,58 %** | A tiempo y completos sobre el universo |
| Reseñas | 99.224 | **98.673** | Una por pedido (547 tenían 2 o 3) |
| Calificación promedio | 4,0864 | **4,0864** | No cambia al cuarto decimal (§3) |
| Ítems de pedido | 112.650 | 112.650 | Sin cambios |
| Ingreso (precio + flete) | 15.843.553,24 | 15.843.553,24 | Sin cambios |
| Pagos | 103.886 filas | 99.440 filas | Resumidos a uno por pedido |
| Productos sin categoría | 610 | 610 | Se etiquetan `sin_categoria` |
| Productos en categorías sin traducción | 2.058 | 2.058 | Se queda el nombre en portugués |
| Ítems con peso inválido | — | 26 | Peso nulo o cero; no se imputa |
| Pedidos sin ningún ítem | 775 | 775 | Se reportan; no suman ingreso |

---

## 2. Qué se limpió, decisión por decisión

### 2.1 Fechas: de `timestamp` a `date`

Las cinco fechas de `pedidos` pasan a día. Motivo: la promesa de entrega es una **fecha**,
no una hora. Comparar `2028-03-10 14:00` contra `2028-03-10 00:00` diría "tarde" cuando
el paquete llegó el día prometido. Con `date`, la comparación es la que el cliente vive.

### 2.2 Universo: se excluyen 1.234 pedidos del denominador

`canceled` (625) y `unavailable` (609) no son entregas: no se pueden evaluar contra una
promesa. Se excluyen **del denominador**, no de la tabla: siguen ahí para poder auditar.

Los 1.729 pedidos que están `shipped`, `invoiced`, `processing`, `created` o `approved`
tampoco tienen entrega confirmada. Se cuentan como **no OTIF**: en un corte histórico, un
pedido que nunca llegó es un incumplimiento. La alternativa (medir solo sobre entregados)
da 93,23 % y también queda reportada, para que la diferencia sea explícita.

### 2.3 Entregado: estado `delivered` **y** fecha real

Hay 8 pedidos marcados `delivered` sin fecha de entrega. No se pueden medir en días de
tránsito ni en puntualidad. Se marcan con `entregado_sin_fecha = true` y se excluyen de
los cálculos, en vez de inventarles una fecha.

### 2.4 A tiempo: se comparan días

`a_tiempo = fecha_entrega (día) <= fecha_estimada (día)`. Es falso cuando llegó un día
después o más. Queda `NULL` cuando el pedido no se entregó: no es "tarde", es "sin dato".

### 2.5 Días de tránsito y días contra la promesa

- `dias_transito = fecha_entrega - fecha_compra` (días calendario).
- `dias_vs_promesa = fecha_entrega - fecha_estimada`: positivo = tarde, negativo =
  temprano. Se guarda con signo porque "llegó 3 días antes" es información, no un cero.

Medido sobre los 96.470 entregados: mínimo 0, máximo 210, mediana **10**, p90 **23**,
promedio **12,50**. No hay días negativos (ninguna entrega anterior a la compra).

> Los días **hábiles** que pide la pregunta 02 del README se calculan en `03_modeling`,
> con el calendario. Aquí se deja el dato base en días calendario.

### 2.6 Reseñas: una por pedido

99.224 reseñas para 98.673 pedidos. 547 pedidos tienen 2 o 3 reseñas. Se queda la de
`fecha_respuesta` más reciente (desempate por `resena_id` para que el resultado sea
siempre el mismo). Sin esto, un pedido con tres reseñas pesa tres veces en el promedio.

### 2.7 Categorías: traducidas, con dos excepciones

73 categorías en portugués; 71 tienen traducción. Las 2.058 líneas de producto de
`pc_gamer` y `portateis_cozinha_e_preparadores_de_alimentos` se quedan con el nombre en
portugués. Los 610 productos sin categoría se etiquetan `sin_categoria`. No se imputa
ninguna categoría.

### 2.8 Pagos: resumidos a uno por pedido

La tabla cruda tiene 103.886 pagos para 99.440 pedidos. Se agrupan en una fila por pedido
(cantidad de pagos, total pagado, cuotas máximas, tipo principal) para poder unirlos sin
multiplicar filas. **No se usan para el ingreso**: el ingreso sale de los ítems.

### 2.9 Peso inválido: se marca, no se corrige

6 productos tienen peso nulo (2) o cero (4). Afectan a 26 ítems. Se marcan con
`peso_invalido = true` y se excluirán del análisis de flete por kilo, reportando cuántos.

---

## 3. Lo que no cambió (y por qué igual importa)

El promedio de calificación crudo y el deduplicado dan **4,0864** los dos. La
deduplicación no movió el promedio porque las reseñas repetidas tienen calificaciones
parecidas; lo que cambia es **el peso de cada pedido**. Con la tabla cruda, 547 pedidos
pesaban dos o tres veces; con staging, cada pedido pesa una. Para un promedio global casi
no se nota; para comparar "a tiempo vs. tarde" por pedido, sí.

---

## 4. Cómo se comprueba

```sql
-- En pgAdmin, Query Tool sobre "entregas"
-- Ejecutar 02_staging/02_verificacion.sql
```

Debe devolver 23 filas con estos valores clave: universo 98.207, entregados 96.470,
a tiempo 89.936, tarde 6.534, OTIF 91,58 %, reseñas 98.673, ítems 112.650, ingreso
15.843.553,24.

Si alguno no coincide, no se sigue al modelo: primero se revisa qué cambió.
