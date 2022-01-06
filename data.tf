data "aws_s3_bucket" "s3_location" {
  bucket = "${var.s3_bucket_name}"
}