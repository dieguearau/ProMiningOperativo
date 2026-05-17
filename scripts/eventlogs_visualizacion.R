# ------- VISUALIZACIONES DE PROCESO - ORDENES DE TRABAJO ---- ----

suppressPackageStartupMessages({
  library(dplyr)
  library(tidyr)
  library(lubridate)
  library(stringr)
  library(readr)
  library(ggplot2)
  library(scales)
  library(networkD3)
  library(htmlwidgets)
})

# ------- Parámetros ----------------------------------------- ----

dir_datos   <- "datos"
dir_outputs <- "outputs"

dir.create(dir_outputs, showWarnings = FALSE)
dir.create(file.path(dir_outputs, "graficos"), showWarnings = FALSE)
dir.create(file.path(dir_outputs, "html"), showWarnings = FALSE)

archivo_event_log <- file.path(dir_datos, "event_log_simulado.csv")
archivo_ot_base   <- file.path(dir_datos, "ot_base_simulada.csv")

# ------- Carga de datos ------------------------------------- ----

event_log <- read_csv(archivo_event_log, show_col_types = FALSE)
ot_base   <- read_csv(archivo_ot_base, show_col_types = FALSE)

event_log <- event_log %>%
  mutate(
    timestamp = ymd_hms(timestamp),
    fecha_evento = as.Date(fecha_evento),
    es_loop = as.integer(es_loop),
    dia_semana = factor(
      weekdays(timestamp),
      levels = c(
        "lunes",
        "martes",
        "miércoles",
        "jueves",
        "viernes",
        "sábado",
        "domingo"
      ),
      labels = c(
        "Lunes",
        "Martes",
        "Miercoles",
        "Jueves",
        "Viernes",
        "Sabado",
        "Domingo"
      )
    )
  )

ot_base <- ot_base %>%
  mutate(
    fecha_creacion = ymd_hms(fecha_creacion),
    fecha_cierre = ymd_hms(fecha_cierre),
    tuvo_loop = as.integer(tuvo_loop),
    fuera_sla = as.integer(fuera_sla),
    grupo_loop = if_else(tuvo_loop == 1, "Con loop", "Sin loop")
  )

# ------- Sankey - flujo de actividades ---------------------- ----

# Umbral mínimo para mostrar transiciones
# Si queda muy cargado, subir a 20, 30 o 50
umbral_transiciones <- 15

# Actividades del flujo principal
actividades_principales <- c(
  "OT creada",
  "Validacion inicial",
  "Clasificacion de OT",
  "Asignacion",
  "Agenda coordinada",
  "Tecnico en camino",
  "Trabajo iniciado",
  "Trabajo finalizado",
  "Validacion de cierre",
  "OT cerrada"
)

# Transiciones
flujo_transiciones <- event_log %>%
  arrange(ot_id, orden_evento) %>%
  group_by(ot_id) %>%
  mutate(
    actividad_origen = actividad,
    actividad_destino = lead(actividad)
  ) %>%
  ungroup() %>%
  filter(!is.na(actividad_destino)) %>%
  count(actividad_origen, actividad_destino, sort = TRUE, name = "cantidad_transiciones") %>%
  mutate(
    tipo_flujo = case_when(
      actividad_origen %in% actividades_principales &
        actividad_destino %in% actividades_principales ~ "Flujo principal",
      TRUE ~ "Loop / reproceso"
    )
  ) %>%
  filter(
    tipo_flujo == "Flujo principal" |
      cantidad_transiciones >= umbral_transiciones
  )

# Nodos
nodes <- data.frame(
  name = unique(c(flujo_transiciones$actividad_origen, flujo_transiciones$actividad_destino)),
  stringsAsFactors = FALSE
)

# Clasificación de nodos
nodes <- nodes %>%
  mutate(
    grupo = case_when(
      name %in% c(
        "OT creada",
        "Solicitud de informacion adicional",
        "Contacto con cliente para reagendar"
      ) ~ "Atencion al cliente",
      
      name %in% c(
        "Validacion inicial",
        "Clasificacion de OT",
        "OT cerrada",
        "Correccion de cierre"
      ) ~ "Backoffice operativo",
      
      name %in% c(
        "Asignacion",
        "Agenda coordinada"
      ) ~ "Planificacion",
      
      name %in% c(
        "Tecnico en camino",
        "Trabajo iniciado",
        "Trabajo finalizado",
        "Solicitud de material"
      ) ~ "Tecnico de campo",
      
      name %in% c(
        "Material preparado"
      ) ~ "Logistica / inventario",
      
      name %in% c(
        "Validacion de cierre",
        "Observacion de calidad"
      ) ~ "Supervision / calidad",
      
      TRUE ~ "Otros"
    )
  )

