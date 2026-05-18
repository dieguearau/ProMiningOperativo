# ------- SIMULACION DE MEJORAS - ORDENES DE TRABAJO ------ ----

suppressPackageStartupMessages({
  library(dplyr)
  library(tidyr)
  library(lubridate)
  library(readr)
  library(ggplot2)
  library(scales)
  library(openxlsx)
})

# ------- Parametros -------------------------------------- ----

dir_datos   <- "datos"
dir_outputs <- "outputs"

dir.create(dir_outputs, showWarnings = FALSE)
dir.create(file.path(dir_outputs, "tablas"), showWarnings = FALSE)
dir.create(file.path(dir_outputs, "graficos"), showWarnings = FALSE)

archivo_event_log <- file.path(dir_datos, "event_log_simulado.csv")

# ------- Parametros de mejora ---------------------------- ----

reduccion_reagendamiento        <- 0.30
reduccion_falta_materiales      <- 0.40
reduccion_cierre_administrativo <- 0.35

reduccion_agenda                <- 0.20
reduccion_validacion_cierre     <- 0.25

# ------- Carga de datos ---------------------------------- ----

event_log <- read_csv(archivo_event_log, show_col_types = FALSE)

event_log <- event_log %>%
  mutate(
    timestamp = ymd_hms(timestamp),
    fecha_evento = as.Date(fecha_evento),
    es_loop = as.integer(es_loop)
  )

# ------- Escenario actual -------------------------------- ----

ot_actual <- event_log %>%
  group_by(
    ot_id,
    tipo_ot,
    prioridad,
    zona,
    canal_origen,
    sla_objetivo_horas,
    estado_final
  ) %>%
  summarise(
    lead_time_horas_actual = round(
      sum(duracion_horas_desde_evento_anterior, na.rm = TRUE),
      2
    ),
    cantidad_eventos_actual = n(),
    cantidad_loops_actual = sum(es_loop, na.rm = TRUE),
    tuvo_loop_actual = as.integer(cantidad_loops_actual > 0),
    fuera_sla_actual = as.integer(
      lead_time_horas_actual > first(sla_objetivo_horas)
    ),
    .groups = "drop"
  )

# ------- Escenario mejorado ------------------------------ ----

event_log_mejorado <- event_log %>%
  mutate(
    factor_mejora = case_when(
      tipo_loop == "Reagendamiento" ~ 1 - reduccion_reagendamiento,
      tipo_loop == "Falta de materiales" ~ 1 - reduccion_falta_materiales,
      tipo_loop == "Cierre administrativo observado" ~ 1 - reduccion_cierre_administrativo,
      actividad == "Agenda coordinada" & es_loop == 0 ~ 1 - reduccion_agenda,
      actividad == "Validacion de cierre" & es_loop == 0 ~ 1 - reduccion_validacion_cierre,
      TRUE ~ 1
    ),
    duracion_horas_mejorada = round(
      duracion_horas_desde_evento_anterior * factor_mejora,
      2
    ),
    horas_ahorradas = round(
      duracion_horas_desde_evento_anterior - duracion_horas_mejorada,
      2
    )
  )

ot_mejorada <- event_log_mejorado %>%
  group_by(
    ot_id,
    tipo_ot,
    prioridad,
    zona,
    canal_origen,
    sla_objetivo_horas,
    estado_final
  ) %>%
  summarise(
    lead_time_horas_mejorado = round(
      sum(duracion_horas_mejorada, na.rm = TRUE),
      2
    ),
    horas_ahorradas = round(
      sum(horas_ahorradas, na.rm = TRUE),
      2
    ),
    fuera_sla_mejorado = as.integer(
      lead_time_horas_mejorado > first(sla_objetivo_horas)
    ),
    .groups = "drop"
  )

