
# ------- SIMULACIÓN EVENT LOG - ÓRDENES DE TRABAJO ------ ----

suppressPackageStartupMessages({
  library(dplyr)
  library(tidyr)
  library(lubridate)
  library(stringr)
  library(purrr)
  library(readr)
})

set.seed(123)

# ------- Parámetros               ----------------------- ----

n_wo <- 1000

fecha_inicio <- as.POSIXct("2026-01-01 08:00:00", tz = "America/Montevideo")
fecha_fin    <- as.POSIXct("2026-03-31 18:00:00", tz = "America/Montevideo")

dir.create("datos", showWarnings = FALSE)

tipos_wo <- c("Instalación", "Mantenimiento", "Reparación", "Inspección")
prioridades <- c("Baja", "Media", "Alta", "Crítica")
zonas <- c("Norte", "Sur", "Este", "Oeste", "Centro")
canales <- c("Call center", "Web", "Comercial", "Sistema")

# ------- Simulación de usuarios   ----------------------- ----

usuarios <- data.frame(
  usuario = paste0("USR_", str_pad(1:30, 2, pad = "0")),
  area = rep(
    c(
      "Atención al cliente",
      "Backoffice operativo",
      "Técnico de campo",
      "Logística / inventario",
      "Supervisión de trabajo"
    ),
    length.out = 30
  ),
  capacidad_diaria = sample(8:18, 30, replace = TRUE)
)

# ------- Flujo base               ----------------------- ----

flujo_base <- data.frame(
  orden = 1:9,
  actividad = c(
    "WO creada",
    "Validación inicial",
    "Clasificación de WO",
    "Asignación",
    "Agenda coordinada",
    "Trabajo iniciado",
    "Trabajo finalizado",
    "Validación de cierre",
    "WO cerrada"
  ),
  area = c(
    "Atención al cliente",
    "Backoffice operativo",
    "Backoffice operativo",
    "Backoffice operativo",
    "Backoffice operativo",
    "Técnico de campo",
    "Técnico de campo",
    "Supervisión de trabajo",
    "Backoffice operativo"
  ),
  duracion_media_horas = c(0, 2, 1, 4, 12, 2, 3, 6, 1)
)

# ------- Probabilidades de loop   ----------------------- ----

prob_loop_tipo <- c(
  "Instalación" = 0.20,
  "Mantenimiento" = 0.30,
  "Reparación" = 0.45,
  "Inspección" = 0.15
)

prob_extra_prioridad <- c(
  "Baja" = 0.00,
  "Media" = 0.05,
  "Alta" = 0.10,
  "Crítica" = 0.15
)

loops_def <- data.frame(
  tipo_loop = c(
    "Información incompleta",
    "Reagendamiento",
    "Falta de materiales",
    "Ejecución fallida",
    "Cierre administrativo observado"
  ),
  prob = c(0.25, 0.25, 0.20, 0.15, 0.15),
  penalizacion_media_horas = c(8, 24, 36, 18, 12)
)

# ------- Funciones auxiliares     ----------------------- ----


sample_usuario_area <- function(area_obj) {
  usuarios %>%
    filter(area == area_obj) %>%
    pull(usuario) %>%
    sample(1)
}

generar_duracion <- function(media_horas) {
  if (media_horas == 0) return(0)
  round(rgamma(1, shape = 2, scale = media_horas / 2), 2)
}

generar_fecha_inicial <- function() {
  as.POSIXct(
    runif(1, as.numeric(fecha_inicio), as.numeric(fecha_fin)),
    origin = "1970-01-01",
    tz = "America/Montevideo"
  )
}

