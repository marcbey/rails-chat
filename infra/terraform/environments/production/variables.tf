variable "aws_region" {
  type    = string
  default = "eu-central-1"
}

variable "name_prefix" {
  type    = string
  default = "rails-chat-production"
}

variable "vpc_cidr" {
  type    = string
  default = "10.40.0.0/16"
}

variable "public_subnet_cidrs" {
  type    = list(string)
  default = ["10.40.1.0/24", "10.40.2.0/24"]
}

variable "private_subnet_cidrs" {
  type    = list(string)
  default = ["10.40.101.0/24", "10.40.102.0/24"]
}

variable "web_instance_type" {
  type    = string
  default = "t3.small"
}

variable "web_host_count" {
  type    = number
  default = 2
}

variable "db_instance_class" {
  type    = string
  default = "db.t4g.micro"
}

variable "db_allocated_storage" {
  type    = number
  default = 20
}

variable "db_max_allocated_storage" {
  type    = number
  default = 100
}

variable "db_engine_version" {
  type    = string
  default = "18"
}

variable "db_name" {
  type    = string
  default = "postgres"
}

variable "db_username" {
  type    = string
  default = "postgres"
}

variable "ssh_public_key" {
  type = string
}

variable "ssh_ingress_cidrs" {
  type    = list(string)
  default = []
}

variable "github_repo" {
  type    = string
  default = "marcbey/rails-chat"
}

variable "aws_account_id" {
  type = string
}

variable "public_hostname" {
  type = string
}

variable "acm_certificate_arn" {
  type = string
}