# Links
links <- flujo_transiciones %>%
  mutate(
    source = match(actividad_origen, nodes$name) - 1,
    target = match(actividad_destino, nodes$name) - 1,
    value = cantidad_transiciones,
    grupo = tipo_flujo
  ) %>%
  select(source, target, value, grupo)

# Paleta sobria
color_scale <- '
d3.scaleOrdinal()
  .domain([
    "Atencion al cliente",
    "Backoffice operativo",
    "Planificacion",
    "Tecnico de campo",
    "Logistica / inventario",
    "Supervision / calidad",
    "Otros",
    "Flujo principal",
    "Loop / reproceso"
  ])
  .range([
    "#2C5F8A",
    "#4E7C7B",
    "#E6A23C",
    "#6F5A8C",
    "#8AAE92",
    "#C65D4A",
    "#999999",
    "#BDBDBD",
    "#D8A7A7"
  ])
'

sankey_proceso <- sankeyNetwork(
  Links = links,
  Nodes = nodes,
  Source = "source",
  Target = "target",
  Value = "value",
  NodeID = "name",
  NodeGroup = "grupo",
  LinkGroup = "grupo",
  colourScale = JS(color_scale),
  fontSize = 13,
  fontFamily = "Arial",
  nodeWidth = 16,
  nodePadding = 30,
  sinksRight = FALSE
)

saveWidget(
  sankey_proceso,
  file.path(dir_outputs, "html", "sankey_flujo_proceso.html"),
  selfcontained = TRUE
)

# ------- Heatmap día/hora ----------------------------------- ----

heatmap_dia_hora <- event_log %>%
  count(dia_semana, hora_evento, name = "cantidad_eventos")

g_heatmap <- ggplot(
  heatmap_dia_hora,
  aes(x = hora_evento, y = dia_semana, fill = cantidad_eventos)
) +
  geom_tile(color = "white", linewidth = 0.2) +
  scale_fill_distiller(
    palette = "YlOrRd",
    direction = 1
  ) +
  scale_x_continuous(breaks = seq(0, 23, 2)) +
  labs(
    title = "Concentración de eventos por día y hora",
    x = "Hora del día",
    y = "Día de la semana",
    fill = "Eventos"
  ) +
  theme_minimal()

ggsave(
  filename = file.path(dir_outputs, "graficos", "06_heatmap_dia_hora.png"),
  plot = g_heatmap,
  width = 9,
  height = 5
)

# ------- Boxplot lead time: con vs sin loop ----------------- ----

g_box_loop <- ggplot(
  ot_base,
  aes(x = grupo_loop, y = lead_time_horas)
) +
  geom_boxplot(outlier.alpha = 0.35) +
  labs(
    title = "Lead time de OT con y sin loops",
    x = "",
    y = "Lead time (horas)"
  ) +
  theme_minimal()

ggsave(
  filename = file.path(dir_outputs, "graficos", "07_boxplot_lead_time_loop.png"),
  plot = g_box_loop,
  width = 8,
  height = 5
)

# ------- SLA: con vs sin loop ------------------------------- ----

sla_loop <- ot_base %>%
  group_by(grupo_loop) %>%
  summarise(
    cantidad_ot = n(),
    fuera_sla_pct = mean(fuera_sla) * 100,
    .groups = "drop"
  )

g_sla_loop <- ggplot(
  sla_loop,
  aes(x = grupo_loop, y = fuera_sla_pct)
) +
  geom_col() +
  geom_text(
    aes(label = paste0(round(fuera_sla_pct, 1), "%")),
    vjust = -0.3
  ) +
  expand_limits(y = max(sla_loop$fuera_sla_pct) * 1.15) +
  labs(
    title = "Porcentaje de OT fuera de SLA según existencia de loops",
    x = "",
    y = "% fuera de SLA"
  ) +
  theme_minimal()

ggsave(
  filename = file.path(dir_outputs, "graficos", "08_sla_loop_vs_no_loop.png"),
  plot = g_sla_loop,
  width = 8,
  height = 5
)

# ------- Ranking de tipos de loop --------------------------- ----

