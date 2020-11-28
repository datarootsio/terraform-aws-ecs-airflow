terraform {
  required_version = "~> 0.13"
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
    archive = {
      source = "hashicorp/archive"
    }
  }
}

provider "aws" {
  version = "~> 3.12.0"
  region  = var.region
}

provider "archive" {
  version = "~> 2.0.0"
}