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

output "cicd_lambda_name" {
  description = "The name of the lambda function that invokes the seed dag (only if \"cicd_lambda\" is enabled)"
  value       = aws_lambda_function.cicd_lambda[0].function_name
}
