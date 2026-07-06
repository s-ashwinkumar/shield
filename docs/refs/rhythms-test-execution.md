# Rhythms — Test Execution on the Host (native, per-worktree)

Investigated `/Users/ashwin/code/rhythms` on 2026-07-05. Goal: can unit/integration/e2e
tests run natively on macOS per git-worktree, without the shared `fullstack-fullstack-1`
dev container?

Legend: **[verified]** = read directly from a file. **[inferred]** = reasoned from evidence.

---

## 1. Repo shape [verified]

Polyglot monorepo. Top-level services (each with its own `mise.toml`, `docker-compose.yml`,
`dev.Dockerfile`, `deploy.Dockerfile`):

| Service | Runtime | Test framework |
|---|---|---|
| `webui/` | Node 22 / npm 11.4, Next.js (`next dev --turbopack`) | Vitest (browser + node) + Playwright |
| `railsapi/` | Ruby 3.4.7, Rails | RSpec (`parallel_test`) |
| `mlai/` | Python 3.12, Poetry 2.2, Java temurin-21 | pytest (`-n auto`, xdist) |
| `mcpservers/`, `ddagent/`, `evals/` | mixed | — |

- **Not** a JS-workspaces/turbo/nx setup. `webui/package.json` has no `workspaces`/`packageManager`
  field; root `package-lock.json` is trivial. Each service is independently managed by **mise**.
- Root `CLAUDE.md`/`README.md` → symlinks to `AGENTS.md`.

## 2. mise / tool versions [verified]

- Root `mise.toml`: sets `WORKSPACE_ROOT`, sources `.local.env` and
  `.devcontainer/.common.dev.env`, puts `.devcontainer/fullstack/bin` on PATH. `experimental = true`.
  Defers tool versions to each service.
- `webui/mise.toml`: `node = "22"`, `npm = "11.4"`; sources `webui/src/config/.dev.env`.
- `railsapi/mise.toml`: `ruby = "3.4.7"`; sources `railsapi/config/.dev.env`.
- `mlai/mise.toml`: `python = "3.12"`, `pipx = 1.8.0`, `java = temurin-21`, `pipx:poetry = 2.2`;
  sources `mlai/src/config/.dev.env`.
- **No `mise run` test tasks** defined — mise supplies runtimes + env only. Tests are invoked via
  the native tool (`npm run`, `rspec`, `pytest`). `mise x -C <svc> -- <cmd>` is the wrapper CI uses.

## 3. Test commands (exact) [verified]

**webui** (`webui/package.json` scripts):
```
npm run test          # vitest run (all projects incl. storybook browser)
npm run test:unit     # vitest run --project=unit --project=unit-node
npm run test:coverage # vitest run --project=unit --project=unit-node --coverage
npm run test:storybook# vitest run --project=storybook   (browser via @vitest/browser-playwright)
npm run test:e2e      # playwright test e2e/ --grep-invert @hosted
npm run test:e2e:hosted # playwright test e2e/ --grep @hosted
```
Vitest projects (`webui/vitest.config.ts`): `unit` (src/**/*.test.tsx, browser env),
`unit-node` (src/**/*.node.test.tsx, node env), `storybook` (needs a browser via Playwright).
`SKIP_ENV_VALIDATION` is forced true in the vitest config → no live env needed for unit.

**railsapi** (`railsapi/README.md`, CI `railsapi-push.yml`):
```
bundle exec rspec                       # local, all
bundle exec rspec spec/models/user_spec.rb[:25]
# CI: bundle exec rake parallel:setup && bundle exec parallel_test spec/ --type rspec ...
```

**mlai** (CI `mlai-push.yml`, `mlai/AGENTS.md`):
```
pytest tests/ --ignore=tests/integration/ --ignore=tests/evals/ -v -n auto --reruns 3   # unit
pytest tests/integration/ -n auto --dist loadfile                                         # integration
pytest tests/evals/ -v -s                                                                 # evals (LLM)
```

## 4. Service dependencies for tests [verified ports / inferred tiering]

Backing services are **standalone Docker containers** defined in each service's
`docker-compose.yml`, published to **host localhost ports** (from `.dev.env`):

