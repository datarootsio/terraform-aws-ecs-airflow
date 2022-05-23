# TODO: temporary commented (efs works only with the DNS hostnames enabled) 
resource "aws_efs_file_system" "airflow-efs" {
  creation_token = "${var.resource_prefix}-airlow-efs-${var.resource_suffix}"
  encrypted      = true
  performance_mode = "generalPurpose"
  throughput_mode  = "bursting"

  lifecycle_policy {
    transition_to_ia = "AFTER_7_DAYS"
  }

  tags = {
    Name    = "${var.resource_prefix}-airflow-efs-${var.resource_suffix}"
  }
}

resource "aws_efs_backup_policy" "policy" {
  file_system_id = aws_efs_file_system.airflow-efs.id

  backup_policy {
    status = "ENABLED"
  }
}

resource "aws_efs_mount_target" "ecs_temp_space_az" {
  file_system_id = "${aws_efs_file_system.airflow-efs.id}"
  subnet_id      = var.private_subnet_ids[0]
  security_groups = ["${aws_security_group.ecs_container_security_group.id}", "${aws_security_group.ecs_container_security_group1.id}"]
}

resource "aws_efs_mount_target" "ecs_temp_space_az1" {
  file_system_id = "${aws_efs_file_system.airflow-efs.id}"
  subnet_id      = var.private_subnet_ids[1]
  security_groups = ["${aws_security_group.ecs_container_security_group.id}", "${aws_security_group.ecs_container_security_group1.id}"]
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
    }

  ingress                = [
   {
     cidr_blocks      = [ "0.0.0.0/0", ]
     description      = ""
     from_port        = 2049
     ipv6_cidr_blocks = []
     prefix_list_ids  = []
     protocol         = "tcp"
     security_groups  = []
     self             = false
     to_port          = 2049
  }]

  tags = local.common_tags
}

resource "aws_security_group" "ecs_container_security_group1" {
  name        = "${var.resource_prefix}-ecs1-sg-${var.resource_suffix}"
  description = "Outbound Traffic Only"
  vpc_id      = "${var.vpc_id}"

  egress = [
    {
      cidr_blocks      = [ "0.0.0.0/0", ]
      description      = ""
      from_port        = 0
      ipv6_cidr_blocks = []
      prefix_list_ids  = []
      protocol         = "-1"
      security_groups  = []
      self             = false
      to_port          = 0
    }
  ]
 ingress                = [
   {
     cidr_blocks      = [ "0.0.0.0/0", ]
     description      = ""
     from_port        = 22
     ipv6_cidr_blocks = []
     prefix_list_ids  = []
     protocol         = "tcp"
     security_groups  = []
     self             = false
     to_port          = 22
  }
  ]
  

  tags = local.common_tags
}