# AGENTS.md

## Command Style

- Use canonical AWS/Terraform commands without inline profile prefixes.
- Do not run commands as `AWS_PROFILE=rails-chat aws ...` or `env AWS_PROFILE=rails-chat aws ...`.
- Do not run commands as `AWS_PROFILE=rails-chat terraform ...` or `env AWS_PROFILE=rails-chat terraform ...`.
- Preferred style: configure/select the profile outside the command, then run plain `aws ...` or `terraform ...`.

## Enforcement

- These style rules are enforced in `.codex/rules/rails-chat.rules`.

## Quality Gate Before Completion

- Before marking work as done, run `bundle exec rspec` and `bundle exec rubocop`.
- If available for the change, run `bin/ci`.
- If a check cannot be run, state it explicitly in the final report.

## Infrastructure Safety

- Treat production operations as confirmation-required work.
- Prefer explicit staging/production targets in commands.
- Do not use destructive infrastructure commands unless the task explicitly requires them.

## Git Workflow

- Keep commits focused and scoped to the task.
- Do not rewrite history (`git commit --amend`, force-push, reset) unless explicitly requested.

## Database and Migrations

- Avoid destructive database tasks (`db:drop`, `db:reset`, purge/truncate) unless explicitly requested.
- For schema changes, include/adjust tests for affected models, requests, and flows.
