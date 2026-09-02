# EMR Service Role
data "aws_iam_policy_document" "emr_service_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["elasticmapreduce.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "emr_service_role" {
  name               = "${var.project_name}-${var.environment}-emr-service-role"
  assume_role_policy = data.aws_iam_policy_document.emr_service_assume_role.json

  tags = {
    Project   = var.project_name
    ManagedBy = "Terraform"
  }
}

resource "aws_iam_role_policy_attachment" "emr_service_policy" {
  role       = aws_iam_role.emr_service_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEMRServicePolicy_v2"
}

# Allow EMR Service Role to pass custom EC2 Role to EC2 instances
data "aws_iam_policy_document" "emr_service_pass_role" {
  statement {
    effect    = "Allow"
    actions   = ["iam:PassRole"]
    resources = [aws_iam_role.emr_ec2_role.arn]

    condition {
      test     = "StringLike"
      variable = "iam:PassedToService"
      values   = ["ec2.amazonaws.com*"]
    }
  }
}

resource "aws_iam_role_policy" "emr_service_pass_role" {
  name   = "${var.project_name}-${var.environment}-emr-service-pass-role"
  role   = aws_iam_role.emr_service_role.id
  policy = data.aws_iam_policy_document.emr_service_pass_role.json
}

# EMR EC2 Role & Instance Profile
data "aws_iam_policy_document" "emr_ec2_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "emr_ec2_role" {
  name               = "${var.project_name}-${var.environment}-emr-ec2-role"
  assume_role_policy = data.aws_iam_policy_document.emr_ec2_assume_role.json

  tags = {
    Project   = var.project_name
    ManagedBy = "Terraform"
  }
}

resource "aws_iam_role_policy_attachment" "emr_ec2_role_policy" {
  role       = aws_iam_role.emr_ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonElasticMapReduceforEC2Role"
}

resource "aws_iam_role_policy_attachment" "emr_ec2_s3_policy" {
  role       = aws_iam_role.emr_ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}

resource "aws_iam_instance_profile" "emr_ec2_profile" {
  name = "${var.project_name}-${var.environment}-emr-ec2-profile"
  role = aws_iam_role.emr_ec2_role.name

  tags = {
    Project   = var.project_name
    ManagedBy = "Terraform"
  }
}