comparativo_ot <- ot_actual %>%
  left_join(
    ot_mejorada,
    by = c(
      "ot_id",
      "tipo_ot",
      "prioridad",
      "zona",
      "canal_origen",
      "sla_objetivo_horas",
      "estado_final"
    )
  ) %>%
  mutate(
    reduccion_lead_time_pct = round(
      horas_ahorradas / lead_time_horas_actual * 100,
      2
    ),
    cambia_estado_sla = case_when(
      fuera_sla_actual == 1 & fuera_sla_mejorado == 0 ~ "Recupera SLA",
      fuera_sla_actual == 1 & fuera_sla_mejorado == 1 ~ "Sigue fuera SLA",
      fuera_sla_actual == 0 & fuera_sla_mejorado == 0 ~ "Sigue dentro SLA",
      fuera_sla_actual == 0 & fuera_sla_mejorado == 1 ~ "Empeora SLA",
      TRUE ~ "Sin dato"
    )
  )

# ------- KPIs comparativos ------------------------------- ----

kpis_comparativos <- data.frame(
  metrica = c(
    "OT analizadas",
    "Lead time promedio",
    "Lead time mediano",
    "P95 lead time",
    "% OT fuera SLA",
    "Horas totales consumidas",
    "Horas totales ahorradas",
    "% reduccion de horas",
    "OT fuera SLA",
    "OT recuperadas para SLA"
  ),
  actual = c(
    nrow(comparativo_ot),
    round(mean(comparativo_ot$lead_time_horas_actual), 2),
    round(median(comparativo_ot$lead_time_horas_actual), 2),
    round(quantile(comparativo_ot$lead_time_horas_actual, 0.95), 2),
    round(mean(comparativo_ot$fuera_sla_actual) * 100, 2),
    round(sum(comparativo_ot$lead_time_horas_actual), 2),
    0,
    0,
    sum(comparativo_ot$fuera_sla_actual),
    0
  ),
  mejorado = c(
    nrow(comparativo_ot),
    round(mean(comparativo_ot$lead_time_horas_mejorado), 2),
    round(median(comparativo_ot$lead_time_horas_mejorado), 2),
    round(quantile(comparativo_ot$lead_time_horas_mejorado, 0.95), 2),
    round(mean(comparativo_ot$fuera_sla_mejorado) * 100, 2),
    round(sum(comparativo_ot$lead_time_horas_mejorado), 2),
    round(sum(comparativo_ot$horas_ahorradas), 2),
    round(
      sum(comparativo_ot$horas_ahorradas) /
        sum(comparativo_ot$lead_time_horas_actual) * 100,
      2
    ),
    sum(comparativo_ot$fuera_sla_mejorado),
    sum(comparativo_ot$cambia_estado_sla == "Recupera SLA")
  )
)

# ------- Ahorro por tipo de loop ------------------------- ----

ahorro_por_tipo_loop <- event_log_mejorado %>%
  filter(es_loop == 1) %>%
  group_by(tipo_loop) %>%
  summarise(
    eventos_loop = n(),
    ot_afectadas = n_distinct(ot_id),
    horas_actuales = round(
      sum(duracion_horas_desde_evento_anterior, na.rm = TRUE),
      2
    ),
    horas_mejoradas = round(
      sum(duracion_horas_mejorada, na.rm = TRUE),
      2
    ),
    horas_ahorradas = round(
      sum(horas_ahorradas, na.rm = TRUE),
      2
    ),
    reduccion_pct = round(horas_ahorradas / horas_actuales * 100, 2),
    .groups = "drop"
  ) %>%
  arrange(desc(horas_ahorradas))

# ------- Ahorro por actividad ---------------------------- ----

ahorro_por_actividad <- event_log_mejorado %>%
  group_by(actividad) %>%
  summarise(
    eventos = n(),
    horas_actuales = round(
      sum(duracion_horas_desde_evento_anterior, na.rm = TRUE),
      2
    ),
    horas_mejoradas = round(
      sum(duracion_horas_mejorada, na.rm = TRUE),
      2
    ),
    horas_ahorradas = round(
      sum(horas_ahorradas, na.rm = TRUE),
      2
    ),
    reduccion_pct = if_else(
      horas_actuales > 0,
      round(horas_ahorradas / horas_actuales * 100, 2),
      0
    ),
    .groups = "drop"
  ) %>%
  arrange(desc(horas_ahorradas))

