locals {
  github_oidc_provider_arn = "arn:aws:iam::${var.aws_account_id}:oidc-provider/token.actions.githubusercontent.com"
}

module "network" {
  source               = "../../modules/network"
  name_prefix          = var.name_prefix
  vpc_cidr             = var.vpc_cidr
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
}

module "security" {
  source      = "../../modules/security"
  name_prefix = var.name_prefix
  vpc_id      = module.network.vpc_id
}

module "load_balancer" {
  source            = "../../modules/load_balancer"
  name_prefix       = var.name_prefix
  vpc_id            = module.network.vpc_id
  public_subnet_ids = module.network.public_subnet_ids
  alb_sg_id         = module.security.alb_sg_id
}

module "compute" {
  source            = "../../modules/compute"
  name_prefix       = var.name_prefix
  instance_type     = var.web_instance_type
  host_count        = var.web_host_count
  public_subnet_ids = module.network.public_subnet_ids
  web_sg_id         = module.security.web_sg_id
  target_group_arn  = module.load_balancer.target_group_arn
  ssh_public_key    = var.ssh_public_key
}

module "database" {
  source                = "../../modules/database"
  name_prefix           = var.name_prefix
  private_subnet_ids    = module.network.private_subnet_ids
  db_sg_id              = module.security.db_sg_id
  engine_version        = var.db_engine_version
  instance_class        = var.db_instance_class
  allocated_storage     = var.db_allocated_storage
  max_allocated_storage = var.db_max_allocated_storage
  db_name               = var.db_name
  db_username           = var.db_username
}

module "container_registry" {
  source      = "../../modules/container_registry"
  name_prefix = var.name_prefix
}

module "iam" {
  source                   = "../../modules/iam"
  name_prefix              = var.name_prefix
  github_repo              = var.github_repo
  github_oidc_provider_arn = local.github_oidc_provider_arn
}

module "observability" {
  source      = "../../modules/observability"
  name_prefix = var.name_prefix
}
