resource "aws_efs_file_system" "airflow-efs" {
  creation_token = "${var.resource_prefix}-airlow-efs-${var.resource_suffix}"
  encrypted      = true
  performance_mode = "generalPurpose"
  throughput_mode  = "bursting"

  lifecycle_policy {
    transition_to_ia = "AFTER_30_DAYS"
  }

  tags = {
    Name    = "${var.resource_prefix}-airflow-efs-${var.resource_suffix}"
  }
}

resource "aws_efs_mount_target" "ecs_temp_space_az0" {
  file_system_id = "${aws_efs_file_system.airflow-efs.id}"
  subnet_id      = var.private_subnet_ids[0]
  security_groups = ["${aws_security_group.ecs_container_security_group.id}"]
}

resource "aws_efs_mount_target" "ecs_temp_space_az1" {
  file_system_id = "${aws_efs_file_system.airflow-efs.id}"
  subnet_id      = var.private_subnet_ids[1]
  security_groups = ["${aws_security_group.ecs_container_security_group.id}"]
}

resource "aws_security_group" "ecs_container_security_group" {
  name        = "${var.resource_prefix}-ecs-sg-${var.resource_suffix}"
  description = "Outbound Traffic Only"
  vpc_id      = "${var.vpc_id}"

    egress {
      description      = "for all outgoing traffics"
      from_port        = 0
      to_port          = 0
      protocol         = "-1"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = ["::/0"]
      prefix_list_ids = []
      security_groups = []
      self = false
    }

  ingress {
      description      = "NFS"
      from_port        = 2049
      to_port          = 2049
      protocol         = "tcp"
      cidr_blocks      = ["${var.cidr}"]  
      ipv6_cidr_blocks = []
      prefix_list_ids = []
      security_groups = []
      self = false
  }

  ingress {
    description      = "Loopback"
    from_port        = 0
    ipv6_cidr_blocks = []
    prefix_list_ids  = []
    protocol         = "-1"
    cidr_blocks      = []
    security_groups  = []
    self             = true
    to_port          = 0
  }

  tags = local.common_tags
}
