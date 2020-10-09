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

resource "aws_ecs_task_definition" "airflow" {
  family                   = "airflow"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.ecs_cpu
  memory                   = var.ecs_memory
  network_mode             = "awsvpc"
  task_role_arn            = aws_iam_role.task.arn
  execution_role_arn       = aws_iam_role.execution.arn
  container_definitions    = <<TASK_DEFINITION
  [
    {
        "image": "${var.airflow_image_name}:${var.airflow_image_tag}",
        "cpu" : ${var.ecs_cpu},
        "memory": ${var.ecs_memory},
        "name": "airflow",
        "environment": [
            {"name": "AIRFLOW__WEBSERVER__NAVBAR_COLOR", "value": "${var.airflow_navbar_color}"},
        "logConfiguration": {
          "logDriver": "awslogs",
          "options": {
            "awslogs-group": "${aws_cloudwatch_log_group.airflow.name}",
            "awslogs-region": "eu-west-1",
            "awslogs-stream-prefix": "container"
          }
        },
        "essential": true,
        "portMappings": [
            {
                "containerPort": 8080,
                "hostPort": 8080
            }
        ]
    }
  ]
  TASK_DEFINITION
}