# Guía de diseño del tablero — P1

Objetivo: que un desconocido entienda la página en 5 segundos. No es “poner bonito”:
es jerarquía, narrativa y color con significado.

Mockup de referencia: `04_presentation/mockup-pagina1.png`.
Assets listos en `04_presentation/assets/` (fondo e iconos).

---

## 1. Sistema de diseño

| Elemento | Valor |
|---|---|
| Lienzo | 1600 × 900 px (16:9) |
| Fondo | `assets/fondo.png` (#081222 → #0C203A) |
| Tarjetas / paneles | #0F243E y #112844 |
| Acento | #38BDF8 (azul) |
| Alerta / retraso | #F87171 (rojo) |
| Éxito | #34D399 (verde) |
| Advertencia | #FBBF24 (ámbar) |
| Texto | #E8F2FF |
| Texto secundario | #8AA2C0 |

### Escala tipográfica única (igual en las tres páginas)

| Elemento | Tamaño | Peso | Color |
|---|---:|---|---|
| Kicker de página | 11 | Negrita | #38BDF8 |
| Título de página | 36 | Negrita | #E8F2FF |
| Subtítulo de página | 15 | Normal | #8AA2C0 |
| Etiqueta de tarjeta | 12 | Normal | #8AA2C0 |
| Valor de tarjeta | 36 | Negrita | #E8F2FF |
| Kicker de panel | 10 | Negrita | #8AA2C0 |
| Título de panel | 13 | Negrita | #E8F2FF |
| Titular de conclusión | 14 | Negrita | #E8F2FF |
| Lectura | 11 | Normal | #8AA2C0 |
| Número de conclusión | 18 | Negrita | #38BDF8 |

No se cambia ningún tamaño de una página a otra. Si un elemento no está en la
tabla, se agrega aquí antes de usarlo.

Reglas:

- Una sola dirección de lectura: título → KPIs → gráfico principal → apoyo → conclusión.
- Rojo solo para lo malo, azul para lo bueno. Nada de colores decorativos.
- Cada visual con título corto que **diga algo**, no “Gráfico 1”.
- Bordes redondeados 12–16 px, sin sombras fuertes.

---

## 2. Página 1 — Resumen

### Estructura

```
[ barra de acento 4 px ]
PROYECTO 1 · ENTREGAS Y SLA
Título: La entrega falla en 1 de cada 15 pedidos
Subtítulo: 91,58 % a tiempo · SP y RJ concentran la mitad · cuesta 2 puntos

[OTIF] [PEDIDOS TARDE] [TASA] [TRÁNSITO] [INGRESO]      ← 5 tarjetas, 112 px alto

[ OTIF por mes (870×420) ]   [ Pedidos tarde por estado (580×420) ]

[ 1 · no es parejo ] [ 2 · peores tasas ] [ 3 · destruye la percepción ]
```

### Cómo se construye en Power BI

1. **Lienzo.** Formato de la página → Tamaño: 1600 × 900. Fondo del lienzo → imagen
   `assets/fondo.png`, ajuste “Ajustar”.
2. **Barra de acento.** Insertar → Formas → Rectángulo, 1600×4, color #38BDF8, sin borde.
3. **Encabezado.** Tres cuadros de texto:
   - `PROYECTO 1 · ENTREGAS Y SLA` — 11 pt, #38BDF8, negrita, espaciado.
   - Título — 36 pt, #E8F2FF, negrita.
   - Subtítulo — 15 pt, #8AA2C0.
4. **Tarjetas.** Visual Tarjeta, 288×112, una por KPI. Formato → Efectos → Fondo
   #0F243E, radio 12, borde desactivado. Etiqueta 10 pt mayúsculas #8AA2C0; valor 28–30.
   Icono: Insertar → Imagen → `assets/icono-*.png`, **58×58**, esquina superior derecha.
   Cada icono es un badge circular con glifo relleno: `icono-otif` (escudo),
   `icono-retraso` (alerta), `icono-tasa` (medidor), `icono-reloj`, `icono-dinero`.
5. **Gráfico principal.** Gráfico de áreas (no de líneas): eje `dim_tiempo[fecha_mes]`,
   valor `OTIF %`. Línea #38BDF8 de 3 px; relleno #14395E. Eje Y desde 76 hasta 100.
   Panel Análisis → Línea constante en 0.9158, gris.
   Anotación: cuadro de texto `mar-2018 · 79,17 %` sobre un rectángulo rojo #F87171,
   colocado junto al punto más bajo.
6. **Barras.** Gráfico de barras: eje `dim_cliente[estado]`, valor `Pedidos tarde`,
   Top 10 por `Pedidos tarde`. Color condicional: SP y RJ en #F87171, resto #38BDF8.
7. **Franja de conclusiones.** Rectángulo 1480×108, #142E52. Tres columnas con círculo
   azul numerado (Formas → Óvalo) y dos textos: titular 14 bold + lectura 10.
8. **Títulos de panel.** Texto pequeño 10 pt #8AA2C0 encima del titular 17 bold.

---

## 3. Página 2 — Entregas (concepto)

- **Título:** `El 4,9 % de los pedidos tarda más de 30 días`
- **KPIs:** mediana 10 · p90 23 · % tarde 6,77 %.
- **Mapa de calor (sustituye la tabla):** Matriz con `dim_cliente[estado]` en filas y
  `dim_tiempo[anio_mes]` en columnas; valor `% tarde`; formato condicional → escala de
  color de #112844 a #F87171. Así se ve en qué estado y en qué mes se junta el problema.
- **Histograma:** columnas por `tramo_dias`, con la barra `30+` en rojo.
- **Lectura:** “La cola no se apaga: 30+ tiene más pedidos que 25-29.”

## 4. Página 3 — Impacto (concepto)

- **Título:** `Llegar tarde cuesta 2 puntos de calificación`
- **Bloque central tipo “antes/después”:** dos números grandes, 4,29 y 2,27, con una
  flecha y el −2,02 entre ellos. Se arma con formas y cuadros de texto; es más potente
  que cuatro tarjetas sueltas.
- **Distribución:** columnas 100 % apiladas con colores semánticos: 1–2 rojo, 3 gris,
  4–5 azul. Sin categoría “(En blanco)”.
- **Lectura:** “53,8 % de las reseñas de pedidos tarde son de 1 estrella.”

---

## 5. Qué evitar

- Fondos claros con gráficos por defecto.
- Tablas sin formato condicional.
- Gráficos de pastel con muchas categorías.
- Etiquetas de datos gigantes o abreviadas (“15,84 mill.”).
- Colores distintos sin significado.
