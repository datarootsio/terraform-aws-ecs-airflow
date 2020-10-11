// SG only meant for the alb to connect to the outside world
resource "aws_security_group" "alb" {
  vpc_id      = var.vpc_id
  name        = "alb"
  description = "Security group for the alb attached to the airflow ecs task"

  egress {
    description = "Allow all traffic out"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    name = "airflow"
  }
}

resource "aws_security_group_rule" "alb_outside_http" {
  security_group_id = aws_security_group.alb.id
  type              = "ingress"
  protocol          = "TCP"
  from_port         = 80
  to_port           = 80
  cidr_blocks       = ["0.0.0.0/0"]
}

// Give this SG to all the instances that want to connect to
// the airflow ecs task. For example rds and the alb
resource "aws_security_group" "airflow" {
  vpc_id      = var.vpc_id
  name        = "airflow"
  description = "Security group to connect to the airflow instance"

  egress {
    description = "Allow all traffic out"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    name = "airflow"
  }
}

resource "aws_security_group_rule" "airflow_connection" {
  security_group_id        = aws_security_group.airflow.id
  type                     = "ingress"
  protocol                 = "-1"
  from_port                = 0
  to_port                  = 0
  source_security_group_id = aws_security_group.airflow.id
}

// ALB
resource "aws_lb" "airflow" {
  name               = "airflow"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id, aws_security_group.airflow.id]
  subnets            = [var.public_subnet_id, var.backup_public_subnet_id]

  enable_deletion_protection = false

  tags = {
    name = "airflow"
  }
}


resource "aws_lb_listener" "airflow" {
  load_balancer_arn = aws_lb.airflow.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.airflow.arn
  }
}

