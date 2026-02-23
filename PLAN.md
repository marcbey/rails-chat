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
4. Domain/SSL-Setup:
- `chat-staging.schopp3r.de` fuer `staging`
- `chat.schopp3r.de` fuer `production`
- HTTPS via AWS ACM + ALB (TLS-Termination auf ALB)
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
19. Keine dedizierten Background-Worker im Testprojekt; Web läuft mit `ActiveJob :async` (kein `Solid Queue` in Puma)

## 3. Zielarchitektur (Service-Split)

### 3.1 Web App Service

- Rails 8.1.2 App mit Puma, Action Cable, Turbo Streams
- Serviert HTML/Turbo Responses und WebSocket-Verbindungen
- Containerisiert (Docker), deployt via Kamal auf mehrere EC2 Hosts
- Läuft hinter einem ALB
- Kein Solid-Queue-Supervisor im Web-Prozess

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

- ALB Listener: `80` + `443`
- `80` redirectet auf `443`
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
- `RAILS_MASTER_KEY_STAGING`
- `RAILS_MASTER_KEY_PRODUCTION`
- `DATABASE_URL_STAGING`
- `DATABASE_URL_PRODUCTION`
- `SECRET_KEY_BASE_STAGING`
- `SECRET_KEY_BASE_PRODUCTION`

Hinweis: `KAMAL_REGISTRY_PASSWORD` wird in den Deploy-Workflows dynamisch via `aws ecr get-login-password` erzeugt und muss nicht als GitHub Secret gepflegt werden.

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

## 10. SSL/HTTPS + Domain-Plan (HostEurope + AWS ACM)

### 10.1 Ziel-Hostnames

- `staging`: `chat-staging.schopp3r.de`
- `production`: `chat.schopp3r.de`

### 10.2 AWS-seitig

1. Je Environment ein ACM-Zertifikat in `eu-central-1` erstellen:
- `chat-staging.schopp3r.de`
- `chat.schopp3r.de`
2. Terraform erweitert ALB um:
- HTTPS Listener `443` mit jeweiligem ACM Zertifikat
- HTTP Listener `80` als Redirect auf HTTPS
3. Security Group ALB erlaubt `80` und `443`
4. Environment-Variablen fuer Rails/Kamal:
- `PUBLIC_HOSTNAME` je Environment
- `ALLOWED_HOSTS` = jeweiliger Public Hostname
- `ALLOWED_CABLE_ORIGINS` = `https://<public-hostname>`
5. `production` setzt `force_ssl = true`

### 10.3 HostEurope-seitig (konkrete DNS-Eintraege)

Bei HostEurope DNS folgende CNAME-Records anlegen:

- `chat-staging` -> `<staging-alb-dns-name>`
- `chat` -> `<production-alb-dns-name>`

Zusätzlich fuer ACM DNS-Validierung je Zertifikat die von ACM vorgegebenen CNAME-Validation-Records anlegen:

- Name: `_xxxx.chat-staging.schopp3r.de`
- Wert: `_yyyy.acm-validations.aws`
- Name: `_aaaa.chat.schopp3r.de`
- Wert: `_bbbb.acm-validations.aws`

### 10.4 Rollout-Reihenfolge

1. Staging DNS + Zertifikat + Terraform + Deploy + Test
2. Production DNS + Zertifikat + Terraform + manueller Deploy + Test

### 10.5 Abnahme SSL

1. `http://chat-staging.schopp3r.de` redirectet auf HTTPS
2. `https://chat-staging.schopp3r.de` liefert gueltiges Zertifikat
3. `http://chat.schopp3r.de` redirectet auf HTTPS
4. `https://chat.schopp3r.de` liefert gueltiges Zertifikat
5. Realtime Chat funktioniert unter HTTPS (Turbo/Action Cable)

## 11. Teststrategie (RSpec)

### 11.1 Testtypen

1. Model Specs
2. Request Specs
3. System Specs (Turbo Flows)
4. Broadcast Specs (Rooms + Messages)

### 11.2 Mindestfaelle

- Raum erstellen -> sofortiger Broadcast in Room-Liste
- Message erstellen -> sofortiger Broadcast im Raum
- Validierungsfehler im Turbo-Flow sichtbar
- HTML Fallback ohne Turbo funktioniert
- Nachrichtenreihenfolge nach `created_at ASC`

## 12. Security und Betriebs-Baseline

- DB nur intern erreichbar
- Least-Privilege IAM/SG
- Keine Secrets im Repo
- Input-Limits + Sanitizing für Chat-Eingaben
- Basis-Logging für App und Infra

## 13. Umsetzungsreihenfolge (ohne Rueckfragen)

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

### Phase 6: SSL/HTTPS

- ACM Zertifikate + DNS Validation
- ALB HTTPS Listener + HTTP Redirect
- Rails Host/Cable/SSL-Config pro Environment

### Phase 7: Abnahme

- End-to-End Smoke Tests
- Dokumentation final

