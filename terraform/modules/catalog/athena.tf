locals {
  athena_output_location = "s3://${var.operations_bucket_id}/athena-results/"
}

resource "aws_athena_workgroup" "this" {
  name        = "${var.project_name}-${var.environment}-workgroup"
  description = "Athena v3 workgroup for ${var.project_name} (${var.environment}) Gold analytics and QuickSight"
  state       = "ENABLED"

  configuration {
    enforce_workgroup_configuration    = true
    publish_cloudwatch_metrics_enabled = true
    bytes_scanned_cutoff_per_query     = var.athena_bytes_scanned_cutoff

    engine_version {
      selected_engine_version = "Athena engine version 3"
    }

    result_configuration {
      output_location = local.athena_output_location

      encryption_configuration {
        encryption_option = "SSE_S3"
      }
    }
  }

  tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# Named Query 1: Create enriched view joining panel_distrital + contexto_territorial for QuickSight
resource "aws_athena_named_query" "create_vw_panel_enriquecido" {
  name        = "01_create_vw_panel_enriquecido"
  description = "Crea o actualiza la vista vw_panel_enriquecido para consumo directo en Amazon QuickSight"
  workgroup   = aws_athena_workgroup.this.id
  database    = aws_glue_catalog_database.gold.name

  query = <<-SQL
    CREATE OR REPLACE VIEW ${aws_glue_catalog_database.gold.name}.vw_panel_enriquecido AS
    SELECT
      p.ubigeo,
      p.departamento,
      p.provincia,
      p.distrito,
      p.superficie_km2,
      p.year,
      p.quarter,
      p.period_id,
      CONCAT(CAST(p.year AS VARCHAR), '-T', CAST(p.quarter AS VARCHAR)) AS periodo,
      p.vel_descarga_mbps,
      p.tests,
      p.teselas_observadas,
      p.observado,
      c.poblacion_2020,
      CASE
        WHEN p.superficie_km2 > 0 THEN c.poblacion_2020 / p.superficie_km2
        ELSE NULL
      END AS densidad_hab_km2,
      c.centros_en_reporte,
      c.centros_con_dato_4g,
      c.centros_con_4g_declarada,
      CASE
        WHEN c.centros_con_dato_4g > 0 THEN 100.0 * c.centros_con_4g_declarada / c.centros_con_dato_4g
        ELSE NULL
      END AS pct_cobertura_4g,
      (c.centros_en_reporte IS NULL) AS en_punto_ciego_osiptel,
      c.periodo_referencia,
      c.fecha_corte_fuente
    FROM ${aws_glue_catalog_database.gold.name}.panel_distrital p
    LEFT JOIN ${aws_glue_catalog_database.gold.name}.contexto_territorial c
      ON p.ubigeo = c.ubigeo;
  SQL
}

# Named Query 2: National quarterly validation & trend summary
resource "aws_athena_named_query" "kpi_resumen_trimestral" {
  name        = "02_kpi_resumen_trimestral"
  description = "Verifica volumen, cobertura de observacion y mediana nacional de descarga por trimestre"
  workgroup   = aws_athena_workgroup.this.id
  database    = aws_glue_catalog_database.gold.name

  query = <<-SQL
    SELECT
      year,
      quarter,
      COUNT(*) AS universo_distritos,
      COUNT(vel_descarga_mbps) AS distritos_observados,
      ROUND(100.0 * COUNT(vel_descarga_mbps) / COUNT(*), 2) AS pct_observados,
      ROUND(approx_percentile(vel_descarga_mbps, 0.5), 2) AS mediana_mbps,
      SUM(COALESCE(tests, 0)) AS total_pruebas
    FROM ${aws_glue_catalog_database.gold.name}.panel_distrital
    GROUP BY year, quarter
    ORDER BY year, quarter;
  SQL
}

# Named Query 3: Blind-spot and underserved districts summary for American Tower
resource "aws_athena_named_query" "kpi_punto_ciego_y_brecha" {
  name        = "03_kpi_punto_ciego_y_brecha"
  description = "Lista distritos prioritarios con alta poblacion y baja velocidad o sin reporte declarado en OSIPTEL (ultimo trimestre disponible)"
  workgroup   = aws_athena_workgroup.this.id
  database    = aws_glue_catalog_database.gold.name

  query = <<-SQL
    WITH ultimo_periodo AS (
      SELECT MAX(period_id) AS max_period_id
      FROM ${aws_glue_catalog_database.gold.name}.panel_distrital
    )
    SELECT
      p.ubigeo,
      p.departamento,
      p.provincia,
      p.distrito,
      ROUND(c.poblacion_2020, 0) AS poblacion_2020,
      ROUND(p.vel_descarga_mbps, 2) AS vel_descarga_mbps,
      p.tests,
      c.centros_con_dato_4g,
      c.centros_con_4g_declarada,
      (c.centros_en_reporte IS NULL) AS en_punto_ciego_osiptel
    FROM ${aws_glue_catalog_database.gold.name}.panel_distrital p
    JOIN ultimo_periodo u
      ON p.period_id = u.max_period_id
    LEFT JOIN ${aws_glue_catalog_database.gold.name}.contexto_territorial c
      ON p.ubigeo = c.ubigeo
    WHERE c.centros_en_reporte IS NULL
       OR p.vel_descarga_mbps < 20.0
    ORDER BY c.poblacion_2020 DESC
    LIMIT 50;
  SQL
}
