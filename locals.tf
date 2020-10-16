locals {
  module_name = "terraform-aws-ecs-airflow"

  own_tags = {
    Name      = "airflow"
    CreatedBy = "Terrafrom"
    Module    = local.module_name
  }
  common_tags = merge(local.own_tags, var.extra_tags)

  s3_bucket_name         = var.s3_bucket_name != "" ? var.s3_bucket_name : aws_s3_bucket.airflow_seed[0].id
  airflow_container_name = "${var.resource_prefix}-airflow-${var.resource_suffix}"
}