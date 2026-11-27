data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

locals {
  quicksight_user_name = coalesce(var.quicksight_user_name, data.aws_caller_identity.current.account_id)
  quicksight_user_arn  = "arn:aws:quicksight:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:user/${var.quicksight_namespace}/${local.quicksight_user_name}"
}

# Grant QuickSight service role least-privilege access to Athena, Glue Gold DB, Gold S3, and Athena results in Operations S3
data "aws_iam_policy_document" "quicksight_athena_s3" {
  count = var.enable_quicksight ? 1 : 0

  statement {
    sid    = "ReadGoldParquet"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:ListBucket",
      "s3:GetBucketLocation"
    ]
    resources = [
      var.gold_bucket_arn,
      "${var.gold_bucket_arn}/*"
    ]
  }

  statement {
    sid    = "AthenaResultsBucket"
    effect = "Allow"
    actions = [
      "s3:ListBucket",
      "s3:GetBucketLocation"
    ]
    resources = [var.operations_bucket_arn]
  }

  statement {
    sid    = "AthenaResultsObjects"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:AbortMultipartUpload",
      "s3:ListMultipartUploadParts"
    ]
    resources = ["${var.operations_bucket_arn}/athena-results/*"]
  }

  statement {
    sid    = "AthenaQueryAccess"
    effect = "Allow"
    actions = [
      "athena:BatchGetQueryExecution",
      "athena:GetDatabase",
      "athena:GetDataCatalog",
      "athena:GetQueryExecution",
      "athena:GetQueryResults",
      "athena:GetQueryResultsStream",
      "athena:GetTableMetadata",
      "athena:GetWorkGroup",
      "athena:ListDatabases",
      "athena:ListDataCatalogs",
      "athena:ListTableMetadata",
      "athena:StartQueryExecution",
      "athena:StopQueryExecution"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "GlueGoldCatalogRead"
    effect = "Allow"
    actions = [
      "glue:BatchGetPartition",
      "glue:GetDatabase",
      "glue:GetDatabases",
      "glue:GetPartition",
      "glue:GetPartitions",
      "glue:GetTable",
      "glue:GetTables"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "quicksight_athena_s3" {
  count  = var.enable_quicksight ? 1 : 0
  name   = "${var.project_name}-${var.environment}-quicksight-athena-gold"
  role   = var.quicksight_service_role_name
  policy = data.aws_iam_policy_document.quicksight_athena_s3[0].json
}

# Wait briefly for IAM policy propagation before QuickSight validates the Athena Data Source
resource "time_sleep" "quicksight_iam_propagation" {
  count           = var.enable_quicksight ? 1 : 0
  create_duration = "10s"

  depends_on = [aws_iam_role_policy.quicksight_athena_s3]
}

resource "aws_quicksight_data_source" "athena_gold" {
  count          = var.enable_quicksight ? 1 : 0
  data_source_id = "${var.project_name}-${var.environment}-athena-gold"
  name           = "${var.project_name}-${var.environment}-athena-gold"
  type           = "ATHENA"

  parameters {
    athena {
      work_group = aws_athena_workgroup.this.name
    }
  }

  permission {
    principal = local.quicksight_user_arn
    actions = [
      "quicksight:DescribeDataSource",
      "quicksight:DescribeDataSourcePermissions",
      "quicksight:PassDataSource",
      "quicksight:UpdateDataSource",
      "quicksight:DeleteDataSource",
      "quicksight:UpdateDataSourcePermissions"
    ]
  }

  depends_on = [
    time_sleep.quicksight_iam_propagation,
    aws_athena_workgroup.this
  ]

  tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

resource "aws_quicksight_data_set" "panel_enriquecido" {
  count       = var.enable_quicksight ? 1 : 0
  data_set_id = "${var.project_name}-${var.environment}-panel-enriquecido"
  name        = "Panel Distrital Enriquecido (${var.environment})"
  import_mode = var.quicksight_import_mode

  physical_table_map {
    physical_table_map_id = "panel-enriquecido-sql"

    custom_sql {
      data_source_arn = aws_quicksight_data_source.athena_gold[0].arn
      name            = "panel_enriquecido"
      sql_query       = <<-SQL
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
          CAST(c.fecha_corte_fuente AS TIMESTAMP) AS fecha_corte_fuente
        FROM ${aws_glue_catalog_database.gold.name}.panel_distrital p
        LEFT JOIN ${aws_glue_catalog_database.gold.name}.contexto_territorial c
          ON p.ubigeo = c.ubigeo
      SQL

      columns {
        name = "ubigeo"
        type = "STRING"
      }
      columns {
        name = "departamento"
        type = "STRING"
      }
      columns {
        name = "provincia"
        type = "STRING"
      }
      columns {
        name = "distrito"
        type = "STRING"
      }
      columns {
        name = "superficie_km2"
        type = "DECIMAL"
      }
      columns {
        name = "year"
        type = "INTEGER"
      }
      columns {
        name = "quarter"
        type = "INTEGER"
      }
      columns {
        name = "period_id"
        type = "INTEGER"
      }
      columns {
        name = "periodo"
        type = "STRING"
      }
      columns {
        name = "vel_descarga_mbps"
        type = "DECIMAL"
      }
      columns {
        name = "tests"
        type = "INTEGER"
      }
      columns {
        name = "teselas_observadas"
        type = "INTEGER"
      }
      columns {
        name = "observado"
        type = "BOOLEAN"
      }
      columns {
        name = "poblacion_2020"
        type = "DECIMAL"
      }
      columns {
        name = "densidad_hab_km2"
        type = "DECIMAL"
      }
      columns {
        name = "centros_en_reporte"
        type = "INTEGER"
      }
      columns {
        name = "centros_con_dato_4g"
        type = "INTEGER"
      }
      columns {
        name = "centros_con_4g_declarada"
        type = "INTEGER"
      }
      columns {
        name = "pct_cobertura_4g"
        type = "DECIMAL"
      }
      columns {
        name = "en_punto_ciego_osiptel"
        type = "BOOLEAN"
      }
      columns {
        name = "periodo_referencia"
        type = "STRING"
      }
      columns {
        name = "fecha_corte_fuente"
        type = "DATETIME"
      }
    }
  }

  permissions {
    principal = local.quicksight_user_arn
    actions = [
      "quicksight:DescribeDataSet",
      "quicksight:DescribeDataSetPermissions",
      "quicksight:PassDataSet",
      "quicksight:DescribeIngestion",
      "quicksight:ListIngestions",
      "quicksight:UpdateDataSet",
      "quicksight:DeleteDataSet",
      "quicksight:CreateIngestion",
      "quicksight:CancelIngestion",
      "quicksight:UpdateDataSetPermissions"
    ]
  }

  depends_on = [
    aws_glue_catalog_table.panel_distrital,
    aws_glue_catalog_table.contexto_territorial,
    aws_quicksight_data_source.athena_gold
  ]

  tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# Dataset 2: Model Inferences in DIRECT_QUERY mode (live updates as soon as Parquet files land in S3 Gold)
resource "aws_quicksight_data_set" "inferencias_modelos" {
  count       = var.enable_quicksight ? 1 : 0
  data_set_id = "${var.project_name}-${var.environment}-inferencias-modelos"
  name        = "Inferencias de Modelos (${var.environment})"
  import_mode = "DIRECT_QUERY"

  physical_table_map {
    physical_table_map_id = "inferencias-modelos-sql"

    custom_sql {
      data_source_arn = aws_quicksight_data_source.athena_gold[0].arn
      name            = "inferencias_modelos"
      sql_query       = <<-SQL
        SELECT
          m.inference_id,
          m.inference_timestamp,
          m.modelo,
          m.autor,
          m.ubigeo,
          c.departamento,
          c.provincia,
          c.distrito,
          c.poblacion_2020,
          (c.centros_en_reporte IS NULL) AS en_punto_ciego_osiptel,
          m.year_objetivo,
          m.quarter_objetivo,
          CONCAT(CAST(m.year_objetivo AS VARCHAR), '-T', CAST(m.quarter_objetivo AS VARCHAR)) AS periodo_objetivo,
          m.vel_origen_mbps,
          m.pred_descarga_mbps,
          (m.pred_descarga_mbps - m.vel_origen_mbps) AS delta_mbps,
          m.indice_prioridad,
          (m.inference_timestamp = MAX(m.inference_timestamp) OVER (PARTITION BY m.modelo)) AS es_ultima_inferencia
        FROM ${aws_glue_catalog_database.gold.name}.predicciones_modelos m
        LEFT JOIN ${aws_glue_catalog_database.gold.name}.contexto_territorial c
          ON m.ubigeo = c.ubigeo
      SQL

      columns {
        name = "inference_id"
        type = "STRING"
      }
      columns {
        name = "inference_timestamp"
        type = "DATETIME"
      }
      columns {
        name = "modelo"
        type = "STRING"
      }
      columns {
        name = "autor"
        type = "STRING"
      }
      columns {
        name = "ubigeo"
        type = "STRING"
      }
      columns {
        name = "departamento"
        type = "STRING"
      }
      columns {
        name = "provincia"
        type = "STRING"
      }
      columns {
        name = "distrito"
        type = "STRING"
      }
      columns {
        name = "poblacion_2020"
        type = "DECIMAL"
      }
      columns {
        name = "en_punto_ciego_osiptel"
        type = "BOOLEAN"
      }
      columns {
        name = "year_objetivo"
        type = "INTEGER"
      }
      columns {
        name = "quarter_objetivo"
        type = "INTEGER"
      }
      columns {
        name = "periodo_objetivo"
        type = "STRING"
      }
      columns {
        name = "vel_origen_mbps"
        type = "DECIMAL"
      }
      columns {
        name = "pred_descarga_mbps"
        type = "DECIMAL"
      }
      columns {
        name = "delta_mbps"
        type = "DECIMAL"
      }
      columns {
        name = "indice_prioridad"
        type = "DECIMAL"
      }
      columns {
        name = "es_ultima_inferencia"
        type = "BOOLEAN"
      }
    }
  }

  permissions {
    principal = local.quicksight_user_arn
    actions = [
      "quicksight:DescribeDataSet",
      "quicksight:DescribeDataSetPermissions",
      "quicksight:PassDataSet",
      "quicksight:DescribeIngestion",
      "quicksight:ListIngestions",
      "quicksight:UpdateDataSet",
      "quicksight:DeleteDataSet",
      "quicksight:CreateIngestion",
      "quicksight:CancelIngestion",
      "quicksight:UpdateDataSetPermissions"
    ]
  }

  depends_on = [
    aws_glue_catalog_table.predicciones_modelos,
    aws_glue_catalog_table.contexto_territorial,
    aws_quicksight_data_source.athena_gold
  ]

  tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}
