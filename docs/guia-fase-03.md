# Guía de la fase 03 — Modelo (`03_modeling`)

**Proyecto 1 · Entregas y SLA (datos de Olist)**

El modelo es la traducción de las tablas limpias a la forma en que Power BI piensa:
dimensiones para filtrar, hechos para sumar. Aquí se define qué es un pedido, qué es un
ítem, cómo se cuenta el tiempo y de dónde sale cada número del tablero.

---

## 1. Qué se construyó

Dos archivos, dos pasos en pgAdmin, sobre la base `entregas`:

| Paso | Archivo | Qué deja |
|---|---|---|
| 1 | `03_modeling/01_estrella.sql` | Esquema `modelo`: 6 tablas y 2 vistas |
| 2 | `03_modeling/02_verificacion.sql` | 22 controles con los números |

| Tabla | Qué es | Filas |
|---|---|---:|
| `modelo.dim_tiempo` | Un día por fila, con año, mes, día y si es hábil | 791 |
| `modelo.feriados` | Feriados nacionales de Brasil 2016–2018 | 27 |
| `modelo.dim_cliente` | Un cliente, con ciudad y estado | 99.441 |
| `modelo.dim_producto` | Un producto, con categoría traducida | 32.951 |
| `modelo.dim_estado_entrega` | Los 5 estados posibles de una entrega | 5 |
| `modelo.hecho_pedidos` | Un pedido, con OTIF, días y calificación | 99.441 |
| `modelo.hecho_items` | Un ítem, con precio, flete e ingreso | 112.650 |
| `modelo.vw_pedidos` / `vw_items` | Los hechos con los nombres ya pegados | — |

---

## 2. La estrella, explicada

```
                         dim_tiempo
                             │
        dim_cliente ─── hecho_pedidos ─── dim_estado_entrega
                             │
                        hecho_items ─── dim_producto
```

- **Dimensiones**: el “quién, qué, cuándo y cómo salió”. Sirven para filtrar y agrupar.
- **Hechos**: el “cuánto”. Tienen las llaves de las dimensiones y los números que se
  suman o promedian.

En Power BI se cargan las 5 dimensiones y las 2 tablas de hechos, y se trazan las
relaciones por las llaves (`cliente_id`, `producto_id`, `fecha_compra`,
`estado_entrega_id`). No se necesita ninguna relación entre los dos hechos: se cruzan a
través de las dimensiones.

---

## 3. Por qué dos tablas de hechos y no una

Es la decisión central de la fase.

| Indicador | Grano correcto | Por qué |
|---|---|---|
| Ingreso, flete, cantidad | **Ítem** | Un pedido puede tener varios productos |
| OTIF, días de tránsito, calificación | **Pedido** | Son uno solo por compra |

Si todo viviera en la tabla de ítems, un pedido con cinco productos contaría cinco veces
en el OTIF. Si todo viviera en la tabla de pedidos, se perdería el detalle por categoría.
Separados, cada indicador se mide donde corresponde.

El cruce entre ambos se hace por las dimensiones compartidas (cliente, tiempo, estado de
entrega). **Nunca se suman las dos tablas de hechos en la misma consulta**: cada una
responde una pregunta distinta.

---

## 4. El calendario

- **Rango: 2016-09-01 a 2018-10-31.** Arranca en el mes de la primera compra (2016-09-04)
  y termina en el mes de la última (2018-10-17). No se empieza en 2016-01-01 porque no
  hay ventas antes de septiembre; no se termina en 2018-12 porque no hay datos. Así el
  eje de meses no muestra periodos vacíos que parezcan caídas.
- **791 días, 548 hábiles.**
- **Feriados:** 27 nacionales de Brasil (2016–2018). Se excluyen carnaval y corpus
  christi porque son puntos facultativos y su inclusión es discutible; queda documentado.
- **`es_habil`** = lunes a viernes que no sea feriado.

### Días calendario vs. días hábiles

| Medida | Mediana |
|---|---:|
| Días calendario (compra → entrega) | **10** |
| Días hábiles | **7** |

Se guardan las dos. La pregunta del README pide días hábiles; los calendario sirven para
comparar con la promesa, que también se expresa en días calendario.

---

## 5. La dimensión de estado de entrega

| ID | Estado | Pedidos |
|---:|---|---:|
| 1 | a tiempo | 89.936 |
| 2 | tarde | 6.534 |
| 3 | sin entrega | 1.729 |
| 4 | entregado sin fecha | 8 |
| 5 | fuera del universo | 1.234 |

Es la que permite responder “OTIF por estado” sin repetir la regla en cada consulta.
`fuera del universo` son los cancelados y no disponibles; `sin entrega` son los que
estaban en curso al corte.

---

## 6. Las medidas que salen del modelo

| Medida | De dónde | Valor |
|---|---|---:|
| Ingreso (precio + flete) | `hecho_items.ingreso` | 15.843.553,24 |
| Ingreso solo producto | `hecho_items.precio` | 13.591.643,70 |
| Flete | `hecho_items.flete` | 2.251.909,54 |
| Pedidos | `hecho_pedidos` | 99.441 |
| OTIF | pedidos a tiempo ÷ universo | 91,58 % |
| Ticket promedio | ingreso ÷ pedidos con ítems | — |
| Días de tránsito | mediana de `dias_transito` | 10 |

> Cuidado con el “13,59 M”: ese número es **solo precio**. El ingreso definido en
> AGENTS incluye flete y da **15,84 M**. En el tablero hay que decir cuál se está
> mostrando.

---

## 7. Cinco preguntas de entrevista (con respuesta)

**1. “¿Por qué `hecho_pedidos` es un hecho y `dim_cliente` una dimensión?”**
Porque el hecho guarda lo que se mide (días, OTIF, calificación) y cambia pedido a
pedido; la dimensión guarda el atributo que describe (ciudad, estado) y se repite. El
cliente no se suma: se usa para filtrar.

**2. “¿Por qué el calendario arranca el 2016-09-01 y no el 2016-01-01?”**
Porque la primera compra es del 2016-09-04. Enero a agosto serían meses en cero que en un
gráfico parecen una caída de ventas cuando en realidad no había operación.

**3. “¿Por qué dos tablas de hechos?”**
Porque el ingreso vive en el ítem y el OTIF en el pedido. Si se juntan, un pedido con
cinco productos pesa cinco veces en el OTIF. Separadas, cada indicador se calcula en su
grano.

**4. “La mediana es 10 días calendario y 7 hábiles. ¿Cuál muestras?”**
Las dos, según la pregunta. Para operación, días hábiles (lo que tarda el proceso); para
el cliente, calendario (lo que espera). La promesa se compara en calendario.

**5. “Si mañana piden ‘solo São Paulo’, ¿qué se toca?”**
Nada del modelo: se filtra `dim_cliente.estado = 'SP'`. El OTIF y el ingreso se recalculan
solos porque las medidas ya están definidas sobre las relaciones. No hay que reescribir
ninguna consulta.

---

## 8. Limitaciones anotadas

- **Sin transportista real**: el SLA se analiza por estado del cliente.
- **1.729 pedidos sin desenlace**: entran al denominador del OTIF como incumplimiento.
- **8 entregados sin fecha**: no se pueden medir; tienen su propio estado.
- **Feriados solo nacionales**: no se descuentan feriados estatales ni municipales.
- **Fechas sin zona horaria**: se trabaja con el día tal como viene en el archivo.

**Lo que sigue:** `04_presentation` — el tablero en Power BI, con estas tablas y las
medidas DAX.
