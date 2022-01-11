# resource "aws_efs_file_system" "airflow-efs" {
#   creation_token = "${var.resource_prefix}-airlow-efs-${var.resource_suffix}"
#   encrypted      = true
#   performance_mode = "generalPurpose"
#   throughput_mode  = "bursting"
#   tags = {
#     Name    = "${var.resource_prefix}-airflow-efs-${var.resource_suffix}"
#   }
# }

# resource "aws_efs_mount_target" "ecs_temp_space_az0" {
#   file_system_id = "${aws_efs_file_system.airflow-efs.id}"
#   subnet_id      = var.private_subnet_ids[0]
#   security_groups = ["${aws_security_group.ecs_container_security_group.id}"]
# }

# resource "aws_efs_mount_target" "ecs_temp_space_az1" {
#   file_system_id = "${aws_efs_file_system.airflow-efs.id}"
#   subnet_id      = var.private_subnet_ids[1]
#   security_groups = ["${aws_security_group.ecs_container_security_group.id}"]
# }

# resource "aws_security_group" "ecs_container_security_group" {
#   name        = "${var.resource_prefix}-ecs-sg-${var.resource_suffix}"
#   description = "Outbound Traffic Only"
#   vpc_id      = "${var.vpc_id}"

#   ingress = [
#     {
#       description      = "NFS"
#       from_port        = 2049
#       to_port          = 2049
#       protocol         = "tcp"
#       cidr_blocks      = ["${var.cidr}"]  
#       ipv6_cidr_blocks = []
#       prefix_list_ids = []
#       security_groups = []
#       self = false      
#     }
#   ]

#   egress = [
#     {
#       description      = "for all outgoing traffics"
#       from_port        = 0
#       to_port          = 0
#       protocol         = "-1"
#       cidr_blocks      = ["0.0.0.0/0"]
#       ipv6_cidr_blocks = ["::/0"]
#       prefix_list_ids = []
#       security_groups = []
#       self = false
#     }
#   ]

# }

# #----------------------------------------
# # ECS security-group loop back rule to connect to EFS Volume
# #----------------------------------------
# resource "aws_security_group_rule" "ecs_loopback_rule" {
#   type                      = "ingress"
#   from_port                 = 0
#   to_port                   = 0
#   protocol                  = "-1"
#   self                      = true
#   description               = "Loopback"
#   security_group_id         = "${aws_security_group.ecs_container_security_group.id}"
# }

# resource "aws_efs_access_point" "airflow" {
#   file_system_id = aws_efs_file_system.airflow-efs.id
#   posix_user {
#     gid = 1001
#     uid = 5000
#     secondary_gids = [1002,1003]
#   }
#   root_directory {
#     path = "/opt/airflow"
#     creation_info {
#       owner_gid   = 1001
#       owner_uid   = 5000
#       permissions = 0755
#     }
#   }
#   tags = {
#     Name    = "${var.resource_prefix}-airflow-efs-${var.resource_suffix}"
#   }
# }

module "efs" {
  source = "github.com/cloudposse/terraform-aws-efs"

  region  = var.region
  vpc_id  = var.vpc_id
  subnets = var.private_subnet_ids

  access_points = {
    "data" = {
      posix_user = {
        gid            = "1001"
        uid            = "5000"
        secondary_gids = "1002,1003"
      }
      creation_info = {
        gid         = "1001"
        uid         = "5000"
        permissions = "0755"
      }
    }
    "data2" = {
      posix_user = {
        gid            = "2001"
        uid            = "6000"
        secondary_gids = null
      }
      creation_info = {
        gid         = "123"
        uid         = "222"
        permissions = "0555"
      }
    }
  }

  additional_security_group_rules = [
    {
      type                     = "ingress"
      from_port                = 2049
      to_port                  = 2049
      protocol                 = "tcp"
      cidr_blocks              = []
      source_security_group_id = aws_security_group.ecs_container_security_group.id
      description              = "Allow ingress traffic to EFS from trusted Security Groups"
    }
  ]

  transition_to_ia = ["AFTER_7_DAYS"]

  security_group_create_before_destroy = false

  context = module.this.context
}

resource "aws_security_group" "ecs_container_security_group" {
  name        = "${var.resource_prefix}-ecs-sg-${var.resource_suffix}"
  description = "Outbound Traffic Only"
  vpc_id      = "${var.vpc_id}"

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