resource "aws_security_group" "datasync-task" {
  name        = "${var.resource_prefix}-datasync-${var.resource_suffix}"
  description = "${var.resource_prefix}-datasync-security-group-${var.resource_suffix}"
  vpc_id      = "${var.vpc_id}"

  egress {
    from_port   = 2049
    to_port     = 2049
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "EFS/NFS"
  }

  tags = {
    Name = "${var.resource_prefix}-datasync-task-${var.resource_suffix}"
  }
}

resource "aws_datasync_location_s3" "location_s3" {
  s3_bucket_arn = aws_s3_bucket.airflow[0].arn
  subdirectory  = "${var.datasync_location_s3_subdirectory}"

  s3_config {
    bucket_access_role_arn = "${aws_iam_role.task.arn}"
  }

  tags = {
    Name = "datasync-location-s3"
  }
}

resource "aws_datasync_location_efs" "location_efs" {
  efs_file_system_arn = aws_efs_mount_target.ecs_temp_space_az0.file_system_arn
  subdirectory = "/opt/airflow"

  ec2_config {
    security_group_arns = [aws_security_group.ecs_container_security_group.arn]
    subnet_arn          = "arn:aws:ec2:${var.region}:681718253798:subnet/${var.private_subnet_ids[0]}"
  }
}

resource "aws_datasync_task" "dags_sync" {
  destination_location_arn = aws_datasync_location_s3.location_s3.arn
  name                     = "${var.resource_prefix}-dags_sync-${var.resource_suffix}"
  source_location_arn      = aws_datasync_location_efs.location_efs.arn
}