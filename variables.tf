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

// Airflow variables
variable "airflow_image_name" {
  type        = string
  description = "The name of the airflow image"
  default     = "apache/airflow"
}

variable "airflow_image_tag" {
  type        = string
  description = "The tag of the airflow image"
  default     = "2.0.1"
}

variable "airflow_executor" {
  type        = string
  description = "The executor mode that airflow will use. Only allowed values are [\"Local\", \"Sequential\"]. \"Local\": Run DAGs in parallel (will created a RDS); \"Sequential\": You can not run DAGs in parallel (will NOT created a RDS);"
  default     = "Local"

  validation {
    condition     = contains(["Local", "Sequential"], var.airflow_executor)
    error_message = "The only values that are allowed for \"airflow_executor\" are [\"Local\", \"Sequential\"]."
  }
}

variable "airflow_authentication" {
  type        = string
  description = "Authentication backend to be used, supported backends [\"\", \"rbac\"]. When \"rbac\" is selected an admin role is create if there are no other users in the db, from here you can create all the other users. Make sure to change the admin password directly upon first login! (if you don't change the rbac_admin options the default login is => username: admin, password: admin)"
  default     = ""

  validation {
    condition     = contains(["", "rbac"], var.airflow_authentication)
    error_message = "The only values that are allowed for \"airflow_executor\" are [\"\", \"rbac\"]."
  }
}

variable "airflow_py_requirements_path" {
  type        = string
  description = "The relative path to a python requirements.txt file to install extra packages in the container that you can use in your DAGs."
  default     = ""
}

variable "airflow_variables" {
  type        = map(string)
  description = "The variables passed to airflow as an environment variable (see airflow docs for more info https://airflow.apache.org/docs/). You can not specify \"AIRFLOW__CORE__SQL_ALCHEMY_CONN\" and \"AIRFLOW__CORE__EXECUTOR\" (managed by this module)"
  default     = {}
}

variable "airflow_container_home" {
  type        = string
  description = "Working dir for airflow (only change if you are using a different image)"
  default     = "/opt/airflow"
}

variable "airflow_log_region" {
  type        = string
  description = "The region you want your airflow logs in, defaults to the region variable"
  default     = ""
}

variable "airflow_log_retention" {
  type        = string
  description = "The number of days you want to keep the log of airflow container"
  default     = "7"
}

variable "airflow_example_dag" {
  type        = bool
  description = "Add an example dag on startup (mostly for sanity check)"
  default     = true
}

// RBAC
variable "rbac_admin_username" {
  type        = string
  description = "RBAC Username (only when airflow_authentication = 'rbac')"
  default     = "admin"
}

variable "rbac_admin_password" {
  type        = string
  description = "RBAC Password (only when airflow_authentication = 'rbac')"
  default     = "admin"
}

variable "rbac_admin_email" {
  type        = string
  description = "RBAC Email (only when airflow_authentication = 'rbac')"
  default     = "admin@admin.com"
}

variable "rbac_admin_firstname" {
  type        = string
  description = "RBAC Firstname (only when airflow_authentication = 'rbac')"
  default     = "admin"
}

variable "rbac_admin_lastname" {
  type        = string
  description = "RBAC Lastname (only when airflow_authentication = 'rbac')"
  default     = "airflow"
}

// ECS variables
variable "ecs_cpu" {
  type        = number
  description = "The allocated cpu for your airflow instance"
  default     = 1024
}

variable "ecs_memory" {
  type        = number
  description = "The allocated memory for your airflow instance"
  default     = 2048
}

// Networking variables
variable "ip_allow_list" {
  type        = list(string)
  description = "A list of ip ranges that are allowed to access the airflow webserver, default: full access"
  default     = ["0.0.0.0/0"]
}

variable "vpc_id" {
  type        = string
  description = "The id of the vpc where you will run ECS/RDS"

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

// ACM + Route53
variable "use_https" {
  type        = bool
  description = "Expose traffic using HTTPS or not"
  default     = false
}

variable "dns_name" {
  type        = string
  description = "The DNS name that will be used to expose Airflow. Optional if not serving over HTTPS. Will be autogenerated if not provided"
  default     = ""
}

variable "certificate_arn" {
  type        = string
  description = "The ARN of the certificate that will be used"
  default     = ""
}

variable "route53_zone_name" {
  type        = string
  description = "The name of a Route53 zone that will be used for the certificate validation."
  default     = ""
}


// Database variables
variable "postgres_uri" {
  type        = string
  description = "The postgres uri of your postgres db, if none provided a postgres db in rds is made. Format \"<db_username>:<db_password>@<db_endpoint>:<db_port>/<db_name>\""
  default     = ""
}

variable "rds_allocated_storage" {
  type        = number
  description = "The allocated storage for the rds db in gibibytes"
  default     = 20
}

variable "rds_storage_type" {
  type        = string
  description = <<EOT
  One of `"standard"` (magnetic), `"gp2"` (general purpose SSD), or `"io1"` (provisioned IOPS SSD)
  EOT
  default     = "standard"
}

variable "rds_engine" {
  type        = string
  description = <<EOT
  The database engine to use. For supported values, see the Engine parameter in [API action CreateDBInstance](https://docs.aws.amazon.com/AmazonRDS/latest/APIReference/API_CreateDBInstance.html)
  EOT
  default     = "postgres"
}

variable "rds_username" {
  type        = string
  description = "Username of rds"
  default     = "airflow"
}

variable "rds_password" {
  type        = string
  description = "Password of rds"
  default     = ""
}

variable "rds_instance_class" {
  type        = string
  description = "The class of instance you want to give to your rds db"
  default     = "db.t2.micro"
}

variable "rds_availability_zone" {
  type        = string
  description = "Availability zone for the rds instance"
  default     = "eu-west-1a"
}

variable "rds_skip_final_snapshot" {
  type        = bool
  description = "Whether or not to skip the final snapshot before deleting (mainly for tests)"
  default     = false
}

variable "rds_deletion_protection" {
  type        = bool
  description = "Deletion protection for the rds instance"
  default     = false
}

variable "rds_version" {
  type        = string
  description = "The DB version to use for the RDS instance"
  default     = "12.7"
}

// S3 Bucket
variable "s3_bucket_name" {
  type        = string
  default     = ""
  description = "The S3 bucket name where the DAGs and startup scripts will be stored, leave this blank to let this module create a s3 bucket for you. WARNING: this module will put files into the path \"dags/\" and \"startup/\" of the bucket"
}
