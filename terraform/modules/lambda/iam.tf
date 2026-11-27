data "aws_iam_policy_document" "lambda_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "trigger_role" {
  name               = "${var.project_name}-${var.environment}-bronze-trigger-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json

  tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

resource "aws_iam_role_policy_attachment" "lambda_basic_logs" {
  role       = aws_iam_role.trigger_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

data "aws_iam_policy_document" "lambda_emr_steps" {
  statement {
    sid    = "SubmitEmrSteps"
    effect = "Allow"
    actions = [
      "elasticmapreduce:ListClusters",
      "elasticmapreduce:DescribeCluster",
      "elasticmapreduce:AddJobFlowSteps"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "lambda_emr_steps" {
  name   = "${var.project_name}-${var.environment}-lambda-emr-steps"
  role   = aws_iam_role.trigger_role.id
  policy = data.aws_iam_policy_document.lambda_emr_steps.json
}
