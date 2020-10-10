output "airflow_alb_dns" {
  value = aws_lb.airflow.dns_name
}

output "airflow_task_iam_role" {
  value = aws_iam_role.task
}