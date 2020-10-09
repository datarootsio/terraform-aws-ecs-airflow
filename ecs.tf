resource "aws_cloudwatch_log_group" "airflow" {
  name              = var.ecs_cluster_name
  retention_in_days = var.airflow_log_retention
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
            {"name": "AIRFLOW__WEBSERVER__NAVBAR_COLOR", "value": "${var.airflow_navbar_color}"}
        ],
        "logConfiguration": {
          "logDriver": "awslogs",
          "options": {
            "awslogs-group": "${aws_cloudwatch_log_group.airflow.name}",
            "awslogs-region": "${var.airflow_log_region}",
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

resource "aws_ecs_service" "airflow" {
  name            = "airflow"
  cluster         = aws_ecs_cluster.airflow.id
  task_definition = aws_ecs_task_definition.airflow.id
  desired_count   = 1

  network_configuration {
    subnets          = [var.subnet_id]
    security_groups  = [aws_security_group.airflow.id]
    assign_public_ip = true
  }

  capacity_provider_strategy {
    capacity_provider = "FARGATE_SPOT"
    weight            = 100
  }
}

// BASIC SG's TO TEST IF YOU ARE ABLE TO CONNECT
resource "aws_security_group" "airflow" {
  vpc_id      = var.vpc_id
  name        = "airflow"
  description = "airflow"
  tags = {
    Name = "airflow"
  }
}

resource "aws_security_group_rule" "ingress_from_lb" {
  security_group_id = aws_security_group.airflow.id
  type              = "ingress"
  protocol          = "TCP"
  from_port         = 8080
  to_port           = 8080
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "https_in" {
  security_group_id = aws_security_group.airflow.id
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
}
