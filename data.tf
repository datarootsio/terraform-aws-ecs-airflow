data "aws_iam_policy_document" "datasync_assume_role" {
  statement {
    actions = ["sts:AssumeRole",]
    principals {
      identifiers = ["datasync.amazonaws.com"]
      type        = "Service"
    }
  }
}

data "aws_iam_policy_document" "override" {
  statement {
    sid = "SidToOverride"

    actions   = ["s3:*"]
    resources = ["*"]
  }
}

data "aws_iam_policy_document" "allow_access_from_another_account" {
    source_json = data.aws_iam_policy_document.override.json

    statement {
        actions   = ["datasync:*"]
        resources = ["*"]
    }

    statement {
        sid = "SidToOverride"

        actions = ["s3:*"]

        resources = [
            "arn:aws:s3:::am-base-airflow-shared",
            "arn:aws:s3:::am-base-airflow-shared/*",
        ]
    }
}