variable "name_prefix" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "ssh_ingress_cidrs" {
  type    = list(string)
  default = []
}
