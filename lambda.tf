resource "aws_iam_role" "iam_for_lambda" {
  name = "${var.resource_prefix}-iam-for-lambda-${var.resource_suffix}"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "revoke_keys_role_policy" {
  name = "${var.resource_prefix}-lambda-iam-policy-${var.resource_suffix}"
  role = aws_iam_role.iam_for_lambda.id

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "s3:*",
        "ses:*",
        "datasync:*",
        "lambda:*"
      ],
      "Effect": "Allow",
      "Resource": "*"
    }
  ]
}
EOF
}

data "archive_file" "zipit" {
  type        = "zip"
  source_file = "${path.module}/datasync-dags/datasync-dags.py"
  output_path = "${path.module}/datasync-dags.zip"
}

resource "aws_lambda_function" "dags-sync-lambda" {
  filename      = "${path.module}/datasync-dags.zip"
  function_name = "datasync-dags"
  role          = aws_iam_role.iam_for_lambda.arn
  handler       = "datasync-dags.handler"

  source_code_hash = "${data.archive_file.zipit.output_base64sha256}"

  runtime = "python3.8"

  environment {
    variables = {
      DAG_ID = "${local.airflow_sync_dag_id}",
      AIRFLOW_URL = "${aws_lb.airflow.dns_name}",
      API_KEY = "${local.airflow_api_key}"
    }
  }

  depends_on = [
    aws_iam_role_policy_attachment.lambda_logs,
    aws_cloudwatch_log_group.lambda_logs,
  ]
}

resource "aws_s3_bucket_notification" "aws-lambda-trigger" {
  bucket = aws_s3_bucket.airflow[0].id

  lambda_function {
    lambda_function_arn = aws_lambda_function.dags-sync-lambda.arn
    events              = ["s3:ObjectCreated:*", "s3:ObjectRemoved:*"]
  }
  
}

resource "aws_lambda_permission" "s3_trigger" {
  statement_id  = "AllowS3Invoke"
  action        = "lambda:InvokeFunction"
  function_name = "${aws_lambda_function.dags-sync-lambda.arn}"
  principal = "s3.amazonaws.com"
  source_arn = "arn:aws:s3:::${aws_s3_bucket.airflow[0].id}"
}

# This is to optionally manage the CloudWatch Log Group for the Lambda Function.
# If skipping this resource configuration, also add "logs:CreateLogGroup" to the IAM policy below.
resource "aws_cloudwatch_log_group" "lambda_logs" {
  name              = "/aws/lambda/${var.resource_prefix}-datasync-dags-${var.resource_suffix}" 
  retention_in_days = 14
}

resource "aws_iam_policy" "lambda_logging" {
  name        = "${var.resource_prefix}-lambda-logging-${var.resource_suffix}"
  path        = "/"
  description = "IAM policy for logging from a lambda"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "arn:aws:logs:*:*:*",
      "Effect": "Allow"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.iam_for_lambda.name
  policy_arn = aws_iam_policy.lambda_logging.arn
}
