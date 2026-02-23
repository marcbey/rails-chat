# PLAN: Bot-Auto-Reply in rails-chat

Stand: 23. Februar 2026

## 1. Ziel

Die App wird um folgende Funktionen erweitert:

1. Rails-Authentifizierung mit Standard-Generator.
2. Benutzerprofil mit `username`, `password` und freiem Feld `bot_character`.
3. Nachrichten-Autor wird automatisch aus `current_user.username` gesetzt (kein Name-Feld mehr im Message-Formular).
4. Bot-Antworten pro Benutzer und pro Chat-Raum ein-/ausschaltbar direkt im Raum.
5. Bei aktivem Bot wird für eingehende Nachrichten im Browser eine LLM-Antwort gestreamt, live ins Message-Textfeld geschrieben und danach automatisch gesendet.

## 2. Leitentscheidungen

1. Auth-Basis via `bin/rails generate authentication`, danach Anpassung auf `username`-basiertes Login.
2. Bot-Aktivierung als persistente Einstellung pro `user` + `chat_room` (nicht global).
3. OpenAI-API-Key wird niemals im Browser oder Repository gespeichert; Browser erhält nur kurzlebige Session-Credentials.
4. Message-Autorität liegt serverseitig: `ChatMessagesController` ignoriert Client-`author_name` und setzt den User selbst.

## 3. Arbeitspakete

## 3.1 Sicherheit & Vorbereitung

1. Sofortige Rotation des im Chat geteilten OpenAI-Keys.
2. `OPENAI_API_KEY` nur in Environment/Credentials, Eintrag in `.env.example` ohne echten Wert.
3. Parameter-Filtering prüfen (`filter_parameter_logging`) für sensible Felder.

## 3.2 Authentifizierung integrieren

1. Generator ausführen: `bin/rails generate authentication`.
2. User-Modell auf `username` als eindeutigen Login-Identifier anpassen.
3. Session-Flow und Login-Form auf `username + password` umstellen.
4. Chat-Routen/Controller absichern (`before_action` mit Authentication).

## 3.3 Account-Seite erweitern

1. Account-Edit/Update-Seite erstellen oder erweitern.
2. Felder: `username`, `password`, `password_confirmation`, `bot_character:text`.
3. Validierungen:
   - `username` vorhanden, eindeutig, sinnvolle Längenbegrenzung.
   - `bot_character` optional, mit Max-Länge (z. B. 2000 Zeichen).

## 3.4 Datenmodell für Chat anpassen

1. `chat_messages.author_name` ablösen durch `chat_messages.user_id` (FK, not null).
2. Backfill-Migration für bestehende Datensätze definieren (Fallback-User oder kontrollierter Cut, je nach Bestand).
3. `chat_room_bot_settings` (oder `room_memberships`) einführen:
   - `user_id`, `chat_room_id`, `bot_enabled:boolean` (default `false`),
   - Unique-Index auf `[user_id, chat_room_id]`.

## 3.5 UI/Server-Flow im Chat umbauen

1. Message-Formular: Name-Feld entfernen, nur Nachrichtentext.
2. Controller-Strong-Params anpassen (`:body`), Autor serverseitig aus `current_user`.
3. Message-Partial zeigt `chat_message.user.username`.
4. In Raum-UI Toggle ergänzen: `Bot aktiv` / `Bot inaktiv` (Turbo-fähig).

## 3.6 OpenAI Realtime/Streaming-Integration

1. Serverseitiger Endpoint zum Erzeugen kurzlebiger OpenAI-Session-Credentials.
2. Stimulus-Controller für Bot-Automation im Chat:
   - erkennt neue eingehende Nachrichten anderer Nutzer,
   - prüft `bot_enabled`,
   - startet Streaming-Session,
   - schreibt Tokens live ins Message-Textarea,
   - sendet Formular automatisch nach Abschluss.
3. Prompting:
   - `system`: `bot_character` des aktuellen Nutzers,
   - `user`: letzte Nachricht + kurzer Kontext (z. B. letzte N Nachrichten aus dem Raum).