ranking_loops <- event_log %>%
  filter(es_loop == 1) %>%
  group_by(tipo_loop) %>%
  summarise(
    eventos_loop = n(),
    ot_afectadas = n_distinct(ot_id),
    duracion_total_horas = sum(duracion_horas_desde_evento_anterior, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  arrange(desc(duracion_total_horas))

g_ranking_loops <- ggplot(
  ranking_loops,
  aes(x = reorder(tipo_loop, duracion_total_horas), y = duracion_total_horas)
) +
  geom_col() +
  geom_text(
    aes(label = round(duracion_total_horas, 0)),
    hjust = -0.15,
    size = 3.5
  ) +
  coord_flip() +
  expand_limits(y = max(ranking_loops$duracion_total_horas) * 1.15) +
  labs(
    title = "Ranking de loops por impacto total en horas",
    x = "Tipo de loop",
    y = "Horas acumuladas"
  ) +
  theme_minimal()

ggsave(
  filename = file.path(dir_outputs, "graficos", "09_ranking_loops_horas.png"),
  plot = g_ranking_loops,
  width = 9,
  height = 5
)

# ------- Actividades críticas por P95 ----------------------- ----

actividades_p95 <- event_log %>%
  group_by(actividad) %>%
  summarise(
    eventos = n(),
    p95_horas = quantile(duracion_horas_desde_evento_anterior, 0.95, na.rm = TRUE),
    mediana_horas = median(duracion_horas_desde_evento_anterior, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  arrange(desc(p95_horas)) %>%
  slice_head(n = 10)

g_p95 <- ggplot(
  actividades_p95,
  aes(x = reorder(actividad, p95_horas), y = p95_horas)
) +
  geom_col() +
  geom_text(
    aes(label = round(p95_horas, 1)),
    hjust = -0.15,
    size = 3.5
  ) +
  coord_flip() +
  expand_limits(y = max(actividades_p95$p95_horas) * 1.15) +
  labs(
    title = "Top actividades críticas por p95 de duración",
    x = "Actividad",
    y = "p95 duración (horas)"
  ) +
  theme_minimal()

ggsave(
  filename = file.path(dir_outputs, "graficos", "10_actividades_p95.png"),
  plot = g_p95,
  width = 9,
  height = 5
)

# ------- Pareto de tiempo por actividad --------------------- ----

pareto_actividad <- event_log %>%
  group_by(actividad) %>%
  summarise(
    duracion_total_horas = sum(duracion_horas_desde_evento_anterior, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  arrange(desc(duracion_total_horas)) %>%
  mutate(
    porcentaje = duracion_total_horas / sum(duracion_total_horas),
    porcentaje_acumulado = cumsum(porcentaje)
  )

g_pareto <- ggplot(
  pareto_actividad,
  aes(x = reorder(actividad, -duracion_total_horas))
) +
  geom_col(aes(y = duracion_total_horas)) +
  geom_line(
    aes(y = porcentaje_acumulado * max(duracion_total_horas), group = 1),
    linewidth = 1
  ) +
  geom_point(
    aes(y = porcentaje_acumulado * max(duracion_total_horas)),
    size = 2
  ) +
  geom_text(
    aes(
      y = porcentaje_acumulado * max(duracion_total_horas),
      label = percent(porcentaje_acumulado, accuracy = 1)
    ),
    vjust = -0.7,
    size = 2.8
  ) +
  scale_y_continuous(
    name = "Horas acumuladas",
    sec.axis = sec_axis(
      ~ . / max(pareto_actividad$duracion_total_horas),
      labels = percent,
      name = "% acumulado"
    )
  ) +
  labs(
    title = "Pareto de tiempo acumulado por actividad",
    x = "Actividad"
  ) +
  theme_minimal() +
  theme(
    axis.text.x = element_text(angle = 45, hjust = 1)
  )

ggsave(
  filename = file.path(dir_outputs, "graficos", "11_pareto_actividad.png"),
  plot = g_pareto,
  width = 11,
  height = 5
)

# ------- Dashboard ejecutivo simple ------------------------- ----

kpis <- data.frame(
  metrica = c(
    "OT analizadas",
    "Eventos registrados",
    "% OT con loops",
    "% OT fuera SLA",
    "Lead time promedio",
    "Lead time mediano"
  ),
  valor = c(
    n_distinct(event_log$ot_id),
    nrow(event_log),
    paste0(round(mean(ot_base$tuvo_loop) * 100, 1), "%"),
    paste0(round(mean(ot_base$fuera_sla) * 100, 1), "%"),
    paste0(round(mean(ot_base$lead_time_horas), 1), " hs"),
    paste0(round(median(ot_base$lead_time_horas), 1), " hs")
  )
)

write_csv(
  kpis,
  file.path(dir_outputs, "tablas", "kpis_dashboard.csv")
)


cat("Visualizaciones generadas correctamente.\n")
cat("Sankey:", file.path(dir_outputs, "html", "01_sankey_flujo_proceso.html"), "\n")
cat("Graficos:", file.path(dir_outputs, "graficos"), "\n")
cat("KPIs:", file.path(dir_outputs, "tablas", "kpis_dashboard.csv"), "\n")