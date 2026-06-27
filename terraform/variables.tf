variable "environment" {
  description = "Deployment environment name"
  type        = string
  default     = "staging"
}

variable "aws_region" {
  description = "AWS region for staging resources"
  type        = string
  default     = "us-east-1"
}

variable "project" {
  description = "Resource naming prefix"
  type        = string
  default     = "raphael"
}

variable "db_instance_class" {
  description = "RDS instance class for Postgres"
  type        = string
  default     = "db.t4g.micro"
}

variable "db_allocated_storage_gb" {
  description = "RDS allocated storage in GB"
  type        = number
  default     = 20
}

variable "db_username" {
  description = "Postgres master username"
  type        = string
  default     = "raphael"
}

variable "db_name" {
  description = "Initial database name"
  type        = string
  default     = "raphael"
}

variable "gateway_desired_count" {
  description = "Desired ECS tasks for raphael-core"
  type        = number
  default     = 1
}

variable "core_service_desired_count" {
  description = "Desired ECS tasks per core domain service"
  type        = number
  default     = 1
}
