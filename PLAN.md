# PLAN: Realtime Chat App (Rails 8.1.2 + Ruby 4.0.1)

## 1. Ziel

Eine Realtime-Chat-App ohne Authentifizierung (MVP) mit:

- Ruby `4.0.1` (via `mise`)
- Rails `8.1.2`
- Hotwire (Turbo + Stimulus)
- modernem Tailwind-CSS UI
- Live-Broadcasts für neue Chat-Nachrichten und neue Chat-Räume
- Deployment auf AWS via Kamal
- Infrastruktur als Terraform IaC
- lokale Entwicklung via Docker

## 2. Verbindliche Festlegungen (Freeze)

Diese Entscheidungen sind final und werden ohne weitere Rückfragen umgesetzt:

1. Datenbank: PostgreSQL 18.x (aktueller Major-Release-Zweig, jeweils neuester in RDS verfügbarer 18.x-Patchstand)
2. Umgebungen: `staging` und `production`
3. AWS Region: `eu-central-1`
4. Aktuell kein Domain-/SSL-Setup (nur HTTP über ALB)
5. CI/CD über GitHub Actions
6. Test-Stack: RSpec
7. Deployment auf mehreren Hosts
8. Host-Sizing: `staging` = `2 x t3.small`, `production` = `2 x t3.small`
9. `staging` deployt automatisch bei jedem Push auf `main`
10. `production` deployt nur manuell per `workflow_dispatch`
11. Kein verpflichtendes GitHub Environment Approval-Gate
12. Realtime-Backend: `Solid Cable` auf derselben PostgreSQL RDS
13. Ingress: `Internet -> ALB -> kamal-proxy -> Puma`
14. Terraform State: `S3 Backend + DynamoDB Locking` (ein Bucket, getrennte State-Keys)
15. RDS: `Single-AZ`, automatische Backups deaktiviert (Testprojekt-Vorgabe)
16. Lokales Docker-Web startet via `bin/dev`
17. Rails-Stack: `postgresql + importmap + tailwind`
18. Primärschlüssel in Domänenmodellen: UUID

## 3. Zielarchitektur (Service-Split)

### 3.1 Web App Service

- Rails 8.1.2 App mit Puma, Action Cable, Turbo Streams
- Serviert HTML/Turbo Responses und WebSocket-Verbindungen
- Containerisiert (Docker), deployt via Kamal auf mehrere EC2 Hosts
- Läuft hinter einem ALB

### 3.2 Datenbank Service

- AWS RDS PostgreSQL 18.x
- Private Subnetze, nicht öffentlich erreichbar
- `Single-AZ`, automatische Backups deaktiviert
- Hält Domänendaten und Solid-Cable-Daten

### 3.3 Realtime über mehrere Hosts

- Turbo Streams + Action Cable
- zentraler Cable-Backend-Store via `Solid Cable`
- Broadcasts per `after_commit`, damit alle Clients auf allen Hosts Updates erhalten

### 3.4 Ingress-Details

- ALB Listener: `80`
- Target Group: kamal-proxy auf Web-Hosts
- Healthcheck: `GET /up`
- Idle Timeout: `300s`
- Stickiness: `off`

## 4. Repository Blueprint (soll erstellt werden)

- `/app`, `/config`, `/db`, `/lib`, `/spec`
- `/.mise.toml`
- `/Dockerfile`
- `/docker-compose.yml`
- `/docker-compose.test.yml` (optional)
- `/bin/docker-dev`
- `/.env.example`
- `/.github/workflows/ci.yml`
- `/.github/workflows/deploy-staging.yml`
- `/.github/workflows/deploy-production.yml`
- `/config/deploy.yml`
- `/config/deploy.staging.yml`
- `/config/deploy.production.yml`
- `/infra/terraform/bootstrap`
- `/infra/terraform/modules/*`
- `/infra/terraform/environments/staging`
- `/infra/terraform/environments/production`
- `/README.md`
- `/PLAN.md`

## 5. Applikationsdesign (verbindlich)

### 5.1 Domänenmodell

`ChatRoom`

- `id: uuid`
- `name: string, required, unique, length 3..80`
- `slug: string, required, unique`
- `timestamps`
- Callback: `after_create_commit` -> Broadcast zur Room-Liste

`ChatMessage`

- `id: uuid`
- `chat_room_id: uuid, FK, indexed`
- `author_name: string, required, length 2..40`
- `body: text, required, max 2000`
- `timestamps`
- Index: `(chat_room_id, created_at)`
- Callback: `after_create_commit` -> Broadcast in Raum-Message-Liste

