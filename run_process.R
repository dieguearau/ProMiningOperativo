
# ============================================================
# PIPELINE PRINCIPAL - PROCESS MINING OPERACIONAL
# ============================================================

cat(" =============================================\n",
    "INICIO DEL PIPELINE\n",
    "=============================================\n\n")

inicio_pipeline <- Sys.time()

# ------------------------------------------------------------
# Configuración
# ------------------------------------------------------------

options(
  scipen = 999,
  stringsAsFactors = FALSE
)

# ------------------------------------------------------------
# Función auxiliar para ejecutar scripts
# ------------------------------------------------------------

ejecutar_script <- function(script_path) {
  
cat(" ---------------------------------------------\n",
    "Ejecutando:", script_path, "\n",
    "---------------------------------------------\n")
  
  inicio <- Sys.time()
  
  source(script_path, echo = FALSE)
  
  fin <- Sys.time()
  
  cat("Finalizado:", script_path, "\n")
  cat(
    "Duración:",
    round(as.numeric(difftime(fin, inicio, units = "secs")), 2),
    "segundos\n\n"
  )
}

# ------------------------------------------------------------
# Scripts del pipeline
# ------------------------------------------------------------

scripts_pipeline <- c(
  "scripts/eventlogs_simulacion.R",
  "scripts/eventlogs_analisis.R",
  "scripts/eventlogs_visualizacion.R",
  "scripts/eventlogs_simulacion_optimizacion.R"
)

# ------------------------------------------------------------
# Ejecución de scripts
# ------------------------------------------------------------

for (script_actual in scripts_pipeline) {
  
  if (file.exists(script_actual)) {
    
    ejecutar_script(script_actual)
    
  } else {
    
    stop(
      paste(
        "No se encontró el script:",
        script_actual
      )
    )
  }
}

# ------------------------------------------------------------
# Render reporte Quarto
# ------------------------------------------------------------

cat(" ---------------------------------------------\n",
    "Renderizando reporte Quarto\n",
    "---------------------------------------------\n")

quarto::quarto_render(
  input = "docs/index.qmd",
  execute_dir = getwd()
)

# ------------------------------------------------------------
# Fin pipeline
# ------------------------------------------------------------

fin_pipeline <- Sys.time()

cat(" =============================================\n",
    "PIPELINE FINALIZADO CORRECTAMENTE\n",
    "=============================================\n")

cat(
  "Duración total:",
  round(
    as.numeric(
      difftime(fin_pipeline, inicio_pipeline, units = "secs")
    ),
    2
  ),
  "segundos\n"
)

cat("\nReporte generado en:\n")
cat("docs/index.html\n")

