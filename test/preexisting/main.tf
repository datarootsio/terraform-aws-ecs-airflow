variable "rds_name" {
  type = string
}

variable "region" {
  type        = string
  description = "The region to deploy your solution to"
  default     = "eu-west-1"
}

variable "resource_prefix" {
  type        = string
  description = "A prefix for the create resources, example your company name (be aware of the resource name length)"
}

variable "resource_suffix" {
  type        = string
  description = "A suffix for the created resources, example the environment for airflow to run in (be aware of the resource name length)"
}

variable "extra_tags" {
  description = "Extra tags that you would like to add to all created resources"
  type        = map(string)
  default     = {}
}

variable "vpc_id" {
  type        = string
  description = "The id of the vpc where you will run ecs/rds"

  validation {
    condition     = can(regex("^vpc-", var.vpc_id))
    error_message = "The vpc_id value must be a valid VPC id, starting with \"vpc-\"."
  }
}

variable "public_subnet_ids" {
  type        = list(string)
  description = "A list of subnet ids of where the ALB will reside, if the \"private_subnet_ids\" variable is not provided ECS and RDS will also reside in these subnets"

  validation {
    condition     = length(var.public_subnet_ids) >= 2
    error_message = "The size of the list \"public_subnet_ids\" must be at least 2."
  }
}

variable "private_subnet_ids" {
  type        = list(string)
  description = "A list of subnet ids of where the ECS and RDS reside, this will only work if you have a NAT Gateway in your VPC"
  default     = []

  validation {
    condition     = length(var.private_subnet_ids) >= 2 || length(var.private_subnet_ids) == 0
    error_message = "The size of the list \"private_subnet_ids\" must be at least 2 or empty."
  }
}

variable "route53_zone_name" {
  type        = string
  description = "The name of a Route53 zone that will be used for the certificate validation."
  default     = ""
}

locals {
  own_tags = {
    Name      = "${var.resource_prefix}-airflow-${var.resource_suffix}"
    CreatedBy = "Terraform"
    Module    = "terraform-aws-ecs-airflow"
  }
  common_tags = merge(local.own_tags, var.extra_tags)

  timestamp_sanitized = replace(timestamp(), "/[- TZ:]/", "")

  rds_ecs_subnet_ids = length(var.private_subnet_ids) == 0 ? var.public_subnet_ids : var.private_subnet_ids
  dns_record         = "${var.resource_prefix}-airflow-${var.resource_suffix}.${data.aws_route53_zone.zone.name}"
}

terraform {
  required_version = "~> 0.13"
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
}

provider "aws" {
  version = "~> 3.12.0"
  region  = var.region
}

resource "aws_security_group" "rds" {
  vpc_id      = var.vpc_id
  name        = "${var.resource_prefix}-rds-${var.resource_suffix}"
  description = "Security group for the RDS"

  egress {
    description = "Allow all traffic out"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow PostgreSQL traffic in"
    from_port   = 5432
    to_port     = 5432
    protocol    = "TCP"
    cidr_blocks = ["10.150.0.0/16"]
  }

  tags = local.common_tags

}

resource "aws_db_instance" "airflow" {
  name                      = replace(title(var.rds_name), "-", "")
  allocated_storage         = 20
  storage_type              = "standard"
  engine                    = "postgres"
  engine_version            = "11.8"
  instance_class            = "db.t2.micro"
  username                  = "dataroots"
  password                  = "dataroots"
  multi_az                  = false
  availability_zone         = "eu-west-1a"
  publicly_accessible       = false
  deletion_protection       = false
  final_snapshot_identifier = "airflow-final-snapshot-${local.timestamp_sanitized}"
  identifier                = var.rds_name
  vpc_security_group_ids    = [aws_security_group.rds.id]
  db_subnet_group_name      = aws_db_subnet_group.airflow.name

  tags = local.common_tags
}

resource "aws_db_subnet_group" "airflow" {
  name       = "${var.resource_prefix}-airflow-${var.resource_suffix}"
  subnet_ids = local.rds_ecs_subnet_ids

  tags = local.common_tags
}

data "aws_route53_zone" "zone" {
  name = var.route53_zone_name
}

resource "aws_route53_record" "validation" {
  for_each = {
    for dvo in aws_acm_certificate.cert.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = data.aws_route53_zone.zone.zone_id
}

resource "aws_acm_certificate" "cert" {
  domain_name       = local.dns_record
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = local.common_tags
}

resource "aws_acm_certificate_validation" "cert" {
  certificate_arn         = aws_acm_certificate.cert.arn
  validation_record_fqdns = [for record in aws_route53_record.validation : record.fqdn]
}

output "certificate_arn" {
  value = aws_acm_certificate.cert.arn
}

output "postgres_uri" {
  value = "${aws_db_instance.airflow.address}:${aws_db_instance.airflow.port}/${aws_db_instance.airflow.name}"
}