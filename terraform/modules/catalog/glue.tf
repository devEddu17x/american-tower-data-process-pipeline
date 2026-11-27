locals {
  glue_database_name = "${replace(var.project_name, "-", "_")}_${var.environment}_gold"
  gold_run_prefix    = "s3://${var.gold_bucket_id}/run_id=${var.gold_run_id}"
}

resource "aws_glue_catalog_database" "gold" {
  name        = local.glue_database_name
  description = "Gold analytical tables for ${var.project_name} (${var.environment})"
}

# Gold Table 1: panel_distrital (district x quarter, partitioned by year with Athena Partition Projection)
resource "aws_glue_catalog_table" "panel_distrital" {
  name          = "panel_distrital"
  database_name = aws_glue_catalog_database.gold.name
  table_type    = "EXTERNAL_TABLE"
  description   = "Panel distrito-trimestre (1,890 distritos x trimestres Ookla) con velocidad ponderada por pruebas"

  parameters = {
    "EXTERNAL"                  = "TRUE"
    "classification"            = "parquet"
    "parquet.compression"       = "SNAPPY"
    "projection.enabled"        = "true"
    "projection.year.type"      = "integer"
    "projection.year.range"     = "2019,2030"
    "storage.location.template" = "${local.gold_run_prefix}/panel_distrital/year=$${year}/"
  }

  partition_keys {
    name = "year"
    type = "int"
  }

  storage_descriptor {
    location      = "${local.gold_run_prefix}/panel_distrital/"
    input_format  = "org.apache.hadoop.hive.ql.io.parquet.MapredParquetInputFormat"
    output_format = "org.apache.hadoop.hive.ql.io.parquet.MapredParquetOutputFormat"

    ser_de_info {
      name                  = "parquet"
      serialization_library = "org.apache.hadoop.hive.ql.io.parquet.serde.ParquetHiveSerDe"
      parameters = {
        "serialization.format" = "1"
      }
    }

    columns {
      name = "ubigeo"
      type = "string"
    }
    columns {
      name = "period_id"
      type = "int"
    }
    columns {
      name = "departamento"
      type = "string"
    }
    columns {
      name = "provincia"
      type = "string"
    }
    columns {
      name = "distrito"
      type = "string"
    }
    columns {
      name = "superficie_km2"
      type = "double"
    }
    columns {
      name = "vel_descarga_mbps"
      type = "double"
    }
    columns {
      name = "tests"
      type = "bigint"
    }
    columns {
      name = "teselas_observadas"
      type = "bigint"
    }
    columns {
      name = "quarter"
      type = "int"
    }
    columns {
      name = "observado"
      type = "boolean"
    }
  }
}

# Gold Table 2: contexto_territorial (1 row per district: INEI + WorldPop 2020 + OSIPTEL 4G)
resource "aws_glue_catalog_table" "contexto_territorial" {
  name          = "contexto_territorial"
  database_name = aws_glue_catalog_database.gold.name
  table_type    = "EXTERNAL_TABLE"
  description   = "Contexto territorial por distrito (1,890 filas): INEI, poblacion WorldPop 2020 y cobertura 4G OSIPTEL"

  parameters = {
    "EXTERNAL"            = "TRUE"
    "classification"      = "parquet"
    "parquet.compression" = "SNAPPY"
  }

  storage_descriptor {
    location      = "${local.gold_run_prefix}/contexto_territorial/"
    input_format  = "org.apache.hadoop.hive.ql.io.parquet.MapredParquetInputFormat"
    output_format = "org.apache.hadoop.hive.ql.io.parquet.MapredParquetOutputFormat"

    ser_de_info {
      name                  = "parquet"
      serialization_library = "org.apache.hadoop.hive.ql.io.parquet.serde.ParquetHiveSerDe"
      parameters = {
        "serialization.format" = "1"
      }
    }

    columns {
      name = "ubigeo"
      type = "string"
    }
    columns {
      name = "departamento"
      type = "string"
    }
    columns {
      name = "provincia"
      type = "string"
    }
    columns {
      name = "distrito"
      type = "string"
    }
    columns {
      name = "superficie_km2"
      type = "double"
    }
    columns {
      name = "poblacion_2020"
      type = "double"
    }
    columns {
      name = "pixeles_validos"
      type = "bigint"
    }
    columns {
      name = "centros_en_reporte"
      type = "bigint"
    }
    columns {
      name = "centros_con_dato_4g"
      type = "bigint"
    }
    columns {
      name = "centros_con_4g_declarada"
      type = "bigint"
    }
    columns {
      name = "periodo_referencia"
      type = "string"
    }
    columns {
      name = "fecha_corte_fuente"
      type = "date"
    }
  }
}

# Gold Table 3: predicciones_modelos (fixed prefix in Gold for all 4 team models, append-only Parquet)
resource "aws_glue_catalog_table" "predicciones_modelos" {
  name          = "predicciones_modelos"
  database_name = aws_glue_catalog_database.gold.name
  table_type    = "EXTERNAL_TABLE"
  description   = "Predicciones e indice de prioridad territorial generados por los 4 modelos del equipo"

  parameters = {
    "EXTERNAL"            = "TRUE"
    "classification"      = "parquet"
    "parquet.compression" = "SNAPPY"
  }

  storage_descriptor {
    location      = "s3://${var.gold_bucket_id}/predicciones_modelos/"
    input_format  = "org.apache.hadoop.hive.ql.io.parquet.MapredParquetInputFormat"
    output_format = "org.apache.hadoop.hive.ql.io.parquet.MapredParquetOutputFormat"

    ser_de_info {
      name                  = "parquet"
      serialization_library = "org.apache.hadoop.hive.ql.io.parquet.serde.ParquetHiveSerDe"
      parameters = {
        "serialization.format" = "1"
      }
    }

    columns {
      name = "inference_id"
      type = "string"
    }
    columns {
      name = "inference_timestamp"
      type = "timestamp"
    }
    columns {
      name = "modelo"
      type = "string"
    }
    columns {
      name = "autor"
      type = "string"
    }
    columns {
      name = "ubigeo"
      type = "string"
    }
    columns {
      name = "year_objetivo"
      type = "int"
    }
    columns {
      name = "quarter_objetivo"
      type = "int"
    }
    columns {
      name = "vel_origen_mbps"
      type = "double"
    }
    columns {
      name = "pred_descarga_mbps"
      type = "double"
    }
    columns {
      name = "indice_prioridad"
      type = "double"
    }
  }
}

# On-demand Glue Crawler (no schedule = $0 idle cost) for discovering future Gold tables (e.g. predicciones)
resource "aws_glue_crawler" "gold" {
  name          = "${var.project_name}-${var.environment}-gold-crawler"
  role          = aws_iam_role.glue_crawler_role.arn
  database_name = aws_glue_catalog_database.gold.name
  table_prefix  = "crawled_"
  description   = "On-demand crawler over Gold bucket run prefix to discover additional tables without overwriting managed definitions"

  s3_target {
    path = "${local.gold_run_prefix}/"
  }

  schema_change_policy {
    delete_behavior = "LOG"
    update_behavior = "UPDATE_IN_DATABASE"
  }

  tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}
