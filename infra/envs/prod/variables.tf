variable "region" {
  type    = string
  default = "ap-south-1"
}

variable "vpc_cidr" {
  type = string
}

variable "azs" {
  type = list(string)
}

variable "ecs_cpu" {
  type = number
}

variable "ecs_memory" {
  type = number
}

variable "ecs_desired_count" {
  type = number
}

variable "db_instance_class" {
  type = string
}

variable "db_allocated_storage" {
  type = number
}

variable "db_backup_retention" {
  type = number
}

variable "db_deletion_protection" {
  type = bool
}

variable "db_password" {
  type      = string
  sensitive = true
  default   = "YOUR_DB_PASSWORD"
}
