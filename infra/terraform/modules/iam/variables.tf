variable "name_prefix" {
  type = string
}

variable "github_repo" {
  type = string
}

variable "github_oidc_provider_arn" {
  type = string
}

variable "allowed_github_subs" {
  type = list(string)
}
