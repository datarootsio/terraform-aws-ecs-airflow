output "airflow_alb_dns" {
  description = "The DNS name of the ALB, with this you can access the Airflow webserver"
  value       = aws_lb.airflow.dns_name
}

output "airflow_dns_record" {
  description = "The created DNS record (only if \"use_https\" = true)"
  value       = local.dns_record
}

output "airflow_task_iam_role" {
  description = "The IAM role of the airflow task, use this to give Airflow more permissions"
  value       = aws_iam_role.task
}

output "airflow_connection_sg" {
  description = "The security group with which you can connect other instance to Airflow, for example EMR Livy"
  value       = aws_security_group.airflow
}

output "postgres_uri" {
  value = local.postgres_uri
}

output "airflow_api_key" {
  value = local.airflow_api_key
}

output "airflow_s3_bucket_arn" {
  value = aws_s3_bucket.airflow[0].arn
}

output "airflow_s3_bucket_name" {
  value = aws_s3_bucket.airflow[0].id
}

output "airflow_efs_dns" {
  value = aws_efs_file_system.airflow-efs.dns_name
}

output "efs_mount_point" {
  value = local.efs_root_directory
}

output "efs_identifier" {
  value = local.airflow_volume_name
}

output "airflow_user_password" {
  value = local.airflow_user_password
}