| Service | Host port | Used by |
|---|---|---|
| `railsapi-postgres` (postgres:15.6) | **4001** → 5432 | railsapi RSpec |
| `railsapi-elasticsearch` (ES 9.1.0) | **4200** → 9200 | railsapi (Searchkick) |
| `mlai-postgres` (postgres:15.6) | **8002** → 5432 | mlai integration (`conftest.py` builds `postgresql+asyncpg://`) |
| `mlai-elasticsearch` (ES 9.1.0) | **8200** → 9200 | mlai integration |
| `mlai-redis` (redis:7) | **8379** → 6379 | mlai |
| `temporal` (auto-setup 1.26.3) | — | mlai integration/workflows |
| `neo4j:5-community` | (mapped) | mlai |

Connection strings (verified):
- `railsapi/config/.dev.env`: `DATABASE_URL=postgres://root:password@localhost:4001/`,
  `ELASTICSEARCH_URL=http://localhost:4200`.
- `mlai/src/config/.dev.env`: `POSTGRES_HOST=localhost POSTGRES_PORT=8002`,
  `REDIS_URL=redis://localhost:8379`, `ELASTICSEARCH_URL=http://localhost:8200`, `TEMPORAL_HOST=localhost`.

Tiering:
- **Unit** — webui `test:unit` needs no backing services (env validation skipped). mlai
  `tests/ --ignore=integration --ignore=evals` [inferred: unit tier, some may touch a session-scoped DB
  via `conftest.py` — verify]. 
- **Integration** — railsapi RSpec needs **Postgres (4001)** + **Elasticsearch (4200)**. mlai
  `tests/integration/` needs **Postgres (8002) + Redis (8379) + Elasticsearch (8200) + Temporal** [verified from conftest/env].
- **e2e** — full app + browser (see §6).
- No **testcontainers** usage found (no auto-spawned containers); tests connect to already-running
  containers on fixed ports.

## 5. The dev container [verified]

- `.devcontainer/fullstack/docker-compose.yml` defines the `fullstack` container
  (`ghcr.io/getrhythms/rhythms-fullstack-dev`), which **mounts the repo at `/workspaces/rhythms`**
  (`volumes: - ../..:/workspaces/rhythms`), runs `.../fullstack/bin/dev` (starts all dev servers),
  and `depends_on` the backing containers. `network_mode: host` (via `docker-compose.base.yml`).
- The compose **`include:`s each service's `docker-compose.yml`** — i.e. the Postgres/ES/Redis/Temporal
  containers are the *same* whether you bring up the whole fullstack or just the datastores.
- **Structural blockers checked:** grep for `/workspaces/rhythms` in `vitest.config.ts`,
  `playwright.config.ts`, `rails_helper.rb`, `conftest.py`, `database.yml` → **none** [verified].
  The only `/workspaces` references are the container's own `command:`/`volume:` — not in test code.
  All DB/ES/Redis URLs use `localhost:<published port>`, which is reachable from the macOS host.
- **Conclusion:** nothing in the test code is container-only. The container's job is (a) pinning
  runtimes — reproducible natively via **mise** — and (b) hosting the backing datastores — which
  publish to host ports and can run standalone.

## 6. e2e / browser tests [verified]

- **Playwright** (`webui/playwright.config.ts`, `webui/e2e/`) plus a separate YAML-driven
  `webui/e2etests/` flow suite used in CI (`e2e-tests.yml`).
- `baseURL = envConfig.baseUrl` from `webui/e2e/config/environments.ts`:
  - local: `process.env.WEBUI_URL || "http://localhost:3000"`
  - prod/demo: `https://app.rhythms.ai`, `https://demo.getrhythms.ai`, `https://app.gotorhythms.ai`.
- Playwright `webServer` block is **commented out** → e2e does **not** auto-start the app; the app
  (webui:3000 + railsapi:4000 + mlai:8000 + mcpservers:8082) must already be running. Storybook
  vitest project also needs a browser.
- CI e2e (`e2e-tests.yml`) brings the entire stack up via
  `.github/workflows/execute_e2e_command all up` (docker compose) — i.e. e2e genuinely needs the
  full running stack.

---

## VERDICT: (a) — unit + integration run natively; only e2e/live-UI needs the running app

