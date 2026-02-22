# Rails Chat

Realtime Chat App mit Ruby on Rails 8.1.2, Ruby 4.0.1, Hotwire/Turbo, Tailwind CSS, Terraform (AWS) und Kamal.

## Voraussetzungen

- `mise`
- Docker + Docker Compose
- AWS CLI v2 (SSO Profil vorhanden, z. B. `rails-chat`)
- Terraform >= 1.7
- GitHub Repository + Secrets

## Lokale Entwicklung (ohne Docker)

```bash
mise install
mise exec -- bundle install
mise exec -- bin/rails db:prepare
mise exec -- bin/dev
```

App läuft dann auf [http://localhost:3000](http://localhost:3000).

## Lokale Entwicklung (mit Docker)

1. `.env.example` kopieren und bei Bedarf anpassen.
2. Starten:

```bash
bin/docker-dev up
```

3. Datenbank vorbereiten:

```bash
bin/docker-dev dbprepare
```

4. Tests ausführen:

```bash
bin/docker-dev rspec
```

## Architektur

- Web: Rails App (Puma + Turbo + Action Cable)
- DB: PostgreSQL 18
- Realtime: Solid Cable (DB-basiert)
- Ingress (AWS): ALB -> kamal-proxy -> Puma

## Tests und Qualität

```bash
mise exec -- bundle exec rspec
mise exec -- bundle exec rubocop
mise exec -- bundle exec brakeman --no-pager
mise exec -- bundle exec bundler-audit check --update
```

## GitHub Actions

Workflows:

- `.github/workflows/ci.yml`
- `.github/workflows/deploy-staging.yml`
- `.github/workflows/deploy-production.yml`
- `.github/workflows/terraform-plan.yml`

Erwartete GitHub Secrets:

- `AWS_REGION` (`eu-central-1`)
- `ECR_REGISTRY`
- `KAMAL_SSH_PRIVATE_KEY`
- `RAILS_MASTER_KEY_STAGING`
- `RAILS_MASTER_KEY_PRODUCTION`
- `DATABASE_URL_STAGING`
- `DATABASE_URL_PRODUCTION`
- `SECRET_KEY_BASE_STAGING`
- `SECRET_KEY_BASE_PRODUCTION`

Environment `staging`:

- `AWS_ROLE_ARN`
- `ECR_IMAGE_NAME`
- `STAGING_WEB_HOSTS`

Environment `production`:

- `AWS_ROLE_ARN`
- `ECR_IMAGE_NAME`
- `PRODUCTION_WEB_HOSTS`

## Terraform

### State Bootstrap

```bash
cd infra/terraform/bootstrap
terraform init
terraform apply -var='state_bucket_name=rails-chat-terraform-state' -var='aws_region=eu-central-1'
```

### Staging

```bash
cd infra/terraform/environments/staging
cp terraform.tfvars.example terraform.tfvars
terraform init -backend-config=backend.hcl.example
terraform plan
```

### Production

```bash
cd infra/terraform/environments/production
cp terraform.tfvars.example terraform.tfvars
terraform init -backend-config=backend.hcl.example
terraform plan
```

Hinweis: In diesem Projekt ist `terraform apply` bewusst noch nicht automatisiert.

## Kamal Deploy

- Basisconfig: `config/deploy.yml`
- Staging: `config/deploy.staging.yml`
- Production: `config/deploy.production.yml`

Deploy lokal (nur wenn Hosts/Secrets gesetzt sind):

```bash
KAMAL_WEB_HOSTS=1.2.3.4,5.6.7.8 \
ECR_REGISTRY=xxx.dkr.ecr.eu-central-1.amazonaws.com \
ECR_IMAGE_NAME=rails-chat-staging/rails-chat \
KAMAL_REGISTRY_PASSWORD=... \
RAILS_MASTER_KEY=... \
DATABASE_URL=... \
SECRET_KEY_BASE=... \
bundle exec kamal deploy -d staging
```

## Status

Die Umsetzungsplanung steht in `PLAN.md`.
