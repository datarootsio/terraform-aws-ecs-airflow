resource "aws_cloudwatch_log_group" "airflow" {
  name              = var.ecs_cluster_name
  retention_in_days = "7"
}

resource "aws_ecs_cluster" "airflow" {
  name               = var.ecs_cluster_name
  capacity_providers = ["FARGATE_SPOT", "FARGATE"]

  default_capacity_provider_strategy {
    capacity_provider = "FARGATE_SPOT"
  }
}

