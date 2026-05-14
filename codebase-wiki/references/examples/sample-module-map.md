# Module Map

A guide to the codebase by directory. Each area row shows recent activity (commit count, last 6 months), TODO/FIXME/HACK marker density, and a link to the area page.

## Areas

| Area | Path | Commits (6mo) | Markers | Page |
|------|------|---------------|---------|------|
| Auth | `src/auth/` | 87 | 4 | [auth](areas/auth.md) *(stub)* |
| Billing | `src/billing/` | 54 | 12 | [billing](areas/billing.md) *(stub)* |
| API | `src/api/` | 33 | 2 | [api](areas/api.md) *(stub)* |
| Providers | `src/providers/` | 28 | 6 | [providers](areas/providers.md) *(stub)* |
| Jobs | `src/jobs/` | 19 | 1 | [jobs](areas/jobs.md) *(stub)* |
| Data | `src/db/` | 14 | 0 | [data](areas/data.md) *(stub)* |
| Shared | `src/lib/` | 9 | 3 | [shared](areas/shared.md) *(stub)* |

Hot-spots: `auth`, `billing`, and `api` are the three most-active areas — likely the right places to deepen first.

## Supporting directories

- `src/config/` — environment variable loading; no runtime logic.
- `scripts/` — one-off operational scripts; not loaded by the API or worker.
- `db/migrations/` — Knex-style migration files.
- `infrastructure/` — Terraform for the deployment environment.

## Repository roots

- `package.json` — workspace root; dependencies and scripts.
- `tsconfig.json` — TypeScript config; path aliases (`@/*` → `src/*`).
- `.github/workflows/` — CI (test, lint) and CD (deploy).
- `docs/adr/` — architecture decision records (4 ADRs as of pass 1).

## Reading paths

| If you want to... | Start with... |
|---|---|
| Understand the architecture | [Architecture](architecture.md) |
| Add a new subscription type | [Billing](areas/billing.md) |
| Add a new payment provider | [Providers](areas/providers.md) |
| Add a new HTTP route | [API](areas/api.md) → [Auth](areas/auth.md) |
| Add a new background job | [Jobs](areas/jobs.md) |

---

Back to [README](README.md)
