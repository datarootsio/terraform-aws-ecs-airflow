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
    source = "datarootsio/ecs-airflow/aws"

    resource_prefix = "my-awesome-company"
    resource_suffix = "env"

    vpc_id             = "vpc-123456"
    public_subnet_ids  = ["subnet-456789", "subnet-098765"]

    airflow_executor = "Sequential"

    use_https = false
}

output "airflow_alb_dns" {
  value = module.airflow.airflow_alb_dns
}