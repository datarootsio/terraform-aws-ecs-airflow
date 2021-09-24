terraform {
  required_version = "~> 0.15"
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

    use_https = false

    airflow_executor = "Local"
    airflow_py_requirements_path = "./requirements.txt"
    airflow_variables = {
      AIRFLOW__WEBSERVER__NAVBAR_COLOR : "#e27d60"
    }

    rds_username            = "airflow"
    rds_password            = "super-secret-pass"
    rds_availability_zone   = "eu-west-1a"
    rds_deletion_protection = false
}

output "airflow_alb_dns" {
  value = module.airflow.airflow_alb_dns
}
