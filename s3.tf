resource "aws_s3_bucket" "airflow" {
  count  = var.s3_bucket_name == "" ? 1 : 0
  bucket = "${var.resource_prefix}-airflow-${var.resource_suffix}"
  acl    = "private"

  versioning {
    enabled = true
  }

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "aws:kms"
      }
    }
  }

  tags = local.common_tags
}

resource "aws_s3_bucket_public_access_block" "airflow" {
  count  = var.s3_bucket_name == "" ? 1 : 0
  bucket = aws_s3_bucket.airflow[0].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_object" "airflow_scheduler_entrypoint" {
  bucket  = local.s3_bucket_name
  key     = "startup/entrypoint_scheduler.sh"
  content = templatefile("${path.module}/templates/startup/entrypoint_scheduler.sh", { AIRFLOW_HOME = var.airflow_container_home })
}

resource "aws_s3_bucket_object" "airflow_webserver_entrypoint" {
  bucket  = local.s3_bucket_name
  key     = "startup/entrypoint_webserver.sh"
  content = templatefile("${path.module}/templates/startup/entrypoint_webserver.sh", { AIRFLOW_HOME = var.airflow_container_home })
}

resource "aws_s3_bucket_object" "airflow_init_entrypoint" {
  bucket = local.s3_bucket_name
  key    = "startup/entrypoint_init.sh"
  content = templatefile("${path.module}/templates/startup/entrypoint_init.sh", {
    RBAC_AUTH       = var.airflow_authentication == "rbac" ? "true" : "false",
    RBAC_USERNAME   = var.rbac_admin_username,
    RBAC_EMAIL      = var.rbac_admin_email,
    RBAC_FIRSTNAME  = var.rbac_admin_firstname,
    RBAC_LASTNAME   = var.rbac_admin_lastname,
    RBAC_PASSWORD   = var.rbac_admin_password,
    AIRFLOW_VERSION = var.airflow_image_tag
  })
}

resource "aws_s3_bucket_object" "airflow_init_db_script" {
  bucket = local.s3_bucket_name
  key    = "startup/init.py"
  source = "${path.module}/templates/startup/init.py"
}

resource "aws_s3_bucket_object" "airflow_requirements" {
  count   = var.airflow_py_requirements_path == "" ? 0 : 1
  bucket  = local.s3_bucket_name
  key     = "startup/requirements.txt"
  content = templatefile(local.airflow_py_requirements_path, {})
}

resource "aws_s3_bucket" "lambda_trigger_bucket" {
  count  = "${var.s3_bucket_source_arn == "" ? 1 : 0}"
  bucket = local.s3_bucket_name
}

resource "aws_s3_bucket_notification" "bucket_notification" {
  count  = "${var.s3_bucket_source_arn == "" ? 1 : 0}"
  bucket = local.s3_bucket_name

  lambda_function {
    lambda_function_arn = "${var.s3_bucket_source_arn != "" ? local.s3_bucket_name  : var.s3_bucket_source_arn }"
    events              = ["s3:ObjectCreated:*"]
  }
}

module "lambda" {
  source           = "moritzzimmer/lambda/aws"
  version          = "5.2.1"
  filename         = "lambda-datasync-dags.zip"
  function_name    = "lambda-datasync-dags"
  handler          = "lambda_handler"
  runtime          = "go1.x"
  source_code_hash = filebase64sha256("${path.module}/templates/lambda/lambda-datasync-dags.zip")
}