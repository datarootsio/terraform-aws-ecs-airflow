locals {
    own_tags = {
        Name = "airflow"
        CreatedBy = "Terrafrom"
    }
    common_tags = merge(local.own_tags, var.extra_tags)

    s3_bucket_name = var.s3_bucket_name != "" ? var.s3_bucket_name : aws_s3_bucket.airflow_seed[0].id
}