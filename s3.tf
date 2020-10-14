resource "aws_s3_bucket" "airflow_seed" {
  count  = var.s3_bucket_name == "" ? 1 : 0
  bucket = "airflow-seed"
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

  tags = {
    name = "airflow"
  }
}

resource "aws_s3_bucket_public_access_block" "airflow_seed" {
  count  = var.s3_bucket_name == "" ? 1 : 0
  bucket = aws_s3_bucket.airflow_seed[0].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

data "template_file" "airflow-seed" {
  template = ""
}

resource "aws_s3_bucket_object" "airflow-seed" {
  bucket  = local.s3_bucket_name
  key     = "airflow-seed.py"
  content = templatefile("${path.module}/templates/airflow-seed.py", { BUCKET_NAME = local.s3_bucket_name })
}