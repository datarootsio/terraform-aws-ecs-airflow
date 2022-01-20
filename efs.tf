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
  subnet_id      = var.public_subnet_ids[0]
  security_groups = ["${aws_security_group.ecs_container_security_group.id}"]
}

resource "aws_efs_mount_target" "ecs_temp_space_az1" {
  file_system_id = "${aws_efs_file_system.airflow-efs.id}"
  subnet_id      = var.public_subnet_ids[1]
  security_groups = ["${aws_security_group.ecs_container_security_group.id}"]
}

resource "aws_security_group" "ecs_container_security_group" {
  name        = "${var.resource_prefix}-ecs-sg-${var.resource_suffix}"
  description = "Outbound Traffic Only"
  vpc_id      = "${var.vpc_id}"

  ingress = [
    {
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
  ]

  egress = [
    {
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
  ]

}

#----------------------------------------
# ECS security-group loop back rule to connect to EFS Volume
#----------------------------------------
resource "aws_security_group_rule" "ecs_loopback_rule" {
  type                      = "ingress"
  from_port                 = 0
  to_port                   = 0
  protocol                  = "-1"
  self                      = true
  description               = "Loopback"
  security_group_id         = "${aws_security_group.ecs_container_security_group.id}"
}