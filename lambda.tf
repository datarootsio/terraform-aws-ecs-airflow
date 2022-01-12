resource "aws_iam_role" "iam_for_lambda" {
  name = "iam_for_lambda"

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

data "archive_file" "zipit" {
  type        = "zip"
  source_file = "${path.module}/datasync-dags-lambda/handler_datasync_task.py"
  output_path = "${path.module}/datasync-dags-lambda.zip"
}

resource "aws_lambda_function" "dags-sync-lambda" {
  filename      = "${path.module}/datasync-dags-lambda.zip"
  function_name = "${var.resource_prefix}-datasync-dags-lambda-${var.resource_suffix}"
  role          = aws_iam_role.iam_for_lambda.arn
  handler       = "datasync-dags-lambda.lambda_handler"

  source_code_hash = "${data.archive_file.zipit.output_base64sha256}"

  runtime = "python3.8"
}

resource "null_resource" "wait_for_lambda_trigger" {
  depends_on   = [aws_lambda_permission.s3_trigger]
  provisioner "local-exec" {
    command = "sleep 3m"
  }
}

resource "aws_s3_bucket_notification" "aws-lambda-trigger" {
  bucket = local.s3_bucket_name
  depends_on = [null_resource.wait_for_lambda_trigger]

  lambda_function {
    lambda_function_arn = "${aws_lambda_function.dags-sync-lambda.arn}"
    events              = ["s3:ObjectCreated:*"]
  }
  
}

resource "aws_lambda_permission" "s3_trigger" {
  statement_id  = "AllowExecutionFromS3Bucket"
  action        = "lambda:InvokeFunction"
  function_name = "${aws_lambda_function.dags-sync-lambda.arn}"
  principal = "s3.amazonaws.com"
  source_arn = "arn:aws:s3:::${var.resource_prefix}-${local.s3_bucket_name}-${var.resource_suffix}"
}