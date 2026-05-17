# ------- ANALISIS DE PROCESO - ORDENES DE TRABAJO ---- ----

suppressPackageStartupMessages({
  library(dplyr)
  library(tidyr)
  library(lubridate)
  library(stringr)
  library(readr)
  library(ggplot2)
  library(openxlsx)
})

# ------- Parámetros ---------------------------------- ----

dir_datos   <- "datos"
dir_outputs <- "outputs"

dir.create(dir_outputs, showWarnings = FALSE)
dir.create(file.path(dir_outputs, "tablas"), showWarnings = FALSE)
dir.create(file.path(dir_outputs, "graficos"), showWarnings = FALSE)

archivo_event_log <- file.path(dir_datos, "event_log_simulado.csv")
archivo_ot_base   <- file.path(dir_datos, "ot_base_simulada.csv")
archivo_usuarios  <- file.path(dir_datos, "usuarios_simulados.csv")

# ------- Carga de datos ------------------------------ ----

event_log <- read_csv(archivo_event_log, locale = locale(encoding = "UTF-8"), show_col_types = FALSE)
ot_base   <- read_csv(archivo_ot_base, locale = locale(encoding = "UTF-8"), show_col_types = FALSE)
usuarios  <- read_csv(archivo_usuarios, show_col_types = FALSE)

event_log <- event_log %>%
  mutate(
    timestamp = ymd_hms(timestamp),
    fecha_evento = as.Date(fecha_evento),
    es_loop = as.integer(es_loop)
  )

ot_base <- ot_base %>%
  mutate(
    fecha_creacion = ymd_hms(fecha_creacion),
    fecha_cierre = ymd_hms(fecha_cierre),
    tuvo_loop = as.integer(tuvo_loop),
    fuera_sla = as.integer(fuera_sla)
  )

# ------- Validación general del proceso -------------- ----

validacion_general <- data.frame(
  metrica = c(
    "Cantidad de OT",
    "Cantidad de eventos",
    "Eventos promedio por OT",
    "OT con loops",
    "% OT con loops",
    "% OT fuera SLA",
    "Lead time promedio horas",
    "Lead time mediano horas"
  ),
  valor = c(
    n_distinct(event_log$ot_id),
    nrow(event_log),
    round(nrow(event_log) / n_distinct(event_log$ot_id), 2),
    sum(ot_base$tuvo_loop),
    round(mean(ot_base$tuvo_loop) * 100, 2),
    round(mean(ot_base$fuera_sla) * 100, 2),
    round(mean(ot_base$lead_time_horas), 2),
    round(median(ot_base$lead_time_horas), 2)
  )
)

conteo_actividades <- event_log %>%
  count(actividad, sort = TRUE, name = "cantidad_eventos") %>%
  mutate(
    porcentaje_eventos = round(cantidad_eventos / sum(cantidad_eventos) * 100, 2)
  )

# ------- Variantes del proceso ----------------------- ----

