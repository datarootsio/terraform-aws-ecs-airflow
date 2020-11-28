data "archive_file" "cicd_lambda" {
  type        = "zip"
  output_path = "/tmp/cicd_lambda.zip"

  source {
    filename = "trigger_airflow_sync_dag.py"
    content = templatefile("${path.module}/templates/cicd-lambda/trigger_airflow_sync_dag.py", {
      AIRFLOW_ECS_CLUSTER_ARN = aws_ecs_cluster.airflow.arn
    })
  }
}

resource "aws_cloudwatch_log_group" "cicd_lambda" {
  name              = "${var.resource_prefix}-airflow-cicd-lambda-${var.resource_suffix}"
  retention_in_days = var.airflow_log_retention

  tags = local.common_tags
}

resource "aws_lambda_function" "cicd_lambda" {
  function_name = "${var.resource_prefix}-airflow-cicd-lambda-${var.resource_suffix}"

  filename         = data.archive_file.cicd_lambda.output_path
  source_code_hash = data.archive_file.cicd_lambda.output_base64sha256
  description      = "A Lambda function to invoke from your CICD to sync the dags in your airflow instance"

  role = aws_iam_role.cicd_lambda.arn

  handler = "trigger_airflow_sync_dag.lambda_handler"
  runtime = "python3.7"
  timeout = 30

  vpc_config {
    subnet_ids         = local.rds_ecs_subnet_ids
    security_group_ids = [aws_security_group.airflow.id]
  }

  depends_on = [
    aws_cloudwatch_log_group.cicd_lambda
  ]

  tags = local.common_tags
}