### 5.2 Routing

- `root "chat_rooms#index"`
- `resources :chat_rooms, only: [:index, :show, :new, :create] do`
- `resources :chat_messages, only: [:create]`
- `end`

### 5.3 Controller-Verhalten

`ChatRoomsController`

- `index`: Raumliste + Neues-Raum-Form
- `show`: Messages des Raums + Message-Form
- `create`: Turbo Stream + HTML Fallback

`ChatMessagesController`

- `create`: Message speichern + Turbo Stream + HTML Fallback

### 5.4 Hotwire/Turbo Struktur

- `chat_rooms/index`:
- `turbo_stream_from "chat_rooms"`
- Container `id="chat_rooms"`
- `chat_rooms/show`:
- `turbo_stream_from @chat_room, "messages"`
- Container `id="chat_room_<id>_messages"`
- Partials:
- `app/views/chat_rooms/_chat_room.html.erb`
- `app/views/chat_rooms/_form.html.erb`
- `app/views/chat_messages/_chat_message.html.erb`
- `app/views/chat_messages/_form.html.erb`

### 5.5 Solid Cable Konfiguration

- Gem `solid_cable` integrieren
- Cable-Adapter in `config/cable.yml` auf Solid Cable setzen
- Solid-Cable-Tabellen per Migrationen erstellen
- Nutzung derselben RDS-Instanz

### 5.6 Tailwind UI Leitlinie

- Desktop: Zwei-Spalten-Layout (Rooms/Chat)
- Mobile: gestapelte Ansicht mit sticky Header + Composer
- Moderne, klare Optik, hohe Lesbarkeit, klare Focus States
- Keine Auth-UI, nur Chat-Room und Message-Flows

## 6. Lokale Entwicklung via Docker

### 6.1 Services

`web`

- Build aus lokalem Quellcode
- Source-Mount für Live-Entwicklung
- Port `3000:3000`
- Startkommando: `bin/dev`
- Abhängigkeit: `db`

`db`

- Image `postgres:18-alpine`
- Persistentes Volume
- Optional Host-Port `5432`

### 6.2 Standardbefehle

- `docker compose up --build`
- `docker compose run --rm web bin/rails db:prepare`
- `docker compose run --rm web bundle exec rspec`
- `docker compose run --rm web bundle exec rubocop`

## 7. CI/CD mit GitHub Actions

### 7.1 Workflows

- `ci.yml`
- Trigger: `pull_request` auf `main`, `push` auf `main`
- Jobs: `validate`, `lint`, `test`, `security`, `build`

- `deploy-staging.yml`
- Trigger: `push` auf `main`
- Voraussetzung: erfolgreiches `ci.yml` auf gleichem Commit
- Action: Kamal Deploy auf Staging

- `deploy-production.yml`
- Trigger: `workflow_dispatch`
- Action: Kamal Deploy auf Production

### 7.2 CI Job-Inhalte

`validate`

- Ruby/Bundler Setup
- `bundle exec rails zeitwerk:check`
- Terraform `fmt -check` + `validate`

`lint`

- `bundle exec rubocop`

`test`

- PostgreSQL Service Container
- `bin/rails db:prepare`
- `bundle exec rspec`

`security`

- `bundle exec brakeman`
- `bundle exec bundler-audit check --update`

`build`

- Docker Build
- Push nach ECR

### 7.3 GitHub Secrets (verbindliche Namenskonvention)

- `AWS_ROLE_ARN`
- `AWS_REGION` (`eu-central-1`)
- `ECR_REGISTRY`
- `KAMAL_REGISTRY_PASSWORD`
- `RAILS_MASTER_KEY_STAGING`
- `RAILS_MASTER_KEY_PRODUCTION`
- `DATABASE_URL_STAGING`
- `DATABASE_URL_PRODUCTION`
- `SECRET_KEY_BASE_STAGING`
- `SECRET_KEY_BASE_PRODUCTION`

## 8. Terraform IaC Plan (AWS)

### 8.1 Bootstrap (State)

In `infra/terraform/bootstrap` werden einmalig erstellt:

- S3 Bucket für Terraform State
- DynamoDB Tabelle für Locking

### 8.2 Remote State

- S3 Bucket: ein gemeinsamer Bucket
- DynamoDB Locking: eine Tabelle
- State Keys:
- `staging/terraform.tfstate`
- `production/terraform.tfstate`

