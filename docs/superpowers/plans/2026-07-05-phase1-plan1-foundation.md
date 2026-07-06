# Phase 1 · Plan 1 — Foundation (essentials repo, Alacritty + Herdr) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Stand up the new stack's foundation — a pushed-up `essentials` repo holding the Alacritty + Herdr configs and a minimal root `AGENTS.md`, with Herdr running and reliably reporting Claude Code pane state (blocked/working/done) — all parallel to and non-disruptive of the live iTerm+tmux stack.

**Architecture:** `essentials` is a standalone, cross-platform personal-environment repo. Configs live in the repo and are symlinked into `~/.config/...` by an idempotent `install.sh`. Herdr is the multiplexer + fleet-awareness layer; Alacritty is just a fast emulator underneath it. Nothing rhythms-specific goes here.

**Tech Stack:** macOS (Apple silicon / aarch64), Homebrew, Alacritty (TOML config), Herdr ≥ 0.7 (TOML config at `~/.config/herdr/config.toml`), Claude Code (Herdr `claude` integration v6).

## Global Constraints

- Platform: **macOS Apple silicon**. Configs must not assume Linux paths.
- **essentials is universal / cross-platform / no rhythms-specific content** (no docker, lease, Linear, dev-container). Anything rhythms-specific belongs in `rdev`, not here.
- Configs are **owned by the repo and symlinked** into `~/.config/...`; never hand-edit the live `~/.config` copies.
- **Do not touch the live iTerm+tmux stack.** Herdr runs alongside it; both coexist.
- Herdr version floor: **0.7** (`herdr --version`). Claude integration version: **6**.
- Keep all config/docs **terse and high-signal** (AXI ergonomics rule).
- The user is installing Alacritty + Herdr themselves; install steps below are **verification/guardrails**, not the primary install path — adapt to whatever install method they used (`brew`, curl script, or mise).

## File Structure

```
~/code/essentials/                 # NEW repo (separate from rdev)
├── README.md                      # what this repo is + how to install
├── AGENTS.md                      # minimal cross-harness working rules (starter; refined later)
├── .gitignore
├── install.sh                     # idempotent: symlink configs → ~/.config, verify tools
├── alacritty/
│   └── alacritty.toml             # → ~/.config/alacritty/alacritty.toml
└── herdr/
    └── config.toml                # → ~/.config/herdr/config.toml
```

Responsibilities: `install.sh` is the only thing that writes to `~/.config` (via symlinks) and checks tool presence/versions. Each config file is self-contained and owned here. `AGENTS.md` is a lean starter; its content is refined by the separate `docs/prompts/agents-md-and-skills-audit.md` workstream.

---

### Task 1: Scaffold the `essentials` repo

**Files:**
- Create: `~/code/essentials/.gitignore`
- Create: `~/code/essentials/README.md`

**Interfaces:**
- Produces: the repo root `~/code/essentials/` used by every later task.

- [ ] **Step 1: Create the repo and initial structure**

```bash
mkdir -p ~/code/essentials/alacritty ~/code/essentials/herdr
cd ~/code/essentials
git init
```

- [ ] **Step 2: Write `.gitignore`**

```gitignore
.DS_Store
*.log
```

- [ ] **Step 3: Write `README.md`**

```markdown
# essentials

My universal, cross-platform working setup — usable on any machine, any project.
Contains: Alacritty config, Herdr config, and a minimal root `AGENTS.md`.

Nothing project-specific lives here (no rhythms/docker/lease). Those live in `rdev`.

## Install
```bash
./install.sh
```
Symlinks the configs into `~/.config/` and verifies required tools.
```

- [ ] **Step 4: Verify structure**

Run: `ls -R ~/code/essentials`
Expected: shows `alacritty/`, `herdr/`, `README.md`, `.gitignore`.

- [ ] **Step 5: Commit**

```bash
cd ~/code/essentials && git add -A && git commit -m "chore: scaffold essentials repo"
```

---

### Task 2: Alacritty config

**Files:**
- Create: `~/code/essentials/alacritty/alacritty.toml`

**Interfaces:**
- Produces: `alacritty/alacritty.toml`, symlinked to `~/.config/alacritty/alacritty.toml` by `install.sh` (Task 5).

- [ ] **Step 1: Confirm Alacritty is installed** (user installs it; verify)

Run: `alacritty --version`
Expected: prints a version (e.g. `alacritty 0.13.x`). If "command not found", install: `brew install --cask alacritty`.

- [ ] **Step 2: Write a fast, minimal config**

`~/code/essentials/alacritty/alacritty.toml`:
```toml
# Alacritty — fast, minimal. Herdr provides multiplexing/agent-awareness on top.
[env]
TERM = "xterm-256color"

[window]
option_as_alt = "OnlyLeft"   # macOS: left-Option as Alt for Herdr/tmux-style binds
padding = { x = 4, y = 4 }
dynamic_title = true

[scrolling]
history = 10000

[font]
size = 14.0
# normal = { family = "..." }   # set your preferred font here

[cursor]
style = { shape = "Block", blinking = "Off" }

[mouse]
hide_when_typing = true
```

