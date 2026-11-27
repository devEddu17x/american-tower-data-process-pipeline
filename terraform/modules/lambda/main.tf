data "archive_file" "trigger_zip" {
  type        = "zip"
  source_file = var.source_file_path
  output_path = "${path.module}/build/trigger_emr.zip"
}

resource "aws_lambda_function" "bronze_trigger" {
  function_name    = "${var.project_name}-${var.environment}-bronze-to-emr-trigger"
  description      = "Triggers an incremental PySpark EMR Step when a new Ookla Parquet lands in Bronze incoming/"
  role             = aws_iam_role.trigger_role.arn
  runtime          = "python3.12"
  handler          = "trigger_emr.handler"
  filename         = data.archive_file.trigger_zip.output_path
  source_code_hash = data.archive_file.trigger_zip.output_base64sha256
  memory_size      = 128
  timeout          = 30

  environment {
    variables = {
      EMR_CLUSTER_NAME_PREFIX   = "${var.project_name}-${var.environment}"
      INCREMENTAL_SCRIPT_S3_URI = var.incremental_script_s3_uri
      BRONZE_MANIFEST_URI       = var.bronze_manifest_uri
      SILVER_MANIFEST_URI       = var.silver_manifest_uri
      SILVER_BUCKET             = var.silver_bucket_id
      GOLD_BUCKET               = var.gold_bucket_id
      GOLD_RUN_ID               = var.gold_run_id
      OPERATIONS_BUCKET         = var.operations_bucket_id
      QUICKSIGHT_DATASET_ID     = var.quicksight_dataset_id
    }
  }

  tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

resource "aws_lambda_permission" "allow_s3_bronze" {
  statement_id  = "AllowExecutionFromS3Bronze"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.bronze_trigger.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = var.bronze_bucket_arn
}

resource "aws_s3_bucket_notification" "bronze_incoming" {
  bucket = var.bronze_bucket_id

  lambda_function {
    lambda_function_arn = aws_lambda_function.bronze_trigger.arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = var.incoming_prefix
    filter_suffix       = ".parquet"
  }

  depends_on = [aws_lambda_permission.allow_s3_bronze]
}