### 8.3 Zielressourcen je Environment

1. VPC, Subnetze (mind. 2 AZ)
2. Security Groups (ALB, Web, DB)
3. ALB
4. EC2 Web Hosts:
- `staging`: `2 x t3.small`
- `production`: `2 x t3.small`
5. RDS PostgreSQL 18.x (`Single-AZ`, Backups aus)
6. ECR Repository
7. IAM Rollen/Policies
8. CloudWatch Logs + Basis-Alarme

### 8.4 Modulstruktur

- `infra/terraform/modules/network`
- `infra/terraform/modules/security`
- `infra/terraform/modules/load_balancer`
- `infra/terraform/modules/compute`
- `infra/terraform/modules/database`
- `infra/terraform/modules/container_registry`
- `infra/terraform/modules/iam`
- `infra/terraform/modules/observability`

### 8.5 Environment-Ordner

- `infra/terraform/environments/staging`
- `infra/terraform/environments/production`

Jeder Environment-Ordner enthält:

- `main.tf`, `variables.tf`, `outputs.tf`, `versions.tf`
- backend config mit env-spezifischem State-Key
- `terraform.tfvars.example`

## 9. Kamal Deployment Plan

### 9.1 Konfigurationsdateien

- `config/deploy.yml`
- `config/deploy.staging.yml`
- `config/deploy.production.yml`

### 9.2 Kamal Defaults

- Registry: AWS ECR
- Healthcheck: `/up`
- Rollen/Hosts je Umgebung getrennt
- Rolling Deploy über mehrere Hosts

### 9.3 Deploy-Flows

- Staging: automatisch per `deploy-staging.yml`
- Production: manuell per `deploy-production.yml`

## 10. Teststrategie (RSpec)

### 10.1 Testtypen

1. Model Specs
2. Request Specs
3. System Specs (Turbo Flows)
4. Broadcast Specs (Rooms + Messages)

### 10.2 Mindestfälle

- Raum erstellen -> sofortiger Broadcast in Room-Liste
- Message erstellen -> sofortiger Broadcast im Raum
- Validierungsfehler im Turbo-Flow sichtbar
- HTML Fallback ohne Turbo funktioniert
- Nachrichtenreihenfolge nach `created_at ASC`

## 11. Security und Betriebs-Baseline

- DB nur intern erreichbar
- Least-Privilege IAM/SG
- Keine Secrets im Repo
- Input-Limits + Sanitizing für Chat-Eingaben
- Basis-Logging für App und Infra

## 12. Umsetzungsreihenfolge (ohne Rückfragen)

### Phase 0: Bootstrap

- `.mise.toml` mit Ruby `4.0.1`
- Rails `8.1.2` App initialisieren
- RSpec, Tailwind, Hotwire, Postgres konfigurieren

### Phase 1: Chat MVP

- Migrationen, Modelle, Controller, Views
- Tailwind Layout finalisieren

### Phase 2: Realtime

- Turbo Stream Subscriptions
- Model-Broadcast Callbacks
- Solid Cable Setup

### Phase 3: Docker lokal

- Dockerfile + Compose
- `bin/dev` im Container
- lokale Runbook-Schritte in README

### Phase 4: CI/CD

- GitHub Workflows `ci`, `deploy-staging`, `deploy-production`
- ECR Build + Push + Kamal Deploy

### Phase 5: Terraform + AWS

- State Bootstrap
- Staging/Production Infrastruktur
- Kamal auf Multi-Host verifizieren

### Phase 6: Abnahme

- End-to-End Smoke Tests
- Dokumentation final

## 13. Definition of Done

Die Umsetzung gilt als abgeschlossen, wenn alle Punkte erfüllt sind:

1. App läuft lokal per Docker (`web + db`) ohne manuelle Sonderwege
2. Realtime für neue Räume und Messages funktioniert in zwei parallelen Browser-Sessions
3. RSpec, RuboCop, Brakeman, Bundler-Audit laufen in GitHub Actions grün
4. Staging deployt automatisch auf Push nach `main`
5. Production deployt manuell per `workflow_dispatch`
6. Terraform kann `staging` und `production` vollständig provisionieren
7. Kamal deployed erfolgreich auf mehrere Hosts je Umgebung
8. README enthält vollständige Setup-/Deploy-/Betriebsanleitung

## 14. Keine offenen Fragen

Dieses Planungsdokument ist vollständig und ausreichend konkretisiert, um die Applikation ohne weitere Rückfragen komplett umzusetzen.