Unit and integration tests can run **natively on the macOS host** per-worktree, because (i) runtimes
are provisioned by **mise** (no container needed), (ii) no test config hardcodes `/workspaces`, and
(iii) tests reach datastores over `localhost:<published port>`. Only **e2e / Storybook-browser** tests
truly need a running app server + browser stack.

### Native commands (run from each service dir, prefixed with `mise x -C <svc> --` or inside a `mise` shell)

```bash
# webui — UNIT, zero backing services:
cd webui && mise x -- npm run test:unit
#   (npm run test:coverage for coverage; test:storybook needs a browser)

# railsapi — INTEGRATION, needs Postgres:4001 + Elasticsearch:4200:
cd railsapi && mise x -- bundle exec rspec            # or: parallel_test spec/ --type rspec

# mlai — UNIT (no/minimal services):
cd mlai && mise x -- pytest tests/ --ignore=tests/integration/ --ignore=tests/evals/ -n auto
# mlai — INTEGRATION, needs Postgres:8002 + Redis:8379 + Elasticsearch:8200 + Temporal:
cd mlai && mise x -- pytest tests/integration/ -n auto --dist loadfile
```

### Minimal backing services for integration tests

Run these standalone containers (from the service compose files — no full fullstack, no dev servers):

- **railsapi RSpec:** Postgres `4001`, Elasticsearch `4200`.
- **mlai integration:** Postgres `8002`, Redis `8379`, Elasticsearch `8200`, Temporal.
- **webui unit:** none.

Per-worktree caveat: the published host ports (4001/4200/8002/8379/8200) are **fixed and shared**.
Concurrent worktrees hitting the same datastores will contend on data/schema. Options: one shared
datastore set with per-worktree DB names/schemas, or per-worktree compose with remapped ports +
overridden `DATABASE_URL`/`*_PORT` env. This is a data-isolation problem, **not** a container blocker.

## Deeper findings (2026-07-05, verified from compose files)

- Each service `docker-compose.yml` defines the **app container AND its datastores as separate services**. So `docker compose up <datastores only>` skips the heavy built app image. Datastores are standard images (postgres:15.6, ES 9.1.0, redis:7, temporal auto-setup, neo4j:5).
- **Datastores are a shared singleton** — run ONCE, all worktrees' native test runs hit the same `localhost:<port>`. Heaviness is a fixed one-time cost, NOT ×N-worktrees. Full set ≈ 2×PG + 2×ES(1G/512m) + redis + temporal + neo4j(1G) ≈ 4–5GB.
- rhythms **already ships host-based paths**: `.devcontainer/unified/LOCAL-DOCKER.md` (compose stack w/o devcontainers, "ideal for AI agents that run from the host") and `PARALLEL-INSTANCES.md` (per-worktree isolation via unique `DEVNAME` → separate containers/networks/volumes/DBs + own tunnel — the HEAVY full-isolation path; not what we want ×N).

## Emerging model (native-first, single leased live server)