- [ ] **Step 3: Validate the config parses**

Run: `alacritty migrate --dry-run --config-file ~/code/essentials/alacritty/alacritty.toml 2>&1 || alacritty --config-file ~/code/essentials/alacritty/alacritty.toml -e true`
Expected: no parse error. (If `migrate` unsupported on the installed version, the `-e true` launch exits cleanly.)

- [ ] **Step 4: Commit**

```bash
cd ~/code/essentials && git add alacritty/alacritty.toml && git commit -m "feat: add alacritty config"
```

---

### Task 3: Herdr config

**Files:**
- Create: `~/code/essentials/herdr/config.toml`

**Interfaces:**
- Produces: `herdr/config.toml`, symlinked to `~/.config/herdr/config.toml` by `install.sh` (Task 5).

- [ ] **Step 1: Confirm Herdr installed and version**

Run: `herdr --version`
Expected: `0.7` or higher. If missing: `brew install herdr`.

- [ ] **Step 2: Capture the authoritative default config as a base**

Run: `herdr --default-config > /tmp/herdr-default.toml && head -40 /tmp/herdr-default.toml`
Expected: prints a full TOML config. (We hand-author only the keys we care about below; the rest fall back to defaults.)

- [ ] **Step 3: Write our tuned config**

`~/code/essentials/herdr/config.toml`:
```toml
# Herdr — multiplexer + fleet awareness. See `herdr --default-config` for all keys.
onboarding = false

[terminal]
shell_mode = "auto"        # login shells on macOS so PATH/Homebrew/mise init runs in panes

[ui]
agent_panel_sort = "priority"   # triage view: blocked -> done -> working -> idle
confirm_close = true
accent = "cyan"

[ui.sound]
enabled = true

[ui.sound.agents]
claude = "on"

[session]
resume_agents_on_restore = true
```

- [ ] **Step 4: Validate by symlinking and reloading (temporary manual symlink; install.sh formalizes it in Task 5)**

Run:
```bash
mkdir -p ~/.config/herdr && ln -sf ~/code/essentials/herdr/config.toml ~/.config/herdr/config.toml
herdr server reload-config 2>&1 || echo "(no running server yet — will validate on launch in Task 4)"
```
Expected: reload succeeds, or the "no running server" message (fine — validated in Task 4).

- [ ] **Step 5: Commit**

```bash
cd ~/code/essentials && git add herdr/config.toml && git commit -m "feat: add herdr config (priority sidebar, macos login shells)"
```

---

### Task 4: Claude integration + verify state detection & restore

