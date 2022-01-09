data "aws_iam_policy_document" "datasync_assume_role" {
  statement {
    actions = ["sts:AssumeRole",]
    principals {
      identifiers = ["datasync.amazonaws.com"]
      type        = "Service"
    }
  }
}

data "aws_iam_policy_document" "bucket_access" {
  statement {
    actions = ["s3:*",]
    resources = [
      "${aws_s3_bucket.airflow[0].arn}",
      "${aws_s3_bucket.airflow[0].arn}:/*",
    ]
  }
}