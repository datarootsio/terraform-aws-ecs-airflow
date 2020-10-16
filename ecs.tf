resource "aws_cloudwatch_log_group" "airflow" {
  name              = "${var.resource_prefix}-airflow-${var.resource_suffix}"
  retention_in_days = var.airflow_log_retention

  tags = local.common_tags
}

resource "aws_ecs_cluster" "airflow" {
  name               = "${var.resource_prefix}-airflow-${var.resource_suffix}"
  capacity_providers = ["FARGATE_SPOT", "FARGATE"]

  default_capacity_provider_strategy {
    capacity_provider = "FARGATE_SPOT"
  }

  tags = local.common_tags
}

resource "aws_ecs_task_definition" "airflow" {
  family                   = "airflow"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.ecs_cpu
  memory                   = var.ecs_memory
  network_mode             = "awsvpc"
  task_role_arn            = aws_iam_role.task.arn
  execution_role_arn       = aws_iam_role.execution.arn
  volume {
    name = "airflow-seed"
  }
  container_definitions = <<TASK_DEFINITION
  [
 {
        "image": "amazon/aws-cli",
        "name": "airflow-seed",
        "command": [
          "s3",
          "cp",
          "s3://${local.s3_bucket_name}/${aws_s3_bucket_object.airflow-seed.key}",
          "/usr/local/airflow/dags/airflow-seed.py"
        ],
        "logConfiguration": {
          "logDriver": "awslogs",
          "options": {
            "awslogs-group": "${aws_cloudwatch_log_group.airflow.name}",
            "awslogs-region": "${var.airflow_log_region}",
            "awslogs-stream-prefix": "container"
          }
        },
        "essential": false,
        "mountPoints": [
          {
            "sourceVolume": "airflow-seed",
            "containerPath": "/usr/local/airflow/dags"
          }
        ]
    },
    {
        "image": "${var.airflow_image_name}:${var.airflow_image_tag}",
        "name": "${local.airflow_container_name}",
        "dependsOn": [
            {
                "containerName": "airflow-seed",
                "condition": "COMPLETE"
            }
        ],
        "environment": [
            {"name": "LOAD_EX", "value": "n"},
            {"name": "EXECUTOR", "value": "Local"},
            {"name": "POSTGRES_HOST", "value": "${aws_db_instance.airflow.address}"},
            {"name": "POSTGRES_PORT", "value": "${aws_db_instance.airflow.port}"},
            {"name": "POSTGRES_USER", "value": "${var.rds_username}"},
            {"name": "POSTGRES_PASSWORD", "value": "${var.rds_password}"},
            {"name": "POSTGRES_DB", "value": "${aws_db_instance.airflow.name}"},
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
        "mountPoints": [
          {
            "sourceVolume": "airflow-seed",
            "containerPath": "/usr/local/airflow/dags"
          }
        ],
        "portMappings": [
            {
                "containerPort": 8080,
                "hostPort": 8080
            }
        ]
    }
  ]
  TASK_DEFINITION

  tags = local.common_tags
}

// Without depends_on I get this error:
// Error: InvalidParameterException: The target group with targetGroupArn arn:aws:elasticloadbalancing:eu-west-1:428226611932:targetgroup/airflow/77a259290ea30e76 does not have an associated load balancer. "airflow"
resource "aws_ecs_service" "airflow" {
  depends_on = [aws_lb.airflow, aws_db_instance.airflow]

  name            = "${var.resource_prefix}-airflow-${var.resource_suffix}"
  cluster         = aws_ecs_cluster.airflow.id
  task_definition = aws_ecs_task_definition.airflow.id
  desired_count   = 1

  network_configuration {
    subnets          = [var.public_subnet_id]
    security_groups  = [aws_security_group.airflow.id]
    assign_public_ip = true
  }

  capacity_provider_strategy {
    capacity_provider = "FARGATE_SPOT"
    weight            = 100
  }

  load_balancer {
    container_name   = local.airflow_container_name
    container_port   = 8080
    target_group_arn = aws_lb_target_group.airflow.arn
  }
}

resource "aws_lb_target_group" "airflow" {
  name        = "${var.resource_prefix}-airflow-${var.resource_suffix}"
  vpc_id      = var.vpc_id
  protocol    = "HTTP"
  port        = 8080
  target_type = "ip"

  health_check {
    port                = 8080
    protocol            = "HTTP"
    interval            = 30
    unhealthy_threshold = 3
    matcher             = "200,302"

  }

  lifecycle {
    create_before_destroy = true
  }

  tags = local.common_tags
}