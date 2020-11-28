data "aws_iam_policy_document" "task_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "task_permissions" {
  statement {
    effect = "Allow"

    resources = [
      aws_cloudwatch_log_group.airflow.arn,
    ]

    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]
  }

  statement {
    effect = "Allow"

    resources = [
      "arn:aws:s3:::*"
    ]

    actions = ["s3:ListBucket", "s3:ListAllMyBuckets"]
  }

  statement {
    effect    = "Allow"
    resources = ["arn:aws:s3:::${local.s3_bucket_name}", "arn:aws:s3:::${local.s3_bucket_name}/*"]
    actions   = ["s3:ListBucket", "s3:GetObject"]
  }

}

data "aws_iam_policy_document" "task_execution_permissions" {
  statement {
    effect = "Allow"

    resources = [
      "*",
    ]

    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]
  }
}

# role for ecs to create the instance
resource "aws_iam_role" "execution" {
  name               = "${var.resource_prefix}-airflow-task-execution-role-${var.resource_suffix}"
  assume_role_policy = data.aws_iam_policy_document.task_assume.json

  tags = local.common_tags
}

# role for the airflow instance itself
resource "aws_iam_role" "task" {
  name               = "${var.resource_prefix}-airflow-task-role-${var.resource_suffix}"
  assume_role_policy = data.aws_iam_policy_document.task_assume.json

  tags = local.common_tags
}

resource "aws_iam_role_policy" "task_execution" {
  name   = "${var.resource_prefix}-airflow-task-execution-${var.resource_suffix}"
  role   = aws_iam_role.execution.id
  policy = data.aws_iam_policy_document.task_execution_permissions.json
}

resource "aws_iam_role_policy" "log_agent" {
  name   = "${var.resource_prefix}-airflow-log-permissions-${var.resource_suffix}"
  role   = aws_iam_role.task.id
  policy = data.aws_iam_policy_document.task_permissions.json
}

# airflow cicd lambda role
data "aws_iam_policy_document" "lambda_assume" {
  count = var.cicd_lambda ? 1 : 0

  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "airflow_cicd_lambda_permissions" {
  count = var.cicd_lambda ? 1 : 0

  // to run the lambda in a vpc subnet
  statement {
    effect = "Allow"

    resources = [
      "*",
    ]

    actions = [
      "ec2:DescribeNetworkInterfaces",
      "ec2:CreateNetworkInterface",
      "ec2:DeleteNetworkInterface",
      "ec2:DescribeInstances",
      "ec2:AttachNetworkInterface"
    ]
  }

  // to create logs
  statement {
    effect = "Allow"

    resources = [
      "*",
    ]

    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]
  }

  // to get the private ip of the ecs task
  statement {
    effect = "Allow"

    resources = [
      aws_ecs_cluster.airflow.arn,
      "${replace(aws_ecs_cluster.airflow.arn, ":cluster/", ":task/")}/*"
    ]

    actions = [
      "ecs:Describe*",
      "ecs:List*"
    ]
  }

  // the list_tasks from boto3 ecs needs this otherwise it will not work
  // the error you get: lambda is not authorized to perform: ecs:ListTasks on resource: *
  // even if we provide a specific cluster arn...
  statement {
    effect = "Allow"

    resources = [
      "*"
    ]

    actions = [
      "ecs:ListTasks"
    ]
  }
}

resource "aws_iam_role" "cicd_lambda" {
  count = var.cicd_lambda ? 1 : 0

  name               = "${var.resource_prefix}-airflow-cicd-lambda-${var.resource_suffix}"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume[0].json

  tags = local.common_tags
}

resource "aws_iam_role_policy" "cicd_lambda" {
  count = var.cicd_lambda ? 1 : 0

  name   = "${var.resource_prefix}-airflow-cicd-lambda-permissions-${var.resource_suffix}"
  role   = aws_iam_role.cicd_lambda[0].id
  policy = data.aws_iam_policy_document.airflow_cicd_lambda_permissions[0].json
}