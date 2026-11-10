# Fuentes de datos — Proyecto 1 (Entregas y SLA)

## Dataset

**Brazilian E-Commerce Public Dataset by Olist**

| Campo | Valor |
|---|---|
| Origen | Kaggle — <https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce> |
| Publicado por | Olist (marketplace brasileño) |
| Autor | Francisco Magioli |
| Licencia | CC BY-NC-SA 4.0 |
| Periodo | septiembre 2016 – octubre 2018 |
| Uso | Educativo, no comercial |
| Fecha de descarga | 2026-10 (sesión anterior) |
| Verificado | 2026-11-10 |

Los CSV **no se versionan** en Git (120 MB). Se descargan desde Kaggle y se colocan en
`01_raw/entrada/` con los nombres exactos de la tabla de abajo.

## Archivos y hashes

Verificar antes de cargar. Si un hash no coincide, el archivo no se usa.

Conteo medido el 2026-11-10 sobre los archivos locales (el número es el de **registros**
de datos, sin el encabezado). Ocho archivos tienen una línea física por registro, pero
`olist_order_reviews_dataset.csv` no: tiene **104.720 líneas físicas para 99.224
registros**, porque los comentarios entre comillas incluyen saltos de línea. El conteo se
hizo con un parser CSV (respeta comillas), no con `wc -l`.

| Archivo | Filas | Bytes | SHA-256 |
|---|---|---|---|
| `olist_orders_dataset.csv` | 99.441 | 17.654.914 | `8DF58EF3D2D7E9944010F7BEECD9B75367F5588EC6E3C91CEC19AE3345EF9ECF` |
| `olist_order_items_dataset.csv` | 112.650 | 15.438.671 | `0BC4D068C4FE38CBB01BD90E8746E3C613FE7B4BAEF75FAB7B0E329701C3E279` |
| `olist_order_payments_dataset.csv` | 103.886 | 5.777.138 | `4F713964F2815DBBAA40B9488268C55AAC3627BFCE5AA96CF58D1F3616DE3CC0` |
| `olist_order_reviews_dataset.csv` | **99.224** | 14.451.670 | `012B61C7593E34F51FA614EFDF802B9C7056CE6AAE5307DDB93236E7CFC797D7` |
| `olist_customers_dataset.csv` | 99.441 | 9.033.957 | `983A422239E1712DED753B3BF9ECF47DC73F144D306029DCFA99E70A226883D2` |
| `olist_products_dataset.csv` | 32.951 | 2.379.446 | `3E6569628A17FBC75FD206EE357B59E20364B9AFA90F5B6CD5B4D624C58AA9CC` |
| `olist_sellers_dataset.csv` | 3.095 | 174.703 | `1F643D2B950373B85735E7794B20986F528D7A000432E7C6F9BCBB44D0846A0E` |
| `product_category_name_translation.csv` | 71 | 2.613 | `A81F0D1F27B27E7293F761BC79E3CE8F348EE39C4B3ED3E49BDE38F478586278` |
| `olist_geolocation_dataset.csv` | 1.000.163 | 61.273.883 | `B514F6FC991B9566AEBA02AA5D67E2C3630F034B60A0E05AA0D082A3B66D88D6` |

> **Dato que ya confirma la trampa 4:** hay **99.224 reseñas para 99.441 pedidos**, con
> **547 pedidos que tienen 2 o 3 reseñas** y **789 `review_id` repetidos en pedidos
> distintos**. Si se promedia sin deduplicar, el promedio queda ponderado por los pedidos
> con reseña repetida. La fase 2 debe deduplicar (la respuesta más reciente) y dejar el
> conteo en la bitácora antes de calcular cualquier promedio.

> `olist_geolocation_dataset.csv` (58 MB) **no se usa** en el modelo. Se conserva porque
> viene en el paquete de Kaggle; la dimensión geográfica se arma con el estado del cliente,
> que ya está en `customers` y es suficiente. Cargarlo inflaría el repo sin aportar.

## Trampas conocidas (verificar en la fase de ingesta)

1. **`order_status`** incluye `canceled`, `unavailable`, `invoiced`, `processing`,
   `shipped`, `approved`, `created`, `delivered`. El universo del análisis excluye
   `canceled` y `unavailable`. Documentar cuántos quedan fuera.
2. **Fechas nulas.** `order_delivered_customer_date` es `NULL` en pedidos no entregados.
   Un `NULL` no es `0` días de tránsito. Filtrar por `order_status = 'delivered'` antes
   de calcular tránsito.
3. **`orders` y `order_items` están a distinto grano.** Un pedido tiene N ítems. Sumar
   `price` con un join directo y luego contar pedidos con `COUNT(*)` infla todo. Usar
   `COUNT(DISTINCT order_id)`.
4. **`order_reviews` no es 1:1 con `orders`.** Hay pedidos con más de una reseña. Para
   promediar por pedido hay que deduplicar (la reseña con `review_answer_timestamp` más
   reciente) y documentarlo.
5. **Fechas como texto.** Los CSV traen `YYYY-MM-DD HH:MM:SS`; en la carga se declaran
   `timestamp` y en `staging` se convierten a `date` donde corresponde.
6. **Categorías en portugués.** `product_category_name` viene en portugués; la traducción
   está en `product_category_name_translation.csv` (71 filas, pero hay categorías sin
   traducción: usar `COALESCE` y mostrar el original).
7. **`product_weight_g` y dimensiones** tienen nulos. No imputar sin documentarlo: se
   excluyen del cálculo de flete por peso y se reporta cuántos.
8. **Rango temporal desigual.** 2016-09 tiene 2 pedidos y 2018-09 tiene 1. Los extremos
   no son comparables; el análisis de tendencia va de 2017-01 a 2018-08.
9. **Transportista inexistente.** Ver limitación en el README: no hay dato de
   transportista; no inventarlo ni derivarlo sin declararlo.
10. **Comillas, saltos de línea y BOM.** Los comentarios de reseñas traen comas y saltos
    de línea dentro de comillas: la carga debe ser `FORMAT csv`, nunca texto plano.
    `product_category_name_translation.csv` empieza con BOM (EF BB BF) y PostgreSQL no lo
    elimina solo (llega como U+FEFF): hay que limpiarlo explícitamente.

## Reproducir la descarga

1. Abrir el enlace de Kaggle e iniciar sesión.
2. Descargar `brazilian-ecommerce.zip` (~126 MB).
3. Descomprimir los 9 CSV en `01_raw/entrada/`.
4. Verificar los hashes de la tabla de arriba (`Get-FileHash -Algorithm SHA256`).