4. Schutz vor Reply-Loops:
   - nicht auf eigene Nachricht antworten,
   - nur eine laufende Generation pro Raum/Nutzer,
   - optional Cooldown/Message-ID-Deduplizierung.

## 3.7 Teststrategie

1. Model/Request-Specs:
   - Auth-Flow,
   - Account-Update,
   - Message-Erstellung mit automatischem Autor,
   - Toggle-Endpunkte für Bot-State.
2. Stimulus/Integration:
   - Bot-Controller Logik (Trigger/Locks/Auto-Submit) mit JS-Test oder Systemtest.
3. Regression-Checks bestehender Chat-Flows (Turbo Streams).

## 3.8 Dokumentation

1. README um Auth-Flow, Account-Feld `bot_character`, Bot-Toggle und OpenAI-Setup ergänzen.
2. Hinweise zu Limitierungen:
   - Auto-Bot läuft nur bei offenem Browser-Tab des Nutzers,
   - Verhalten bei Verbindungsabbruch.

## 4. Abnahmekriterien

1. Unangemeldete Nutzer sehen keinen Chat.
2. Angemeldeter Nutzer sendet Nachricht ohne Namensfeld; gespeicherter Autor ist `current_user`.
3. Bot lässt sich pro Raum aktivieren/deaktivieren.
4. Bei aktivem Bot und eingehender Fremd-Nachricht erscheint die Antwort live im Textfeld und wird automatisch gesendet.
5. Antwortstil folgt `bot_character`.
6. Kein statischer OpenAI-Secret-Key ist im Frontend-Code oder Repo enthalten.

## 5. Geklärte Entscheidungen

1. Login via `username + password` (kein E-Mail-Login).
2. `bot_enabled` gilt pro `user + chat_room`.
3. Bot antwortet nur auf `@username`-Erwähnung.
4. Standardmodell: `gpt-realtime-mini` (konfigurierbar via `OPENAI_REALTIME_MODEL`).
5. Kontextfenster: letzte `20` Nachrichten.
6. Maximale Bot-Antwortlänge: `2000` Zeichen.

## 6. Verbesserungen (empfohlen)

1. API-Key-Rotation sofort durchführen (der aktuell geteilte Key gilt als kompromittiert).
2. Optional serverseitigen Fallback ergänzen, falls Browser-Realtime-Verbindung fehlschlägt.
3. Telemetrie für Bot-Fehler ergänzen (z. B. Rails-Logs mit Request-ID + Raum + Nutzer).

## 7. Feature-Nachtrag (Implementierungsstand)

Dieser Nachtrag ergänzt den bestehenden Plan um den tatsächlich integrierten Feature-Umfang.

### 7.1 Auth & Account

1. Rails Authentication Generator ist eingebunden.
2. Login läuft über `username + password`.
3. Account-Seite (`/account`) unterstützt:
   - `username` ändern,
   - Passwort ändern,
   - `bot_character` pflegen.

### 7.2 Chat-Domain

1. `chat_messages.author_name` wurde durch `chat_messages.user_id` ersetzt.
2. Nachrichtenautor wird serverseitig aus `current_user` gesetzt.
3. Raumbezogene Bot-Einstellung ist über `chat_room_memberships` umgesetzt (`bot_enabled`).

### 7.3 Mention-Trigger & Realtime-Bot

1. Bot antwortet nur auf Nachrichten mit `@username`.
2. Browser ruft einen serverseitigen Endpoint auf, um ein kurzlebiges Realtime-Client-Secret zu erhalten.
3. Realtime-Streaming schreibt Tokens live in das Message-Textarea.
4. Nach Abschluss wird das Formular automatisch abgesendet.
5. Antwortlänge ist auf maximal `2000` Zeichen begrenzt.

### 7.4 OpenAI-Konfiguration

1. Default-Modell: `gpt-realtime-mini` (`OPENAI_REALTIME_MODEL` überschreibbar).
2. `OPENAI_API_KEY` wird nur serverseitig verwendet.
3. Key-Weitergabe ist für folgende Deploy-Wege vorbereitet:
   - lokal via `.env`,
   - Docker Compose via Environment-Passthrough,
   - Kamal Deploy via `env.secret`,
   - GitHub Environments `staging`/`production` via Secrets.
