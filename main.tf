terraform {
  required_version = ">= 0.12.26"

  required_providers {
    aws      = "~> 3.74"
    template = ">= 2.0"
  }
}

data "aws_caller_identity" "current" {}