resource "aws_s3_bucket" "my_super_bucket" {
  bucket = "${var.name}-this-is-a-blueprint"
  acl    = "private"
  tags = {
    "Usage"    = "blueprint"
    "Name"     = var.name
    "ExtraTag" = var.extra_tag
  }
}