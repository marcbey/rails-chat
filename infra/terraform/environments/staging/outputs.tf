output "alb_dns_name" {
  value = module.load_balancer.alb_dns_name
}

output "db_endpoint" {
  value = module.database.db_endpoint
}

output "db_password_secret_arn" {
  value = module.database.db_password_secret_arn
}

output "ecr_repository_url" {
  value = module.container_registry.repository_url
}

output "github_actions_role_arn" {
  value = module.iam.github_actions_role_arn
}
