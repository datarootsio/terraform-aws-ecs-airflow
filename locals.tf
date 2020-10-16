locals {
  module_name = "terraform-aws-ecs-airflow"

  own_tags = {
    Name      = "airflow"
    CreatedBy = "Terrafrom"
    Module    = local.module_name
  }
  common_tags = merge(local.own_tags, var.extra_tags)

  rds_name     = "airflow"
  postgres_uri = "${var.rds_username}:${var.rds_password}@${aws_db_instance.airflow.address}:${aws_db_instance.airflow.port}/${aws_db_instance.airflow.name}"

  s3_bucket_name = var.s3_bucket_name != "" ? var.s3_bucket_name : aws_s3_bucket.airflow[0].id
  s3_key         = ""

  airflow_webserver_container_name = "${var.resource_prefix}-airflow-webserver-${var.resource_suffix}"
  airflow_scheduler_container_name = "${var.resource_prefix}-airflow-scheduler-${var.resource_suffix}"
  airflow_sidecar_container_name   = "${var.resource_prefix}-airflow-sidecar-${var.resource_suffix}"
  airflow_volume_name              = "airflow"

  airflow_container_home = "/opt/airflow"
}