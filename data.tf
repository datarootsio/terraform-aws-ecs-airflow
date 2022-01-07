data "aws_iam_policy_document" "datasync_assume_role" {
  statement {
    actions = ["sts:AssumeRole",]
    principals {
      identifiers = ["datasync.amazonaws.com"]
      type        = "Service"
    }
  }
}