## 14. Eingaben vom Benutzer (einmalig notwendig)

Fuer die Umsetzung werden nur noch folgende Inputs benoetigt:

1. Zugriff auf HostEurope DNS-Verwaltung (du trägst dort CNAMEs ein)
2. ALB DNS Namen aus Terraform Outputs:
- Staging ALB DNS
- Production ALB DNS (sobald production aufgebaut ist)
3. ACM Validation CNAMEs (liefert AWS; du trägst sie bei HostEurope ein)

## 15. Definition of Done

Die Umsetzung gilt als abgeschlossen, wenn alle Punkte erfüllt sind:

1. App läuft lokal per Docker (`web + db`) ohne manuelle Sonderwege
2. Realtime für neue Räume und Messages funktioniert in zwei parallelen Browser-Sessions
3. RSpec, RuboCop, Brakeman, Bundler-Audit laufen in GitHub Actions grün
4. Staging deployt automatisch auf Push nach `main`
5. Production deployt manuell per `workflow_dispatch`
6. Terraform kann `staging` und `production` vollständig provisionieren
7. Kamal deployed erfolgreich auf mehrere Hosts je Umgebung
8. README enthält vollständige Setup-/Deploy-/Betriebsanleitung

## 16. Keine offenen Fragen

Dieses Planungsdokument ist vollständig und ausreichend konkretisiert, um die Applikation ohne weitere Rückfragen komplett umzusetzen.

## 17. Erweiterung: Authentifizierung + Bot-Auto-Reply

Dieser Abschnitt erweitert den ursprünglichen MVP-Plan gezielt um die inzwischen gewünschte Benutzer-Authentifizierung und die LLM-basierte Bot-Automation.

### 17.1 Ziel der Erweiterung

1. Login mit `username + password`.
2. Account-Verwaltung um `bot_character`.
3. Nachrichtenautor wird aus `current_user.username` gesetzt (kein manuelles Namensfeld).
4. Bot pro Benutzer und pro Chat-Raum aktivierbar/deaktivierbar.
5. Bot antwortet nur auf `@username`-Erwähnung.
6. Bot-Antwort wird im Browser live in das Message-Formular gestreamt und automatisch abgesendet.

### 17.2 Datenmodell-Erweiterung

1. `chat_messages.author_name` wird ersetzt durch `chat_messages.user_id` (FK, not null).
2. Neue Tabelle `chat_room_memberships`:
- `user_id`
- `chat_room_id`
- `bot_enabled:boolean` (default `false`)
- Unique-Index auf `[user_id, chat_room_id]`
3. `users` enthält zusätzlich `bot_character:text` (max 2000 Zeichen).

### 17.3 Authentifizierung

1. Rails Standard-Authentication-Generator wird genutzt.
2. Login-Identität ist `username` (normalisiert zu lowercase).
3. Alle Chat-Routen erfordern authentifizierte Sessions.
4. Layout-Navigation enthält Chat, Account und Sign-out.

### 17.4 Account-Seite

1. Account-Edit unter `/account`.
2. Felder:
- `username`
- `password` + `password_confirmation`
- `bot_character`
3. Validierungen:
- `username`: unique, Format `[a-z0-9_]`, Länge 3..30
- `bot_character`: max 2000 Zeichen

### 17.5 Chat-Flow Anpassungen

1. Message-Form entfernt `author_name`.
2. `ChatMessagesController#create` erlaubt nur `body`; `user` wird serverseitig gesetzt.
3. Message-Partial rendert `chat_message.user.username`.
4. Raum-UI enthält Bot-Toggle (Turbo-fähig).

### 17.6 OpenAI Realtime Integration

1. Serverseitiger Endpoint erzeugt kurzlebige Realtime-Client-Secrets.
2. Browser verwendet nur dieses kurzlebige Secret, niemals den langfristigen API-Key.
3. Stimulus-Controller:
- erkennt neue eingehende Messages,
- prüft Mention `@username`,
- startet Realtime-Session,
- streamt Token-Delta live in Textarea,
- auto-submitted Formular nach Completion.
4. Default-Modell: `gpt-realtime-mini` (via `OPENAI_REALTIME_MODEL` überschreibbar).

### 17.7 Sicherheit & Betrieb

1. `OPENAI_API_KEY` nur als Secret/ENV, nie im Repo.
2. Deploy-Pipeline führt `OPENAI_API_KEY` für `staging`/`production` als Environment Secret.
3. Staging-Demo-Zugang wird über `db:seed` bereitgestellt (idempotent).

### 17.8 Abnahme der Erweiterung

1. Unauthentifizierte Benutzer werden auf Login umgeleitet.
2. Authentifizierte Benutzer senden Nachrichten ohne Namensfeld.
3. Bot pro Raum ein-/ausschaltbar.
4. Bei aktiver Bot-Einstellung + Mention entsteht eine automatisch gestreamte und gesendete Antwort.
5. Antwortstil folgt `bot_character`.
