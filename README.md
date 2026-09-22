# S.H.I.E.L.D.

**Strategic Herding, Intervention, Escalation & LLM Dispatch**

<p align="center">
  <img src="assets/coulson.png" alt="Coulson on duty: calm handler, chaotic fleet, everything under control" width="720">
</p>
<p align="center"><em>Coulson, reporting. The fleet is fine. One screen is on fire. This is normal.</em></p>

A personal harness for running a *fleet* of autonomous coding agents — many tickets in
parallel, each in its own git worktree, each following a shared playbook — with the human
doing exactly two things: approving plans, and answering escalations. Everything else is
LLM-driven, watched by a deterministic first mate.

> *"Agents of S.H.I.E.L.D."* was sitting right there. We took it.

## The cast

| Name | Role |
|---|---|
| **You** | Fury. One eye on everything, appears only when it matters. |
| **coulson** | The handler — *C.O.U.L.S.O.N.: Coordinated Orchestration of Unattended LLM Streams, Oversight & Notifications*. A Claude session you talk to; brings you the fleet's gates and escalations with context, relays your answers into streams, dispatches new work. |
| **the watcher** | Ops (`shield watch`). A zero-token bash daemon: scans every stream's state across all your repos, emits attention items, wakes Coulson, and fires a dead-man notification if nobody answers in time. |
| **the agents** | The streams. One coordinator per ticket, in its own worktree, executing the playbook end to end with builder subagents and cross-model review. |
| **the playbook** | The Code (*"more like guidelines, really"* — painfully accurate for LLM instruction-following). The tool-neutral workflow every stream follows. |

## The one rule

> Any time new code is written — review fixes, QA fixes, PR-comment fixes — it must pass
> **fresh-eyes review** (a different model family) again; if it could affect functionality,
> it gets **QA'd** again too. A loop that hasn't converged after ~3 passes **escalates to
> a human**.

That single rule generates every loop in the system, so the flow itself stays a straight
line: triage → plan (🧑 gate) → build → review → QA → ship. See `playbook/workflow.md`.

## Install

```bash
git clone git@github.com:s-ashwinkumar/shield.git ~/code/shield
~/code/shield/install        # needs git, jq, gh, herdr, claude, terminal-notifier
```

`install` asks for your **projects root** (where your repos live, e.g. `~/code`) and links
one command, `shield`, into `~/.local/bin`.

## Using it on your repos

Shield works on any git repo. It acts on the repo you're in, or on the repo you name:

```bash
cd ~/code/myapp && shield stream ENG-42     # inside a repo (or one of its worktrees)
shield -C myapp stream ENG-42               # a repo name under your projects root
shield -C ~/src/other stream 118            # a path; a bare number = GitHub issue #118
```

Each repo gets its own Herdr workspace; streams get a worktree under
`<repo>/.claude/worktrees/` and are registered in `~/.shield/streams/`, so `shield send`,
`shield status`, and Coulson work across every repo at once. Shield keeps its per-worktree
files out of `git status` via the repo's local `.git/info/exclude` — nothing to gitignore.

Repo-specific behavior is opt-in via **`<repo>/.shield/config`** (see
`config/project.example`): base branch, shared dependency dirs (`DEPS`), an optional dev
container, service ports for `shield status --all`, a per-PR preview URL pattern for QA,
the ticket tracker (Linear / GitHub / none), and a **setup hook** (`.shield/setup`) that
runs in every new worktree for anything bespoke — per-worktree databases, tool trust,
codegen.

## Commands

```
shield up                     create/focus the repo's Herdr workspace
shield stream <ticket>        dispatch an agent of S.H.I.E.L.D. (worktree + coordinator)
shield coulson                put Coulson on duty (fleet watcher + attention handler)
shield status [--all]         fleet at a glance, across repos
shield send <stream> <msg>    relay into a stream's live agent
shield peek|focus <stream>    read / jump to a stream's pane
shield build|forward|resume|clean|switch <stream>   stream lifecycle
shield watch [status]         fleet watcher alone (SHIELD_WATCH_SHADOW=1 = observe only)
shield usage [--roles]        token accounting: harness overhead vs ticket work
shield browser                ensure the shared QA Chrome (persistent profile, :9222)
```

## Architecture, briefly

- **Playbook** (`playbook/`) — tool-neutral WHAT: stages, gates, loops, QA method menu.
  Copied into each worktree at dispatch. Any harness (Claude Code, Cursor, Codex, remote
  agents) can execute it by providing six operations: state/resume, an implementer, a
  fresh-eyes reviewer, a test runner, a QA executor, and a human channel.
- **Coordinator** (`agents/coordinator.md`) — the Claude Code binding: `state.json`,
  builder subagent per task, adversarial review via the Codex plugin (OpenAI reviews
  Claude's diff), QA in whole rounds against PR preview environments (or locally),
  evidence required in every PR, comment rounds until quiet. Never merges.
- **First mate** (`libexec/shield-watch` + `agents/coulson.md` + `libexec/shield-coulson`) — attention
  routing: deterministic detection + dead-man fallback in bash; LLM judgment only where
  judgment matters (context, relay/redirect, dispatch). Design:
  `docs/archive/plans/first-mate-orchestrator-design.md`.
- **QA browser** — one long-lived Chrome (`--remote-debugging-port`, persistent
  signed-in profile) that all agents attach to via the chrome-devtools MCP, each in
  its own tabs. No login walls, no profile lock races.
- **Metering** (`libexec/shield-usage`) — local transcript accounting with per-model pricing;
  `--roles` separates harness overhead (Coulson) from ticket work. Dollar figures are
  counterfactual API list prices, not a bill.

- **Layout** — `bin/shield` is the only thing on your PATH; each verb is
  `libexec/shield-<verb>`, sharing `libexec/_lib.sh` (project resolution, the stream
  registry, per-repo config). Tests: `for t in tests/*.sh; do bash "$t"; done`.

## Honest status

Personal, opinionated, and under heavy iteration. Works across repos, but still tied to
macOS (terminal-notifier, launchd, Chrome paths) and to Herdr as the terminal substrate.
Design history from its single-repo days lives in `docs/archive/`.