generar_loop_eventos <- function(tipo_loop, timestamp_actual) {
  
  loop_info <- loops_def %>% filter(tipo_loop == !!tipo_loop)
  penalizacion <- generar_duracion(loop_info$penalizacion_media_horas)
  
  if (tipo_loop == "Información incompleta") {
    actividades <- data.frame(
      actividad = c("Solicitud de información adicional", "Validación inicial"),
      area = c("Atención al cliente", "Backoffice operativo")
    )
  }
  
  if (tipo_loop == "Reagendamiento") {
    actividades <- tibble(
      actividad = c("Contacto con cliente para reagendar", "Agenda coordinada"),
      area = c("Atención al cliente", "Backoffice operativo")
    )
  }
  
  if (tipo_loop == "Falta de materiales") {
    actividades <- tibble(
      actividad = c("Solicitud de material", "Material preparado", "Agenda coordinada", "Trabajo iniciado"),
      area = c(
        "Técnico de campo",
        "Logística / inventario",
        "Backoffice operativo",
        "Técnico de campo"
      )
    )
  }
  
  if (tipo_loop == "Ejecución fallida") {
    actividades <- tibble(
      actividad = c("Trabajo iniciado", "Trabajo finalizado"),
      area = c("Técnico de campo", "Técnico de campo")
    )
  }
  
  if (tipo_loop == "Cierre administrativo observado") {
    actividades <- tibble(
      actividad = c("Corrección de cierre", "Validación de cierre"),
      area = c("Backoffice operativo", "Supervisión de trabajo")
    )
  }
  
  n <- nrow(actividades)
  duraciones <- rep(penalizacion / n, n)
  
  actividades %>%
    mutate(
      duracion_horas_desde_evento_anterior = round(duraciones, 2),
      timestamp = timestamp_actual + dhours(cumsum(duraciones)),
      es_loop = 1,
      tipo_loop = tipo_loop
    )
}

generar_ot <- function(i) {
  
  ot_id <- paste0("OT_", str_pad(i, 5, pad = "0"))
  
  tipo_ot <- sample(tipos_wo, 1, prob = c(0.25, 0.25, 0.35, 0.15))
  prioridad <- sample(prioridades, 1, prob = c(0.25, 0.45, 0.22, 0.08))
  zona <- sample(zonas, 1)
  canal_origen <- sample(canales, 1, prob = c(0.45, 0.25, 0.15, 0.15))
  
  timestamp_actual <- generar_fecha_inicial()
  
  prob_loop <- min(
    prob_loop_tipo[[tipo_ot]] + prob_extra_prioridad[[prioridad]],
    0.85
  )
  
  n_loops <- sample(
    0:4,
    1,
    prob = c(
      1 - prob_loop,
      prob_loop * 0.55,
      prob_loop * 0.25,
      prob_loop * 0.15,
      prob_loop * 0.05
    )
  )
  
  loops_wo <- if (n_loops > 0) {
    sample(loops_def$tipo_loop, n_loops, replace = TRUE, prob = loops_def$prob)
  } else {
    character(0)
  }
  
  eventos <- list()
  
  for (j in seq_len(nrow(flujo_base))) {
    
    act <- flujo_base[j, ]
    
    dur <- generar_duracion(act$duracion_media_horas)
    timestamp_actual <- timestamp_actual + dhours(dur)
    
    evento_base <- data.frame(
      ot_id = ot_id,
      timestamp = timestamp_actual,
      actividad = act$actividad,
      area = act$area,
      usuario = sample_usuario_area(act$area),
      tipo_ot = tipo_ot,
      prioridad = prioridad,
      zona = zona,
      canal_origen = canal_origen,
      es_loop = 0,
      tipo_loop = NA_character_,
      duracion_horas_desde_evento_anterior = dur
    )
    
    eventos <- append(eventos, list(evento_base))
    
    # Inserción probabilística de loops en puntos lógicos del proceso
    loops_pendientes <- loops_wo
    
    if (length(loops_pendientes) > 0) {
      
      loop_a_insertar <- NULL
      
      if (act$actividad == "Validación inicial" &&
          "Información incompleta" %in% loops_pendientes) {
        loop_a_insertar <- "Información incompleta"
      }
      
      if (act$actividad == "Agenda coordinada" &&
          "Reagendamiento" %in% loops_pendientes) {
        loop_a_insertar <- "Reagendamiento"
      }
      
      if (act$actividad == "Trabajo iniciado" &&
          "Falta de materiales" %in% loops_pendientes) {
        loop_a_insertar <- "Falta de materiales"
      }
      
      if (act$actividad == "Trabajo finalizado" &&
          "Ejecución fallida" %in% loops_pendientes) {
        loop_a_insertar <- "Ejecución fallida"
      }
      
      if (act$actividad == "Validación de cierre" &&
          "Cierre administrativo observado" %in% loops_pendientes) {
        loop_a_insertar <- "Cierre administrativo observado"
      }
      
      if (!is.null(loop_a_insertar)) {
        
        loop_eventos <- generar_loop_eventos(loop_a_insertar, timestamp_actual) %>%
          mutate(
            ot_id = ot_id,
            usuario = map_chr(area, sample_usuario_area),
            tipo_ot = tipo_ot,
            prioridad = prioridad,
            zona = zona,
            canal_origen = canal_origen
          )
        
        timestamp_actual <- max(loop_eventos$timestamp)
        eventos <- append(eventos, list(loop_eventos))
        
        loops_wo <- loops_wo[-match(loop_a_insertar, loops_wo)]
      }
    }
  }
  
  bind_rows(eventos) %>%
    arrange(timestamp) %>%
    mutate(
      event_id = paste0(ot_id, "_EV_", str_pad(row_number(), 3, pad = "0")),
      estado_final = "Cerrada",
      sla_objetivo_horas = case_when(
        prioridad == "Crítica" ~ 24,
        prioridad == "Alta" ~ 48,
        prioridad == "Media" ~ 96,
        prioridad == "Baja" ~ 168,
        TRUE ~ 96
      )
    ) %>%
    select(
      ot_id,
      event_id,
      timestamp,
      actividad,
      area,
      usuario,
      tipo_ot,
      prioridad,
      zona,
      canal_origen,
      es_loop,
      tipo_loop,
      duracion_horas_desde_evento_anterior,
      sla_objetivo_horas,
      estado_final
    )
}