# ------- Comparativos por dimensiones -------------------- ----

comparativo_prioridad <- comparativo_ot %>%
  group_by(prioridad) %>%
  summarise(
    cantidad_ot = n(),
    lead_time_actual = round(mean(lead_time_horas_actual), 2),
    lead_time_mejorado = round(mean(lead_time_horas_mejorado), 2),
    ahorro_promedio = round(mean(horas_ahorradas), 2),
    fuera_sla_actual_pct = round(mean(fuera_sla_actual) * 100, 2),
    fuera_sla_mejorado_pct = round(mean(fuera_sla_mejorado) * 100, 2),
    ot_recuperadas_sla = sum(cambia_estado_sla == "Recupera SLA"),
    .groups = "drop"
  )

comparativo_tipo_ot <- comparativo_ot %>%
  group_by(tipo_ot) %>%
  summarise(
    cantidad_ot = n(),
    lead_time_actual = round(mean(lead_time_horas_actual), 2),
    lead_time_mejorado = round(mean(lead_time_horas_mejorado), 2),
    ahorro_promedio = round(mean(horas_ahorradas), 2),
    fuera_sla_actual_pct = round(mean(fuera_sla_actual) * 100, 2),
    fuera_sla_mejorado_pct = round(mean(fuera_sla_mejorado) * 100, 2),
    ot_recuperadas_sla = sum(cambia_estado_sla == "Recupera SLA"),
    .groups = "drop"
  )

comparativo_zona <- comparativo_ot %>%
  group_by(zona) %>%
  summarise(
    cantidad_ot = n(),
    lead_time_actual = round(mean(lead_time_horas_actual), 2),
    lead_time_mejorado = round(mean(lead_time_horas_mejorado), 2),
    ahorro_promedio = round(mean(horas_ahorradas), 2),
    fuera_sla_actual_pct = round(mean(fuera_sla_actual) * 100, 2),
    fuera_sla_mejorado_pct = round(mean(fuera_sla_mejorado) * 100, 2),
    ot_recuperadas_sla = sum(cambia_estado_sla == "Recupera SLA"),
    .groups = "drop"
  )

# ------- Exportacion Excel ------------------------------- ----

wb <- createWorkbook()

addWorksheet(wb, "kpis_comparativos")
writeData(wb, "kpis_comparativos", kpis_comparativos)

addWorksheet(wb, "comparativo_ot")
writeData(wb, "comparativo_ot", comparativo_ot)

addWorksheet(wb, "ahorro_tipo_loop")
writeData(wb, "ahorro_tipo_loop", ahorro_por_tipo_loop)

addWorksheet(wb, "ahorro_actividad")
writeData(wb, "ahorro_actividad", ahorro_por_actividad)

addWorksheet(wb, "comparativo_prioridad")
writeData(wb, "comparativo_prioridad", comparativo_prioridad)

addWorksheet(wb, "comparativo_tipo_ot")
writeData(wb, "comparativo_tipo_ot", comparativo_tipo_ot)

addWorksheet(wb, "comparativo_zona")
writeData(wb, "comparativo_zona", comparativo_zona)

saveWorkbook(
  wb,
  file.path(dir_outputs, "tablas", "simulacion_mejoras_ot.xlsx"),
  overwrite = TRUE
)

# ------- Graficos ---------------------------------------- ----

