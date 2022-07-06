terraform {
  required_version = "> 0.15"
  required_providers {
    aws = {
      version      = ">= 2.48"
    }
  }
}

data "aws_caller_identity" "current" {}