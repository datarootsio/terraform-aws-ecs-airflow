locals {
  own_tags = {
    Name      = "${var.resource_prefix}-airflow-${var.resource_suffix}"
    CreatedBy = "Terraform"
    Module    = "terraform-aws-ecs-airflow"
  }
  common_tags = merge(local.own_tags, var.extra_tags)

  timestamp           = timestamp()
  timestamp_sanitized = replace(local.timestamp, "/[- TZ:]/", "")
  year                = formatdate("YYYY", local.timestamp)
  month               = formatdate("M", local.timestamp)
  day                 = formatdate("D", local.timestamp)

  rds_name             = "${var.resource_prefix}-airflow-${var.resource_suffix}"
  created_postgres_uri = "${var.rds_username}:${var.rds_password}@${aws_db_instance.airflow.address}:${aws_db_instance.airflow.port}/${aws_db_instance.airflow.name}"
  postgres_uri         = var.postgres_uri != "" ? var.postgres_uri : local.created_postgres_uri

  s3_bucket_name = var.s3_bucket_name != "" ? var.s3_bucket_name : aws_s3_bucket.airflow[0].id
  s3_key         = ""

  airflow_log_region               = var.airflow_log_region != "" ? var.airflow_log_region : var.region
  airflow_webserver_container_name = "${var.resource_prefix}-airflow-webserver-${var.resource_suffix}"
  airflow_scheduler_container_name = "${var.resource_prefix}-airflow-scheduler-${var.resource_suffix}"
  airflow_sidecar_container_name   = "${var.resource_prefix}-airflow-sidecar-${var.resource_suffix}"
  airflow_volume_name              = "airflow"
  airflow_variables = merge({
    AIRFLOW__CORE__SQL_ALCHEMY_CONN : "postgresql+psycopg2://${local.postgres_uri}",
    AIRFLOW__CORE__EXECUTOR : "LocalExecutor",
  }, var.airflow_variables)

  airflow_variables_list = formatlist("{\"name\":\"%s\",\"value\":\"%s\"}", keys(local.airflow_variables), values(local.airflow_variables))

  rds_ecs_subnet_ids = length(var.private_subnet_ids) == 0 ? var.public_subnet_ids : var.private_subnet_ids

  dns_record      = var.dns_name != "" ? var.dns_name : (var.route53_zone_name != "" ? "${var.resource_prefix}-airflow-${var.resource_suffix}.${data.aws_route53_zone.zone[0].name}" : "")
  certificate_arn = var.use_https ? (var.certificate_arn != "" ? var.certificate_arn : aws_acm_certificate.cert[0].arn) : ""
}