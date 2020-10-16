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

resource "aws_s3_bucket_object" "airflow_seed_dag" {
  bucket = local.s3_bucket_name
  key    = "dags/airflow_seed.py"
  content = templatefile("${path.module}/templates/dags/airflow_seed.py", {
    BUCKET_NAME  = local.s3_bucket_name,
    KEY          = local.s3_key,
    AIRFLOW_HOME = local.airflow_container_home
  })
}

resource "aws_s3_bucket_object" "airflow_example_dag" {
  bucket  = local.s3_bucket_name
  key     = "dags/example_dag.py"
  content = templatefile("${path.module}/templates/dags/example_dag.py", {})
}

resource "aws_s3_bucket_object" "airflow_scheduler_entrypoint" {
  bucket  = local.s3_bucket_name
  key     = "startup/entrypoint_scheduler.sh"
  content = templatefile("${path.module}/templates/startup/entrypoint_scheduler.sh", { AIRFLOW_HOME = local.airflow_container_home })
}

resource "aws_s3_bucket_object" "airflow_webserver_entrypoint" {
  bucket  = local.s3_bucket_name
  key     = "startup/entrypoint_webserver.sh"
  content = templatefile("${path.module}/templates/startup/entrypoint_webserver.sh", { AIRFLOW_HOME = local.airflow_container_home })
}

resource "aws_s3_bucket_object" "airflow_requirements" {
  bucket  = local.s3_bucket_name
  key     = "startup/requirements.txt"
  content = templatefile("${path.module}/templates/startup/requirements.txt", {})
}