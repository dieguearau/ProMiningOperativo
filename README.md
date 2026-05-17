# Detección de Ineficiencias Operativas en Órdenes de Trabajo

<p align="center">
  <img src="assets/img/sankey_flujo_operativo.png" width="950">
</p>

<p align="center">
  Simulación y análisis de procesos operativos utilizando técnicas de process mining y analítica operacional.
</p>

---

# Objetivo del proyecto

Este proyecto busca detectar ineficiencias operativas en el ciclo de vida de órdenes de trabajo mediante:

* análisis de eventos operativos;
* detección de loops y reprocesos;
* análisis de lead time;
* identificación de cuellos de botella;
* evaluación de SLA;
* simulación de mejoras operativas.

El enfoque replica escenarios comunes en empresas de servicios, soporte técnico, logística y operaciones.

---

# Problema de negocio

Muchas organizaciones poseen procesos operativos complejos donde las órdenes de trabajo atraviesan múltiples áreas y estados.

Aunque los sistemas registran eventos y trazabilidad, normalmente no existe una visión clara sobre:

* dónde se generan las demoras;
* qué loops impactan más;
* qué actividades consumen más tiempo;
* cómo afectan los reprocesos al SLA;
* qué mejoras podrían generar mayor impacto.

Este proyecto busca responder esas preguntas utilizando análisis de procesos sobre event logs simulados.

---

# Principales funcionalidades

* Simulación de event logs operativos.
* Generación de órdenes de trabajo con múltiples flujos.
* Simulación de loops y reprocesos.
* Análisis de lead time.
* Análisis de SLA.
* Identificación de cuellos de botella.
* Heatmaps operativos por día/hora.
* Diagramas Sankey de flujo de proceso.
* Pareto de tiempo acumulado.
* Simulación de escenarios de mejora.
* Generación de reporte ejecutivo en Quarto.

---

# Flujo operativo simulado

```text
OT creada
→ Validación inicial
→ Clasificación de OT
→ Asignación
→ Agenda coordinada
→ Trabajo iniciado
→ Trabajo finalizado
→ Validación de cierre
→ OT cerrada
```

Con posibles loops asociados a:

* Información incompleta.
* Reagendamientos.
* Falta de materiales.
* Ejecución fallida.
* Observaciones administrativas.

---

# Tecnologías utilizadas

<p>
  <img src="https://img.shields.io/badge/R-276DC3?style=for-the-badge&logo=r&logoColor=white"/>
  <img src="https://img.shields.io/badge/dplyr-1f3b4d?style=for-the-badge"/>
  <img src="https://img.shields.io/badge/ggplot2-4E7C7B?style=for-the-badge"/>
  <img src="https://img.shields.io/badge/Quarto-39729E?style=for-the-badge&logo=quarto&logoColor=white"/>
  <img src="https://img.shields.io/badge/networkD3-C65D4A?style=for-the-badge"/>
</p>

---

# Principales análisis realizados

## Lead time operacional

Análisis del tiempo total transcurrido desde la creación hasta el cierre de una OT.

<p align="center">
  <img src="assets/img/distribucion_lead_time.png" width="800">
</p>

---

## Impacto de loops y reprocesos

Detección de órdenes que regresan a etapas anteriores del flujo y su impacto sobre SLA y tiempo total.

<p align="center">
  <img src="assets/img/impacto_loops.png" width="800">
</p>

---

## Heatmap operativo

Visualización de concentración de eventos por día y hora.

<p align="center">
  <img src="assets/img/heatmap_operacional.png" width="850">
</p>

---

## Pareto operacional

Identificación de actividades que explican la mayor parte del tiempo total consumido.

<p align="center">
  <img src="assets/img/pareto_operacional.png" width="950">
</p>

---

## Simulación de mejoras

Comparación entre escenario actual y escenario mejorado mediante reducción de loops críticos.

<p align="center">
  <img src="assets/img/sla_actual_vs_mejorado.png" width="750">
</p>

---

# Principales insights

* Los loops representan una parte significativa del lead time total.
* Los reagendamientos y problemas de materiales generan los mayores impactos operativos.
* Existen actividades que concentran gran parte del tiempo acumulado.
* La simulación de mejoras permite reducir incumplimientos de SLA y tiempo operativo total.

---

# Estructura del proyecto

```text
process-mining-operacional/
│
├── assets/
│   └── img/
│
├── datos/
│   ├── event_log_simulado.csv
│   ├── ot_base_simulada.csv
│   └── usuarios_simulados.csv
│
├── outputs/
│   ├── graficos/
│   ├── html/
│   └── tablas/
│
├── scripts/
│   ├── eventlogs_simulacion.R
│   ├── eventlogs_analisis.R
│   ├── eventlogs_visualizacion.R
│   └── eventlogs_simulacion_optimizacion.R
│
├── reporte/
│   ├── reporte_proceso_ot.qmd
│   └── reporte_proceso_ot.html
│
└── README.md
```

---

# Reporte ejecutivo

El proyecto incluye un reporte ejecutivo desarrollado en Quarto:

```text
reporte/reporte_proceso_ot.html
```

---

# Posibles aplicaciones

El enfoque puede adaptarse a:

* soporte técnico;
* mantenimiento;
* logística;
* service desk;
* workflows administrativos;
* gestión de tickets;
* atención al cliente;
* procesos internos corporativos.

---

# Autor

Diego Araujo

Proyecto desarrollado como portfolio de analítica operacional y process mining aplicado a operaciones.
