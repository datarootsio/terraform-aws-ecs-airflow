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

resource "aws_s3_bucket_object" "airflow_seed" {
  bucket  = local.s3_bucket_name
  key     = "dags/airflow_seed.py"
  content = templatefile("${path.module}/templates/dags/airflow_seed.py", { BUCKET_NAME = local.s3_bucket_name })
}