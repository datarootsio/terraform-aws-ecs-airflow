resource "aws_db_instance" "airflow" {
  count                      = var.postgres_uri != "" || var.airflow_executor == "Sequential" ? 0 : 1
  name                       = replace(title(local.rds_name), "-", "")
  allocated_storage          = var.rds_allocated_storage
  storage_type               = var.rds_storage_type
  engine                     = var.rds_engine
  engine_version             = var.rds_version
  auto_minor_version_upgrade = false
  instance_class             = var.rds_instance_class
  username                   = var.rds_username
  password                   = var.rds_password
  multi_az                   = false
  availability_zone          = var.rds_availability_zone
  publicly_accessible        = false
  deletion_protection        = var.rds_deletion_protection
  skip_final_snapshot        = var.rds_skip_final_snapshot
  final_snapshot_identifier  = "${var.resource_prefix}-airflow-${var.resource_suffix}-${local.timestamp_sanitized}"
  identifier                 = local.rds_name
  vpc_security_group_ids     = [aws_security_group.airflow.id]
  db_subnet_group_name       = aws_db_subnet_group.airflow[0].name
  storage_encrypted          = true
  backup_retention_period    = 7
  backup_window              = "10:28-10:58"
  ca_cert_identifier         = "rds-ca-2019"
  delete_automated_backups   = false
  enabled_cloudwatch_logs_exports = [
    "postgresql",
    "upgrade"
  ]
  kms_key_id                   = "arn:aws:kms:us-east-1:796958440801:key/b1082d93-c665-4a2b-a79c-08da2a9c8ab1"
  maintenance_window           = "sat:03:23-sat:03:53"
  monitoring_interval          = 1
  monitoring_role_arn          = "arn:aws:iam::796958440801:role/rds-monitoring-role"
  performance_insights_enabled = true

  tags = local.common_tags
}

resource "aws_db_subnet_group" "airflow" {
  count      = var.postgres_uri != "" || var.airflow_executor == "Sequential" ? 0 : 1
  name       = "${var.resource_prefix}-airflow-${var.resource_suffix}"
  subnet_ids = local.rds_ecs_subnet_ids

  tags = local.common_tags
}