# ------- Generación del event log ----------------------- ----


event_log <- map_dfr(1:n_wo, generar_ot) %>%
  group_by(ot_id) %>%
  arrange(timestamp, .by_group = TRUE) %>%
  mutate(
    orden_evento = row_number(),
    fecha_evento = as.Date(timestamp),
    dia_semana = recode(
      wday(timestamp, label = TRUE, abbr = FALSE, week_start = 1) %>% as.character(),
      "Monday" = "Lunes",
      "Tuesday" = "Martes",
      "Wednesday" = "Miércoles",
      "Thursday" = "Jueves",
      "Friday" = "Viernes",
      "Saturday" = "Sábado",
      "Sunday" = "Domingo"
    ),
    hora_evento = hour(timestamp)
  ) %>%
  ungroup()


# ------- Tabla resumen por WO     ----------------------- ----


ot_base <- event_log %>%
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
    fecha_creacion = min(timestamp),
    fecha_cierre = max(timestamp),
    lead_time_horas = round(as.numeric(difftime(max(timestamp), min(timestamp), units = "hours")), 2),
    cantidad_eventos = n(),
    cantidad_loops = sum(es_loop, na.rm = TRUE),
    tuvo_loop = as.integer(cantidad_loops > 0),
    fuera_sla = as.integer(lead_time_horas > first(sla_objetivo_horas)),
    .groups = "drop"
  )
 
# ------- Exportación              ----------------------- ----


write_csv(event_log, "datos/event_log_simulado.csv")
write_csv(usuarios, "datos/usuarios_simulados.csv")
write_csv(ot_base, "datos/ot_base_simulada.csv")


# ------- Validaciones rápidas     ----------------------- ----


cat("Event log generado:\n")
cat("Filas:", nrow(event_log), "\n")
cat("WO únicas:", n_distinct(event_log$ot_id), "\n")
cat("WO con loops:", sum(ot_base$tuvo_loop), "\n")
cat("% WO con loops:", round(mean(ot_base$tuvo_loop) * 100, 1), "%\n")
cat("% fuera SLA:", round(mean(ot_base$fuera_sla) * 100, 1), "%\n")
cat("Lead time promedio:", round(mean(ot_base$lead_time_horas), 1), "horas\n")