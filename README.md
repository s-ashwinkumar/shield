# rdev -- Local AI Dev Environment

Automated development pipeline powered by Claude Code. Start a workstream for a ticket, plan with the agent, then walk away — it builds, reviews (with OpenAI via Codex), and opens a PR.

## How it works

```
rstream USENG-492

  ┌─────────┐    ┌─────────┐    ┌──────────┐    ┌───────────┐    ┌────┐    ┌────────────┐
  │  PLAN   │───▶│  BUILD  │───▶│ UX REVIEW│───▶│CODE REVIEW│───▶│ PR │───▶│PR COMMENTS │
  │interact │    │autonomo │    │user gate │    │codex loop │    │auto│    │fix-pr loop │
  └─────────┘    └─────────┘    └──────────┘    └───────────┘    └────┘    └────────────┘
  you + agent    builder per    rpromote to     codex reviews    create/   /fix-pr skill
  discuss plan   task, review   test locally    builder fixes    update    triage, fix,
                 after each     (skip if no UI) loop until clean PR       resolve threads
```

### Subagent Architecture

The **coordinator** orchestrates the pipeline and dispatches specialized subagents:

- **builder** (Claude) — writes code and tests, full edit/bash permissions
- **codex:codex-rescue** (OpenAI) — reviews code with fresh eyes, cross-model review
- **superpowers:code-reviewer** — per-task review during build phase

The coordinator never reviews code itself. OpenAI reviews Claude's code for genuine second-opinion review.

## Quick start

```bash
git clone <repo-url> ~/code/rdev
cd ~/code/rdev
./install
```

### Additional setup

```bash
# Install Codex CLI (for cross-model review)
npm install -g @openai/codex
codex login

# Install Codex plugin for Claude Code
claude plugin marketplace add openai/codex-plugin-cc
claude plugin install codex
```

## Prerequisites

