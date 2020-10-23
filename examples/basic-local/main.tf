terraform {
  required_version = "~> 0.13"
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
}

provider "aws" {
  region = "eu-west-1"
}

module "airflow" {
    source = "datarootsio/aws-airflow/module/"

    resource_prefix = "my-awesome-company"
    resource_suffix = "env"

    vpc_id             = "vpc-123456"
    public_subnet_ids  = ["subnet-456789", "subnet-098765"]

    use_https = false

    rds_username            = "dataroots"
    rds_password            = "dataroots"
    rds_availability_zone   = "eu-west-1a"
    rds_deletion_protection = false
}

output "airflow_alb_dns" {
  value = module.airflow.airflow_alb_dns
}