comparativo_long <- comparativo_ot %>%
  select(ot_id, lead_time_horas_actual, lead_time_horas_mejorado) %>%
  pivot_longer(
    cols = c(lead_time_horas_actual, lead_time_horas_mejorado),
    names_to = "escenario",
    values_to = "lead_time_horas"
  ) %>%
  mutate(
    escenario = case_when(
      escenario == "lead_time_horas_actual" ~ "Actual",
      escenario == "lead_time_horas_mejorado" ~ "Mejorado",
      TRUE ~ escenario
    )
  )

g_box_comparativo <- ggplot(
  comparativo_long,
  aes(x = escenario, y = lead_time_horas)
) +
  geom_boxplot(outlier.alpha = 0.3, fill = "#B3C9B7") +
  labs(
    title = "Comparación del lead time: escenario actual vs mejorado",
    x = "",
    y = "Lead time (horas)"
  ) +
  theme_minimal()

ggsave(
  filename = file.path(dir_outputs, "graficos", "12_boxplot_actual_vs_mejorado.png"),
  plot = g_box_comparativo,
  width = 8,
  height = 5
)

g_ahorro_loop <- ggplot(
  ahorro_por_tipo_loop,
  aes(x = reorder(tipo_loop, horas_ahorradas), y = horas_ahorradas)
) +
  geom_col(fill = "#B3C9B7") +
  geom_text(
    aes(label = round(horas_ahorradas, 0)),
    hjust = -0.15,
    size = 3.5
  ) +
  coord_flip() +
  expand_limits(y = max(ahorro_por_tipo_loop$horas_ahorradas) * 1.15) +
  labs(
    title = "Horas ahorradas por tipo de loop",
    x = "Tipo de loop",
    y = "Horas ahorradas"
  ) +
  theme_minimal()

ggsave(
  filename = file.path(dir_outputs, "graficos", "13_ahorro_por_tipo_loop.png"),
  plot = g_ahorro_loop,
  width = 9,
  height = 5
)

g_ahorro_actividad <- ahorro_por_actividad %>%
  filter(horas_ahorradas > 0) %>%
  ggplot(aes(x = reorder(actividad, horas_ahorradas), y = horas_ahorradas)) +
  geom_col(fill = "#B3C9B7") +
  geom_text(
    aes(label = round(horas_ahorradas, 0)),
    hjust = -0.15,
    size = 3.5
  ) +
  coord_flip() +
  expand_limits(y = max(ahorro_por_actividad$horas_ahorradas) * 1.15) +
  labs(
    title = "Horas ahorradas por actividad",
    x = "Actividad",
    y = "Horas ahorradas"
  ) +
  theme_minimal()

ggsave(
  filename = file.path(dir_outputs, "graficos", "14_ahorro_por_actividad.png"),
  plot = g_ahorro_actividad,
  width = 9,
  height = 5
)

sla_comparativo <- data.frame(
  escenario = c("Actual", "Mejorado"),
  fuera_sla_pct = c(
    mean(comparativo_ot$fuera_sla_actual) * 100,
    mean(comparativo_ot$fuera_sla_mejorado) * 100
  )
)

g_sla_comparativo <- ggplot(
  sla_comparativo,
  aes(x = escenario, y = fuera_sla_pct)
) +
  geom_col(fill = "#B3C9B7") +
  geom_text(
    aes(label = paste0(round(fuera_sla_pct, 1), "%")),
    vjust = -0.3,
    size = 4
  ) +
  expand_limits(y = max(sla_comparativo$fuera_sla_pct) * 1.15) +
  labs(
    title = "Comparación de OT fuera de SLA",
    x = "",
    y = "% fuera de SLA"
  ) +
  theme_minimal()

ggsave(
  filename = file.path(dir_outputs, "graficos", "15_sla_actual_vs_mejorado.png"),
  plot = g_sla_comparativo,
  width = 8,
  height = 5
)



cat("Simulacion de mejoras finalizada.\n")
cat("Excel:", file.path(dir_outputs, "tablas", "simulacion_mejoras_ot.xlsx"), "\n")
cat("Graficos:", file.path(dir_outputs, "graficos"), "\n")