| Tool | Required | Auto-install | Notes |
|------|----------|-------------|-------|
| [Homebrew](https://brew.sh) | Yes | No | Package manager for macOS |
| `git` | Yes | `brew install git` | |
| `tmux` | Yes | `brew install tmux` | |
| `jq` | Yes | `brew install jq` | |
| `claude` | Yes | No | [Claude Code](https://code.claude.com) |
| `gh` | Yes | No | [GitHub CLI](https://cli.github.com) |
| `codex` | Recommended | `npm install -g @openai/codex` | OpenAI Codex for cross-model review |
| `terminal-notifier` | Recommended | `brew install terminal-notifier` | macOS notifications |

## Commands

| Command | Description |
|---------|-------------|
| `rstream <ticket> [flags]` | Create workstream, launch coordinator for planning |
| `rbuild <name>` | Approve plan, start autonomous build |
| `rpromote <name>` | Check out stream branch in main repo for testing (re-runnable) |
| `runpromote <name>` | Restore main branch after testing |
| `rforward <name>` | Start code review → PR → comment pipeline |
| `rresume <name> [flags]` | Resume work on a completed or paused stream |
| `rclean <name>` | Tear down workstream (worktree/state + tmux window) |
| `rstatus` | Show all workstreams with pipeline stages |
| `rwatch [interval]` | Monitor all Claude panes for stuck prompts (auto-starts via tmux) |

### rstream flags

| Flag | Description |
|------|-------------|
| `--local` | Work on main repo instead of a worktree (for devcontainer/large features) |
| `--design` | Full design process: brainstorming → spec → TDD implementation plan |
| `--god` | Fully autonomous after plan approval — no user gates |
| `--branch <name>` | Custom branch name (default: `stream/<ticket>`) |
| `--base <branch>` | Base branch (default: `main`) |

### rresume flags

| Flag | Description |
|------|-------------|
| `--from <stage>` | Stage to resume from: `plan`, `build`, `code_review`, `pr_comments` |
| `--pr <number>` | Find the branch from a PR number |
| `--local` / `--worktree` | Override mode |
| `--god` | Run fully autonomous |

## Workflow

### Standard flow (small tickets, bugs)

```bash
rstream USENG-492                    # plan interactively
# say "build it" in the coordinator  # or exit + rbuild USENG-492
rpromote USENG-492                   # test on running services
rpromote USENG-492                   # re-promote after agent fixes (safe to repeat)
rforward USENG-492                   # code review → PR → comments (autonomous)
```

### Design flow (larger features)

```bash
rstream USENG-500 --local --design   # full brainstorming → spec → TDD plan
# approve plan, say "build it"       # subagent-driven: builder per task + review
rforward USENG-500                   # codex review → PR → comments
```

### God mode (fully autonomous after planning)

```bash
rstream USENG-510 --god              # plan interactively
# approve plan, say "build it"       # everything runs autonomously:
                                     # build → review → PR → comments → done
```

### Resume completed work

```bash
rresume USENG-492                    # resume at build stage
rresume USENG-492 --from plan        # re-plan first
rresume USENG-492 --pr 5042          # find branch from PR number
rresume USENG-492 --worktree         # switch from local to worktree mode
```

## Skills

Manual skills you can invoke anytime in a Claude session:

| Skill | Description |
|-------|-------------|
| `/fix-pr [pr-number]` | Triage PR review comments: fix code, respond, resolve threads |
| `/fix-ci [pr-number]` | Diagnose failing CI, fix failures caused by this PR's changes |
| `/review` | Run the codex review → builder fix loop |

## Pipeline Stages

### Stage 1: PLAN (interactive)

The coordinator fetches the ticket from Linear MCP, renames the branch to Linear's suggestion, and explores the codebase.

**Standard mode** (`--design` off): Explore → discuss → write plan → save to `docs/plans/<ticket>.md`

**Design mode** (`--design` on): Full superpowers flow:
1. Explore context → clarifying questions → propose approaches
2. Write design doc → self-review → user review
3. Write TDD implementation plan (bite-sized tasks, exact code, no placeholders)

### Stage 2: BUILD (autonomous)

**If plan has numbered tasks**: Fresh builder subagent per task, `superpowers:code-reviewer` reviews each task before proceeding.

**If no numbered tasks**: Single builder dispatch with full plan.

After build, checks `git diff main --name-only`:
- Files under `webui/` → UX review needed (user gate, unless god mode)
- Backend only → skip to code review

### Stage 3: CODE REVIEW (autonomous loop)

Codex (OpenAI) reviews → builder (Claude) fixes → codex re-reviews. Loop exits when:
- No Critical/Important issues remain
- Max iterations reached
- Same issues repeat (builder can't fix them)

The review prompt includes the ticket scope so codex only flags issues within or caused by this change.

### Stage 4: PR (autonomous)

Pushes branch, checks if PR exists (`gh pr view`). Creates or updates accordingly.

### Stage 5: PR COMMENTS (autonomous loop)

Waits for bot reviews (5 min first round, 3 min subsequent), then runs `/fix-pr` to handle all comments. Up to 3 rounds.

## Agents

| Agent | Role | Tools | Model |
|-------|------|-------|-------|
| `coordinator` | Pipeline orchestrator | All (including MCP) | Inherited |
| `builder` | Writes code and tests | Read, Grep, Glob, Bash, Edit, Write | Inherited |
| `codex:codex-rescue` | Code review (OpenAI) | Bash, Read | OpenAI |

## State & Artifacts

State lives in `.claude/rdev/` (gitignored):
- `state.json` — pipeline stage, ticket, mode, flags
- `<ticket>.md` — ticket context
- `review-<ticket>-{n}.md` — review findings per round

Plans persist in `docs/plans/<ticket>.md` (committed to repo).

## Monitoring

`rwatch` runs automatically via tmux `session-created` hook. It monitors all Claude panes every 30s and sends macOS notifications when any session is stuck waiting for input (permissions, Y/n prompts, interruptions).

## Configuration

Config lives at `~/.config/rdev/config`:

```bash
RHYTHMS_DIR="/Users/you/code/rhythms"
WORKTREE_DIR="/Users/you/code/rhythms/.claude/worktrees"
TMUX_SESSION=main
NOTIFY=true
DEVCONTAINER=fullstack
MAX_REVIEW_LOOPS=3
```

## Troubleshooting

**"tmux session not found"** — Run `rdev` first, or use `--session <name>`.

**"stream not found"** — The stream name might not match the ticket ID. Check `.claude/rdev/state.json` for the `name` field.

**Agent exited unexpectedly** — `rresume <name>` to restart from current stage.

**rpromote fails "branch already exists"** — Safe to re-run. rpromote handles this now.

**Codex review not running** — Ensure `codex login` was done and the codex plugin is installed.

**rwatch not running** — `rwatch` or restart tmux (starts via session hook).

**Cursor slow file lookup** — `.claude/worktrees` is excluded in `.vscode/settings.json`. Restart Cursor.

## Uninstall

```bash
cd ~/code/rdev
./uninstall
```

Removes symlinks, config, and tmux additions. Does NOT remove worktrees.
