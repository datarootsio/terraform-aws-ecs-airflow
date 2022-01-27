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
  statement {
    effect = "Allow"

    resources = [
      "arn:aws:ssm:${var.region}:${data.aws_caller_identity.this.account_id}:parameter/${var.resource_suffix}/airflow/fernet_key",
    ]

    actions = [
      "ssm:GetParametersByPath",
      "ssm:GetParameters",
      "ssm:GetParameter"
    ]
  }
}

data "aws_iam_policy_document" "ecs_exec" {
  count = var.enable_ecs_execute_command ? 1 : 0

  # This policy is required to allow use of the ecs-exec command, to execute
  # commands on running fargate tasks - similar to `docker exec` functionality
  # https://docs.aws.amazon.com/AmazonECS/latest/developerguide/ecs-exec.html
  statement {
    sid    = "AllowExecWithSSM"
    effect = "Allow"
    actions = [
      "ssmmessages:CreateControlChannel",
      "ssmmessages:CreateDataChannel",
      "ssmmessages:OpenControlChannel",
      "ssmmessages:OpenDataChannel"
    ]
    resources = ["*"]
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

resource "aws_iam_role_policy" "ecs_exec" {
  name   = "ecs-exec"
  policy = data.aws_iam_policy_document.ecs_exec.json
  role   = aws_iam_role.task.name
}
