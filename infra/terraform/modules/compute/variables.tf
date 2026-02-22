variable "name_prefix" {
  type = string
}

variable "instance_type" {
  type = string
}

variable "host_count" {
  type = number
}

variable "public_subnet_ids" {
  type = list(string)
}

variable "web_sg_id" {
  type = string
}

variable "target_group_arn" {
  type = string
}

variable "ssh_public_key" {
  type = string
}
