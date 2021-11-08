provider "aws" {
  region = var.region
}

data "aws_caller_identity" "this" {}

terraform {
  required_version = "~> 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.64"
    }
  }
}
