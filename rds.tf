resource "aws_db_instance" "airflow" {
  count                     = var.postgres_uri != "" || var.airflow_executor == "Sequential" ? 0 : 1
  name                      = replace(title(local.rds_name), "-", "")
  allocated_storage         = 20
  storage_type              = "standard"
  engine                    = "postgres"
  engine_version            = "11.8"
  instance_class            = var.rds_instance_class
  username                  = var.rds_username
  password                  = var.rds_password
  multi_az                  = false
  availability_zone         = var.rds_availability_zone
  publicly_accessible       = false
  deletion_protection       = var.rds_deletion_protection
  final_snapshot_identifier = "${var.resource_prefix}-airflow-${var.resource_suffix}-${local.timestamp_sanitized}"
  identifier                = local.rds_name
  vpc_security_group_ids    = [aws_security_group.airflow.id]
  db_subnet_group_name      = aws_db_subnet_group.airflow[0].name

  tags = local.common_tags
}

resource "aws_db_subnet_group" "airflow" {
  count      = var.postgres_uri != "" || var.airflow_executor == "Sequential" ? 0 : 1
  name       = "${var.resource_prefix}-airflow-${var.resource_suffix}"
  subnet_ids = local.rds_ecs_subnet_ids

  tags = local.common_tags
}