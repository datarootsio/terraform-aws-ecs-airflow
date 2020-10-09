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

variable "ecs_cluster_name" {
  type        = string
  description = "The name of the ecs cluster, this name will also be the log group"
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

