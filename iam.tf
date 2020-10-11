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
  name               = "airflow-task-execution-role"
  assume_role_policy = data.aws_iam_policy_document.task_assume.json

  tags = {
    name = "airflow"
  }
}

# role for the airflow instance itself
resource "aws_iam_role" "task" {
  name               = "airflow-task-role"
  assume_role_policy = data.aws_iam_policy_document.task_assume.json

  tags = {
    name = "airflow"
  }
}

resource "aws_iam_role_policy" "task_execution" {
  name   = "airflow-task-execution"
  role   = aws_iam_role.execution.id
  policy = data.aws_iam_policy_document.task_execution_permissions.json
}

resource "aws_iam_role_policy" "log_agent" {
  name   = "airflow-log-permissions"
  role   = aws_iam_role.task.id
  policy = data.aws_iam_policy_document.task_permissions.json
}
