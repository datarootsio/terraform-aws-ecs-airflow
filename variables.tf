variable "airflow_image_name" {
  type        = string
  description = "The name of the airflow image"
  default     = "puckel/docker-airflow"
}

variable "airflow_image_tag" {
  type        = string
  description = "The tag of the airflow image"
  default     = "1.10.9"
}

variable "airflow_log_region" {
  type        = string
  description = "The region you want your airflow logs in"
}

variable "airflow_log_retention" {
  type        = number
  description = "The number of days you want to keep the log of airflow container"
  default     = 7
}

variable "airflow_navbar_color" {
  type        = string
  description = "The color of the airflow navbar; good way to distinguish your dev/stag/prod airflow"
  default     = "#007A87"
}

variable "ecs_cluster_name" {
  type        = string
  description = "The name of the ecs cluster, this name will also be the log group"
}

variable "ecs_cpu" {
  type        = number
  description = "The allocated cpu for your airflow instance"
  default     = 256
}

variable "ecs_memory" {
  type        = number
  description = "The allocated memory for your airflow instance"
  default     = 512
}

variable "vpc_id" {
  type        = string
  description = "The id of the vpc where you will run ecs/rds"
}

variable "subnet_id" {
  type        = string
  description = "The id of the subnet where you will run ecs/rds"
}

variable "rds_instance_class" {
  type        = string
  description = "The class of instance you want to give to your rds db"
  default     = "db.t2.micro"
}