- **Shared datastore layer (singleton, always-on):** all datastore containers only (no app containers). ~4–5GB, one-time.
- **Per-worktree testing = native** (`mise x -C <svc> -- <test cmd>`) against the shared datastores. Unit needs ~nothing; integration needs the datastores. Isolation via per-worktree **DB name** + **ES index prefix** (open problem #1/#2 below).
- **The "one local server" = native app processes** (`bin/dev` per service) from whichever worktree holds the **lease** — they bind the fixed app ports (webui 3000 / railsapi 4000 / mlai 8000 / mcp 8082), so only one worktree can be "live" at a time. Claim = start app servers; release = stop them. **No docker mount repointing, no devcontainer, no session migration.** This dissolves the promote/unpromote clunk: worktrees never move; promote/unpromote = lease flip + start/stop app procs.
- **Everything else UI → Railway** preview envs.
- Whole-repo scope (tasks aren't service-specific) → the datastore singleton must cover all services incl. heavy mlai (temporal/neo4j).

### Open problems to solve (not blockers, but must-do for daily reliability)
1. **Postgres data isolation:** shared PG server, per-worktree database name. `DATABASE_URL=...@localhost:4001/` has empty db → name comes from `database.yml`; verify per-worktree override via env.
2. **ES / neo4j isolation:** per-worktree index/namespace prefix, or run integration one-worktree-at-a-time.
3. **Dependency install caching:** fresh-worktree `bundle/poetry/npm install` must be seconds not minutes (shared caches) — addresses the old "symlink node_modules" pain.

## SOPS secrets & tests — investigated (the key objection)

- sops-encrypted files exist per service: `development.sops.env`, `ci.sops.env`, `railway.sops.env`. `start-local.sh` decrypts `development.sops.env` → `.decrypted.env` **for the running app**.
- **BUT tests do NOT consume them.** Verified in CI (`.github/workflows/{railsapi,mlai,webui,mcpservers}-push.yml`): **no `sops`/`decrypt` step in ANY test job.** Test commands are bare:
  - railsapi: `RAILS_ENV=test → rake parallel:setup → parallel_test spec/ --type rspec`
  - mlai: `pytest tests/ --ignore=integration --ignore=evals -n auto` (+ integration variant)
  - webui: `npm run test`  · mcpservers: `pytest …`
- Rails test env **self-generates** the sensitive keys: `ACTIVE_RECORD_ENCRYPTION_* = ENV[...] || (Rails.env.test? ? SecureRandom.hex : nil)`. Deliberate "no real secret in test" design.
- **Caveat on the proof:** CI runs tests inside the devcontainer *image* (`devcontainers/ci`, `imageName: rhythms-<svc>-dev`) for runtime consistency — so CI proves "no fullstack container, no sops," NOT "runs on bare macOS via mise." The mise-native leap (native gem/wheel compilation: pg, nokogiri, grpc, ML wheels) is still to be proven by an actual run.
- **Split confirmed:** tests+linters = native, no secrets. Live app server = leased container, needs decrypted dev secrets. The two concerns are cleanly separable.
- Bonus finds: `BUNDLE_PATH=$WORKDIR/.cache/bundle` (per-worktree gem cache — cacheable), `.local.env` already holds the user's `SOPS_AGE_KEY`, and mise `[hooks.cd]` + `_.source` already load env natively on `cd`.

## SPIKE RESULT (2026-07-05, run on host) — the real blocker is platform deps, not sops

Ran on the actual machine. State: mise installed; webui/node_modules (1.6G) + railsapi/.cache/bundle (707M) present; datastores already running (4001/4200/8002/8200/8379); fullstack app up (3000/4000/8000).

- **node runs natively** via mise (`v22.23.1`) ✓. **No sops needed** ✓.
- **BUT native vitest FAILED:** `Cannot find module '@rollup/rollup-darwin-arm64'`.
  - `node_modules/@rollup` has ONLY `rollup-linux-arm64-{gnu,musl}` — deps installed INSIDE the Linux container.
  - railsapi gems likewise Linux: `pg-1.6.3-aarch64-linux`, exts are ELF (Linux) `.so`.
  - Container mounts `../..:/workspaces/rhythms` → **host + container SHARE node_modules/bundle via bind mount.**
- **Conclusion:** can't run tests on macOS against these deps (wrong platform); can't reinstall for macOS without breaking the container (same files). Native testing REQUIRES separate host-native dep installs.

### THE convergent design decision: worktrees live OUTSIDE `~/code/rhythms` (outside the bind mount)
Solves three problems at once:
1. Cursor indexing (theme #4) — worktrees no longer inside the indexed repo.
2. Platform-dep conflict — a worktree outside the mount holds its own darwin-arm64 deps, no clobber.
3. Explains why the old `symlink node_modules` hack failed (symlinking Linux binaries onto host).

### Validated cost (was "open problem #3", now confirmed load-bearing)
Each worktree needs host-native `npm install` + `bundle install` (darwin; native gems need brew libs e.g. `libpq`). First time = minutes; cacheable across worktrees via a shared HOST cache, separate from the container's Linux `.cache/bundle`. **Not yet run end-to-end** (next spike: throwaway worktree outside mount → native install → green test + timing).

### Open items to verify before relying on native runs
- Whether mlai's non-integration `tests/` truly need zero DB (conftest opens an async engine at
  session scope — confirm it's skipped/lazily used for pure-unit runs).
- railsapi `rake parallel:setup` / `db:reset` expectations for a native, per-worktree DB.
