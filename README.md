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

### Login in Development

Beim Seeding wird automatisch ein Demo-User angelegt:

- Username: `demo`
- Passwort: `password123!`

Du kannst die Werte mit `SEED_USERNAME` und `SEED_PASSWORD` überschreiben.

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
- Jobs im Web-Prozess: `:async` (kein Solid Queue Supervisor in Puma)
- Ingress (AWS): ALB -> kamal-proxy -> Puma

## Auth & Bot

- Authentifizierung mit Rails-Standardgenerator (Session-basiert).
- Login über `username + password`.
- Registrierung über `/registration/new`.
- Passwort-Reset über `/passwords/new` (E-Mail-Link).
- Account-Seite unter `/account` mit:
  - `username`
  - `email_address`
  - `password`
  - `bot_character`
- Nachrichten-Autor wird serverseitig aus `current_user.username` gesetzt.
- Bot-Antworten sind pro User und pro Chat-Raum ein-/ausschaltbar.
- Bot-Trigger hängt von Raumgröße und Mention ab (siehe Matrix unten).
- Bot-Streaming läuft browserseitig in Echtzeit über OpenAI Realtime API und streamt Tokens live in das Message-Formular, danach Auto-Submit.

Benötigte ENV-Variablen:

- `OPENAI_API_KEY`
- `OPENAI_REALTIME_MODEL` (Default: `gpt-realtime-mini`)

Für Passwort-Reset in Staging/Production:

- `APP_HOST` (wird im Deploy-Workflow automatisch gesetzt)
- funktionierende Mailer-Konfiguration (SMTP/Provider)

### Bot Trigger-Regeln

| Bedingung | Ergebnis |
| --- | --- |
| Bot im Raum deaktiviert | Keine automatische Antwort |
| Bot aktiviert, Raum mit genau 2 Teilnehmern | Bot antwortet auf jede eingehende Nachricht des anderen Teilnehmers (kein `@username` nötig) |
| Bot aktiviert, Raum mit 3+ Teilnehmern | Bot antwortet nur auf Nachrichten mit `@username`-Mention |
| Nachricht stammt vom selben User | Keine automatische Selbst-Antwort |

### Realtime Ablauf (Kurz)

1. Browser erkennt eine neue eingehende Chat-Nachricht per DOM-Mutation (Turbo Stream Update).
2. Stimulus-Controller prüft Bot-Status und Trigger-Regel (2er-Raum vs. Mention).
3. Browser holt über `POST /chat_rooms/:chat_room_id/bot_reply_session` ein kurzlebiges OpenAI Realtime Client Secret.
4. Browser baut WebRTC Data-Channel zu OpenAI Realtime auf und sendet Prompt + Kontext.
5. Token-Streams werden live in das Nachrichten-Formular geschrieben.
6. Nach `response.completed` wird das Formular automatisch abgeschickt.

### OpenAI Key nach Umgebung bereitstellen

`develop` (lokal):

```bash
cp .env.example .env
echo 'OPENAI_API_KEY=YOUR_KEY' >> .env
echo 'OPENAI_REALTIME_MODEL=gpt-realtime-mini' >> .env
```

`staging` und `production` (GitHub Environments):

```bash
gh secret set OPENAI_API_KEY_STAGING --env staging --body "$OPENAI_API_KEY"
gh secret set OPENAI_API_KEY_PRODUCTION --env production --body "$OPENAI_API_KEY"
```

Hinweise:

- API Keys niemals im Repository speichern.
- Deploy-Workflows schreiben `OPENAI_API_KEY` zur Laufzeit in `.kamal/secrets-common`.
- Staging deployt automatisch bei Push auf `main`; Production manuell.

### Bot Troubleshooting

- `403 Forbidden` bei `bot_reply_session`: Bot ist im aktuellen Raum für den User deaktiviert.
- `503 Missing OPENAI_API_KEY configuration`: Key ist in der Zielumgebung nicht gesetzt.
- `502 Failed to initialize realtime bot session`: OpenAI-Realtime-Init fehlgeschlagen (Upstream/Key/Model prüfen).
- Bot antwortet in Gruppenraum nicht: Nachricht enthält kein `@username`.
- Bot antwortet in 2er-Raum nicht: Prüfen, ob wirklich genau zwei Mitgliedschaften für den Raum bestehen.

## Tests und Qualität

```bash
mise exec -- bundle exec rspec
mise exec -- bundle exec rubocop
mise exec -- bundle exec brakeman --no-pager
mise exec -- bundle exec bundler-audit check --update
```

Gezielte Testläufe:

```bash
mise exec -- bundle exec rspec spec/requests/chat_room_bot_reply_sessions_spec.rb
mise exec -- bundle exec rspec spec/requests/chat_messages_spec.rb
mise exec -- bundle exec rspec spec/models/chat_message_spec.rb
```

## GitHub Actions

Workflows:

- `.github/workflows/ci.yml`
- `.github/workflows/deploy-staging.yml`
- `.github/workflows/deploy-production.yml`
- `.github/workflows/terraform-plan.yml`

Deploy-Verhalten:

- `staging`: automatisch bei jedem Push auf `main`
- `production`: manuell per `workflow_dispatch`

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
- `OPENAI_API_KEY_STAGING`
- `OPENAI_API_KEY_PRODUCTION`

Hinweis: `KAMAL_REGISTRY_PASSWORD` wird zur Laufzeit aus AWS ECR geholt und ist kein statisches Secret.
Hinweis: `KAMAL_SSH_KNOWN_HOSTS`, `ALLOWED_HOSTS` und `ALLOWED_CABLE_ORIGINS` werden in den Deploy-Workflows automatisch aus AWS-Ressourcen ermittelt.

Environment `staging`:

- `AWS_ROLE_ARN`
- `ECR_IMAGE_NAME`

Environment `production`:

- `AWS_ROLE_ARN`
- `ECR_IMAGE_NAME`

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

Hinweis: `ssh_ingress_cidrs` ist standardmäßig leer. Für SSH/Kamal muss explizit mindestens ein erlaubter CIDR gesetzt werden.

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
