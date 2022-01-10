resource "aws_efs_file_system" "airflow" {
  creation_token = "${var.resource_prefix}-airlow-efs-${var.resource_suffix}"
  encrypted      = true
  performance_mode = "generalPurpose"
  throughput_mode  = "bursting"
  tags = {
    Name    = "${var.resource_prefix}-airflow-efs-${var.resource_suffix}"
  }
}
# Create the access point with the given user permissions
resource "aws_efs_access_point" "airflow" {
  file_system_id = aws_efs_file_system.airflow.id
  posix_user {
    gid = 1000
    uid = 1000
  }
  root_directory {
    path = local.efs_root_directory
    creation_info {
      owner_gid   = 1000
      owner_uid   = 1000
      permissions = 755
    }
  }
  tags = {
    Name    = "${var.resource_prefix}-airflow-efs-${var.resource_suffix}"
  }
}
# Create the mount targets on your private subnets
resource "aws_efs_mount_target" "this" {
    count           = length(var.private_subnet_ids)
    file_system_id  = aws_efs_file_system.airflow.id
    subnet_id       = var.private_subnet_ids[count.index]
}

resource "aws_security_group" "efs" {
   name = "efs-sg"
   description= "Allos inbound efs traffic from ecs"
   vpc_id = var.vpc_id

   ingress {
     security_groups = [aws_security_group.ecs.id]
     from_port = 2049
     to_port = 2049 
     protocol = "tcp"
   }     
        
   egress {
     security_groups = [aws_security_group.ecs.id]
     from_port = 0
     to_port = 0
     protocol = "-1"
   }
 }