variantes_proceso <- event_log %>%
  arrange(ot_id, orden_evento) %>%
  group_by(ot_id) %>%
  summarise(
    secuencia = paste(actividad, collapse = " -> "),
    cantidad_eventos = n(),
    cantidad_loops = sum(es_loop, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  count(secuencia, cantidad_eventos, cantidad_loops, sort = TRUE, name = "cantidad_ot") %>%
  mutate(
    porcentaje_ot = round(cantidad_ot / sum(cantidad_ot) * 100, 2)
  )

top_variantes <- variantes_proceso %>%
  slice_head(n = 10)

# ------- Lead time ----------------------------------- ----

lead_time_resumen <- ot_base %>%
  summarise(
    cantidad_ot = n(),
    promedio = round(mean(lead_time_horas), 2),
    mediana = round(median(lead_time_horas), 2),
    p25 = round(quantile(lead_time_horas, 0.25), 2),
    p75 = round(quantile(lead_time_horas, 0.75), 2),
    p90 = round(quantile(lead_time_horas, 0.90), 2),
    p95 = round(quantile(lead_time_horas, 0.95), 2),
    maximo = round(max(lead_time_horas), 2)
  )

lead_time_por_tipo <- ot_base %>%
  group_by(tipo_ot) %>%
  summarise(
    cantidad_ot = n(),
    lead_time_promedio = round(mean(lead_time_horas), 2),
    lead_time_mediano = round(median(lead_time_horas), 2),
    p95 = round(quantile(lead_time_horas, 0.95), 2),
    fuera_sla_pct = round(mean(fuera_sla) * 100, 2),
    .groups = "drop"
  ) %>%
  arrange(desc(lead_time_promedio))

lead_time_por_prioridad <- ot_base %>%
  group_by(prioridad) %>%
  summarise(
    cantidad_ot = n(),
    lead_time_promedio = round(mean(lead_time_horas), 2),
    lead_time_mediano = round(median(lead_time_horas), 2),
    p95 = round(quantile(lead_time_horas, 0.95), 2),
    fuera_sla_pct = round(mean(fuera_sla) * 100, 2),
    .groups = "drop"
  ) %>%
  arrange(desc(lead_time_promedio))

# ------- Impacto de loops ---------------------------- ----

impacto_loops_cantidad <- ot_base %>%
  mutate(
    bucket_loops = case_when(
      cantidad_loops == 0 ~ "0 loops",
      cantidad_loops == 1 ~ "1 loop",
      cantidad_loops == 2 ~ "2 loops",
      cantidad_loops >= 3 ~ "3+ loops",
      TRUE ~ "Sin dato"
    ),
    bucket_loops = factor(bucket_loops, levels = c("0 loops", "1 loop", "2 loops", "3+ loops"))
  ) %>%
  group_by(bucket_loops) %>%
  summarise(
    cantidad_ot = n(),
    porcentaje_ot = round(n() / nrow(ot_base) * 100, 2),
    lead_time_promedio = round(mean(lead_time_horas), 2),
    lead_time_mediano = round(median(lead_time_horas), 2),
    p95 = round(quantile(lead_time_horas, 0.95), 2),
    fuera_sla_pct = round(mean(fuera_sla) * 100, 2),
    .groups = "drop"
  )

impacto_loop_vs_no_loop <- ot_base %>%
  group_by(tuvo_loop) %>%
  summarise(
    cantidad_ot = n(),
    porcentaje_ot = round(n() / nrow(ot_base) * 100, 2),
    lead_time_promedio = round(mean(lead_time_horas), 2),
    lead_time_mediano = round(median(lead_time_horas), 2),
    fuera_sla_pct = round(mean(fuera_sla) * 100, 2),
    .groups = "drop"
  ) %>%
  mutate(
    grupo = if_else(tuvo_loop == 1, "Con loop", "Sin loop")
  ) %>%
  select(grupo, everything(), -tuvo_loop)

impacto_por_tipo_loop <- event_log %>%
  filter(es_loop == 1) %>%
  group_by(tipo_loop) %>%
  summarise(
    eventos_loop = n(),
    ot_afectadas = n_distinct(ot_id),
    duracion_total_horas = round(sum(duracion_horas_desde_evento_anterior, na.rm = TRUE), 2),
    duracion_promedio_horas = round(mean(duracion_horas_desde_evento_anterior, na.rm = TRUE), 2),
    duracion_mediana_horas = round(median(duracion_horas_desde_evento_anterior, na.rm = TRUE), 2),
    .groups = "drop"
  ) %>%
  mutate(
    porcentaje_ot_afectadas = round(ot_afectadas / n_distinct(event_log$ot_id) * 100, 2)
  ) %>%
  arrange(desc(duracion_total_horas))

# ------- Cuellos de botella por actividad ------------ ----

cuellos_por_actividad <- event_log %>%
  group_by(actividad) %>%
  summarise(
    eventos = n(),
    ot_afectadas = n_distinct(ot_id),
    duracion_total_horas = round(sum(duracion_horas_desde_evento_anterior, na.rm = TRUE), 2),
    duracion_promedio_horas = round(mean(duracion_horas_desde_evento_anterior, na.rm = TRUE), 2),
    duracion_mediana_horas = round(median(duracion_horas_desde_evento_anterior, na.rm = TRUE), 2),
    p90 = round(quantile(duracion_horas_desde_evento_anterior, 0.90, na.rm = TRUE), 2),
    p95 = round(quantile(duracion_horas_desde_evento_anterior, 0.95, na.rm = TRUE), 2),
    .groups = "drop"
  ) %>%
  mutate(
    porcentaje_tiempo_total = round(
      duracion_total_horas / sum(duracion_total_horas) * 100,
      2
    )
  ) %>%
  arrange(desc(duracion_total_horas))

# ------- Análisis por área --------------------------- ----

analisis_por_area <- event_log %>%
  group_by(area) %>%
  summarise(
    eventos = n(),
    ot_afectadas = n_distinct(ot_id),
    duracion_total_horas = round(sum(duracion_horas_desde_evento_anterior, na.rm = TRUE), 2),
    duracion_promedio_horas = round(mean(duracion_horas_desde_evento_anterior, na.rm = TRUE), 2),
    duracion_mediana_horas = round(median(duracion_horas_desde_evento_anterior, na.rm = TRUE), 2),
    eventos_loop = sum(es_loop, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  mutate(
    porcentaje_tiempo_total = round(
      duracion_total_horas / sum(duracion_total_horas) * 100,
      2
    ),
    porcentaje_eventos_loop = round(eventos_loop / eventos * 100, 2)
  ) %>%
  arrange(desc(duracion_total_horas))

analisis_por_usuario <- event_log %>%
  group_by(usuario, area) %>%
  summarise(
    eventos = n(),
    ot_afectadas = n_distinct(ot_id),
    duracion_total_horas = round(sum(duracion_horas_desde_evento_anterior, na.rm = TRUE), 2),
    duracion_promedio_horas = round(mean(duracion_horas_desde_evento_anterior, na.rm = TRUE), 2),
    eventos_loop = sum(es_loop, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  arrange(desc(duracion_total_horas))

# ------- SLA ----------------------------------------- ----

sla_general <- ot_base %>%
  summarise(
    cantidad_ot = n(),
    ot_fuera_sla = sum(fuera_sla),
    fuera_sla_pct = round(mean(fuera_sla) * 100, 2),
    ot_dentro_sla = sum(fuera_sla == 0),
    dentro_sla_pct = round(mean(fuera_sla == 0) * 100, 2)
  )

sla_por_tipo <- ot_base %>%
  group_by(tipo_ot) %>%
  summarise(
    cantidad_ot = n(),
    fuera_sla_pct = round(mean(fuera_sla) * 100, 2),
    lead_time_promedio = round(mean(lead_time_horas), 2),
    .groups = "drop"
  ) %>%
  arrange(desc(fuera_sla_pct))

sla_por_prioridad <- ot_base %>%
  group_by(prioridad) %>%
  summarise(
    cantidad_ot = n(),
    fuera_sla_pct = round(mean(fuera_sla) * 100, 2),
    lead_time_promedio = round(mean(lead_time_horas), 2),
    sla_objetivo_horas = first(sla_objetivo_horas),
    .groups = "drop"
  ) %>%
  arrange(desc(fuera_sla_pct))

sla_loop_vs_no_loop <- ot_base %>%
  group_by(tuvo_loop) %>%
  summarise(
    cantidad_ot = n(),
    fuera_sla_pct = round(mean(fuera_sla) * 100, 2),
    lead_time_promedio = round(mean(lead_time_horas), 2),
    .groups = "drop"
  ) %>%
  mutate(
    grupo = if_else(tuvo_loop == 1, "Con loop", "Sin loop")
  ) %>%
  select(grupo, everything(), -tuvo_loop)

# ------- Flujo entre actividades --------------------- ----

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
    porcentaje_transiciones = round(
      cantidad_transiciones / sum(cantidad_transiciones) * 100,
      2
    )
  )

# ------- Exportación de tablas ----------------------- ----

wb <- createWorkbook()

addWorksheet(wb, "validacion_general")
writeData(wb, "validacion_general", validacion_general)

addWorksheet(wb, "conteo_actividades")
writeData(wb, "conteo_actividades", conteo_actividades)

addWorksheet(wb, "top_variantes")
writeData(wb, "top_variantes", top_variantes)

addWorksheet(wb, "lead_time_resumen")
writeData(wb, "lead_time_resumen", lead_time_resumen)

addWorksheet(wb, "lead_time_tipo")
writeData(wb, "lead_time_tipo", lead_time_por_tipo)

addWorksheet(wb, "lead_time_prioridad")
writeData(wb, "lead_time_prioridad", lead_time_por_prioridad)

addWorksheet(wb, "impacto_loops")
writeData(wb, "impacto_loops", impacto_loops_cantidad)

addWorksheet(wb, "loop_vs_no_loop")
writeData(wb, "loop_vs_no_loop", impacto_loop_vs_no_loop)

addWorksheet(wb, "tipo_loop")
writeData(wb, "tipo_loop", impacto_por_tipo_loop)

addWorksheet(wb, "cuellos_actividad")
writeData(wb, "cuellos_actividad", cuellos_por_actividad)

addWorksheet(wb, "analisis_area")
writeData(wb, "analisis_area", analisis_por_area)

addWorksheet(wb, "analisis_usuario")
writeData(wb, "analisis_usuario", analisis_por_usuario)

addWorksheet(wb, "sla_general")
writeData(wb, "sla_general", sla_general)

addWorksheet(wb, "sla_tipo")
writeData(wb, "sla_tipo", sla_por_tipo)

addWorksheet(wb, "sla_prioridad")
writeData(wb, "sla_prioridad", sla_por_prioridad)

addWorksheet(wb, "sla_loop")
writeData(wb, "sla_loop", sla_loop_vs_no_loop)

addWorksheet(wb, "flujo_transiciones")
writeData(wb, "flujo_transiciones", flujo_transiciones)

saveWorkbook(
  wb,
  file.path(dir_outputs, "tablas", "analisis_proceso_ot.xlsx"),
  overwrite = TRUE
)

# ------- Gráficos iniciales -------------------------- ----

g_lead_time <- ggplot(ot_base, aes(x = lead_time_horas)) +
  geom_histogram(bins = 40) +
  labs(
    title = "Distribución del lead time de las OT",
    x = "Lead time (horas)",
    y = "Cantidad de OT"
  ) +
  theme_minimal()

ggsave(
  filename = file.path(dir_outputs, "graficos", "01_distribucion_lead_time.png"),
  plot = g_lead_time,
  width = 9,
  height = 5
)

g_loops <- ggplot(impacto_loops_cantidad, aes(x = bucket_loops, y = lead_time_promedio)) +
  geom_col() +
  labs(
    title = "Lead time promedio según cantidad de loops",
    x = "Cantidad de loops",
    y = "Lead time promedio (horas)"
  ) +
  theme_minimal()

ggsave(
  filename = file.path(dir_outputs, "graficos", "02_lead_time_por_loops.png"),
  plot = g_loops,
  width = 8,
  height = 5
)

g_cuellos <- cuellos_por_actividad %>%
  slice_max(duracion_total_horas, n = 10) %>%
  ggplot(aes(x = reorder(actividad, duracion_total_horas), y = duracion_total_horas)) +
  geom_col() +
  coord_flip() +
  labs(
    title = "Top actividades por tiempo total acumulado",
    x = "Actividad",
    y = "Duración total acumulada (horas)"
  ) +
  theme_minimal()

ggsave(
  filename = file.path(dir_outputs, "graficos", "03_cuellos_por_actividad.png"),
  plot = g_cuellos,
  width = 9,
  height = 5
)

g_area <- ggplot(analisis_por_area, aes(x = reorder(area, duracion_total_horas), y = duracion_total_horas)) +
  geom_col() +
  coord_flip() +
  labs(
    title = "Tiempo total acumulado por área",
    x = "Área",
    y = "Duración total acumulada (horas)"
  ) +
  theme_minimal()

ggsave(
  filename = file.path(dir_outputs, "graficos", "04_tiempo_por_area.png"),
  plot = g_area,
  width = 9,
  height = 5
)

g_tipo_loop <- ggplot(
  impacto_por_tipo_loop,
  aes(x = reorder(tipo_loop, duracion_total_horas), y = duracion_total_horas)
) +
  geom_col() +
  coord_flip() +
  labs(
    title = "Impacto total por tipo de loop",
    x = "Tipo de loop",
    y = "Duración total acumulada (horas)"
  ) +
  theme_minimal()

ggsave(
  filename = file.path(dir_outputs, "graficos", "05_impacto_tipo_loop.png"),
  plot = g_tipo_loop,
  width = 9,
  height = 5
)



cat("Análisis de proceso finalizado.\n")
cat("Tablas exportadas en:", file.path(dir_outputs, "tablas", "analisis_proceso_ot.xlsx"), "\n")
cat("Gráficos exportados en:", file.path(dir_outputs, "graficos"), "\n")