**Files:** none (installs Herdr's Claude integration; verification task).

**Interfaces:**
- Consumes: the Herdr config from Task 3.
- Produces: a verified guarantee that Claude panes report blocked/working/done and restore after a server restart — the core fleet-triage capability the whole redesign relies on.

- [ ] **Step 1: Install the Claude integration**

Run: `herdr integration install claude`
Expected: confirms Claude integration installed (version 6). Verify: `herdr integration list 2>&1 | grep -i claude` (or check Settings → integrations tab inside Herdr).

- [ ] **Step 2: Launch Herdr in Alacritty and open a Claude pane**

Manual: open Alacritty, run `herdr`, and in a pane run `claude` (start any small prompt, e.g. "list files here").
Expected: a real Claude Code session runs in the pane.

- [ ] **Step 3: Observe state transitions in the sidebar**

Manual observation while the Claude pane runs a task then finishes:
Expected: sidebar shows the pane go **🟡 working** during the task, **🔵 done** when it finishes, and **🔴 blocked** if it hits a permission prompt (trigger one, e.g. a command needing approval). Confirm `agent_panel_sort = "priority"` floats blocked/done to the top.
**If state is unreliable/misfires:** note exactly which transition is wrong — this is the known screen-manifest-detection risk; capture it before proceeding (it may inform whether we lean on Claude hooks later).

- [ ] **Step 4: Verify session restore across a server restart**

Run (from another Alacritty tab or after detaching with `prefix+q`):
```bash
herdr server restart 2>&1 || (herdr server stop; herdr)
```
Then reattach: `herdr`.
Expected: the Claude pane restores in its native session (not a bare shell), per `resume_agents_on_restore = true`.

- [ ] **Step 5: Record the verification result**

Append a short note to `~/code/essentials/README.md` under a "## Verified" heading: Herdr version, that Claude state detection works (or the specific misfire found), and that session restore works. Commit:
```bash
cd ~/code/essentials && git add README.md && git commit -m "docs: record herdr+claude verification"
```

---

### Task 5: Idempotent `install.sh`

**Files:**
- Create: `~/code/essentials/install.sh`

**Interfaces:**
- Consumes: `alacritty/alacritty.toml`, `herdr/config.toml`.
- Produces: symlinks at `~/.config/alacritty/alacritty.toml` and `~/.config/herdr/config.toml`; a tool/version check. This is the reproducible setup entrypoint referenced by README.

- [ ] **Step 1: Write `install.sh`**

`~/code/essentials/install.sh`:
```bash
#!/usr/bin/env bash
set -euo pipefail
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

link() {  # link <repo-relative-src> <dest>
  local src="$REPO/$1" dest="$2"
  mkdir -p "$(dirname "$dest")"
  if [[ -e "$dest" && ! -L "$dest" ]]; then
    echo "WARN: $dest exists and is not a symlink — backing up to $dest.bak"
    mv "$dest" "$dest.bak"
  fi
  ln -sfn "$src" "$dest"
  echo "linked $dest -> $src"
}

check() {  # check <cmd> <install-hint>
  if command -v "$1" >/dev/null 2>&1; then
    echo "ok: $1 ($($1 --version 2>&1 | head -1))"
  else
    echo "MISSING: $1 — install with: $2"
  fi
}

link "alacritty/alacritty.toml" "$HOME/.config/alacritty/alacritty.toml"
link "herdr/config.toml"        "$HOME/.config/herdr/config.toml"

check alacritty "brew install --cask alacritty"
check herdr     "brew install herdr"
echo "done. If herdr is running: 'herdr server reload-config'"
```

- [ ] **Step 2: Make executable and run**

Run: `chmod +x ~/code/essentials/install.sh && ~/code/essentials/install.sh`
Expected: prints `linked …` for both configs and `ok: alacritty …` / `ok: herdr …`.

- [ ] **Step 3: Verify symlinks resolve to the repo**

Run: `readlink ~/.config/alacritty/alacritty.toml ~/.config/herdr/config.toml`
Expected: both point into `~/code/essentials/...`.

- [ ] **Step 4: Commit**

```bash
cd ~/code/essentials && git add install.sh && git commit -m "feat: idempotent install.sh (symlink configs + tool checks)"
```

---

### Task 6: Minimal root `AGENTS.md`

**Files:**
- Create: `~/code/essentials/AGENTS.md`

**Interfaces:**
- Produces: a lean starter `AGENTS.md`. Content is deliberately minimal here; it's refined/expanded by the separate `docs/prompts/agents-md-and-skills-audit.md` workstream. Symlinking it to `~/AGENTS.md` is optional and left to the user (noted, not done automatically, to avoid clobbering existing global instructions).

- [ ] **Step 1: Write a minimal, universal AGENTS.md**

`~/code/essentials/AGENTS.md`:
```markdown
# How I work (global, cross-harness)

- Be terse and direct. No filler, no restating the question, no trailing summaries — the diff/output speaks.
- When I push back ("are you sure?", "that's not true"), treat it as signal: re-verify before defending.
- Prefer editing existing files over creating new ones. Don't add docs/READMEs unless asked.
- Verify before claiming done: run the command, show the output. Evidence before assertions.
- Ask before hard-to-reverse or outward-facing actions (pushing, deleting, publishing).
- Keep tool/CLI output terse; don't dump large blobs into context.
```

- [ ] **Step 2: Verify it reads cleanly**

Run: `cat ~/code/essentials/AGENTS.md`
Expected: the minimal rules above; no rhythms-specific content.

- [ ] **Step 3: Commit**

```bash
cd ~/code/essentials && git add AGENTS.md && git commit -m "feat: minimal global AGENTS.md"
```

---

### Task 7: Push essentials to a remote

**Files:** none (git remote + push).

**Interfaces:**
- Consumes: the committed repo from Tasks 1–6.
- Produces: the pushed-up `essentials` repo (the user's stated requirement: "pushed up").

- [ ] **Step 1: Create the remote** (confirm the user's preferred host/visibility first)

Run (GitHub, private): `cd ~/code/essentials && gh repo create essentials --private --source=. --remote=origin`
Expected: creates the repo and adds `origin`. (If the user wants a different name/visibility, adjust.)

- [ ] **Step 2: Push**

Run: `cd ~/code/essentials && git push -u origin HEAD`
Expected: branch pushed, upstream set.

- [ ] **Step 3: Verify**

Run: `cd ~/code/essentials && git remote -v && git status -sb`
Expected: `origin` set, working tree clean, branch tracks origin.

---

## Self-Review

**Spec coverage (§4 repo topology, §5 substrate):** essentials repo created (Task 1,7), Alacritty config (Task 2), Herdr config with priority sidebar (Task 3), Claude state detection + restore verified (Task 4), install.sh (Task 5), minimal AGENTS.md (Task 6). ✓ The `rdev-mux` adapter is explicitly Plan 2, not here.

**Placeholder scan:** no TBD/TODO. Config values are concrete. The one deliberately-open item (font family in Alacritty) is commented and optional. Task 4 Step 3 is an observation step (infra state can't be unit-tested) with an explicit "capture the misfire" fallback.

**Type consistency:** N/A (config/infra, no shared code signatures). Symlink paths are consistent between Task 3 Step 4 (temporary) and Task 5 (formalized in install.sh).

**Known deviation from strict TDD:** this is environment/config setup, so "tests" are verification commands with expected output and one manual observation (Task 4 Step 3, the sidebar). This is appropriate for infra; later plans (adapter, dep-sharing, runner) have real code and use test-first steps.
