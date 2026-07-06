# herdr vs. alternatives — agentic-dev harness evaluation (mid-2026)

Goal: decide whether to adopt **herdr** or a **more stable** alternative for a solo dev running 10+ parallel Claude Code sessions in git worktrees, moving from custom tmux scripts toward WezTerm + a better multiplexer.

All GitHub numbers below were pulled live from the GitHub API on **2026-07-05** and are marked *(verified)*. Feature claims from product READMEs/sites are marked *(vendor-stated)*. Anything else is *(inferred)*.

## Comparison table

Criteria: **1** Agent-awareness · **2** Persistence/detach-reattach · **3** Scriptable API/CLI · **4** Terminal-native (not Electron/GUI-only) · **5** macOS-first · **6** git-worktree friendly · **7** Maintenance/governance health · **8** License + bounded exit cost.

| Tool | 1 Agent-aware | 2 Persist | 3 Scriptable | 4 Terminal-native | 5 macOS | 6 Worktree | 7 Governance | 8 License |
|---|---|---|---|---|---|---|---|---|
| **herdr** | ✓ (built-in, zero-config) | ✓ (bg server, ssh/remote) | ✓ (socket API + CLI + plugins) | ✓ (~10MB Rust binary) | ✓ | partial (organize by folder; no worktree automation) | partial (12k★ but ~1 dev; 3mo old) | partial (AGPL-3.0 / commercial dual) |
| **zellij** | ✗ (no agent state; plugin-buildable) | ✓ | ✓ (CLI actions + WASM plugins) | ✓ (Rust binary) | ✓ | partial (layouts, manual) | ✓ (34k★, ~190 contribs, 5yr) | ✓ (MIT) |
| **tmux (+resurrect/continuum, sesh)** | ✗ (bell hacks only) | ✓ (best-in-class) | ✓ (mature CLI/control-mode) | ✓ | ✓ | partial (via sesh/tmuxinator) | ✓ (47k★, decades, OpenBSD) | ✓ (ISC/BSD) |
| **WezTerm native mux** | ✗ | ✓ (mux server) | ✓ (`wezterm cli` spawn/list panes) | ✓ | ✓ | partial (scriptable, DIY) | ✓ (27k★, ~430 contribs, since 2018) | ✓ (MIT) |
| **claude-squad** | ✓ (per-agent status) | partial (tmux-backed) | partial (TUI-first) | ✓ (Go TUI binary) | ✓ | ✓ (worktree per agent) | partial (8k★, ~2 devs) | ✓ (AGPL-3.0) |
| **Conductor** | ✓ | ✗ (local app) | unknown | ✗ (macOS Electron app) | ✓ | ✓ | partial (closed-source co.) | ✗ (proprietary) |
| **emdash** | ✓ | ✗ | unknown | ✗ (Electron/TS) | ✓ | ✓ | partial (5k★, YC W26-backed, Apache-2.0) | ✓ (Apache-2.0) |
| **Crystal / Nimbalyst** | ✓ | ✗ | unknown | ✗ (Electron desktop) | ✓ | ✓ | ✗ (pivoted; repo stale since 2026-02) | ✓ (MIT) |
| **container-use** | partial (via agent, no fleet UI) | ✗ (env-oriented) | ✓ (MCP + CLI) | ✓ (Go CLI) | ✓ | ✗ (containers, not worktrees) | ✓ (Dagger-backed, Apache-2.0) | ✓ (Apache-2.0) |
| **Warp (agent features)** | ✓ | partial | partial | ✗ (closed GUI terminal) | ✓ | partial | partial (VC-backed, closed) | ✗ (proprietary) |
| **sesh** | ✗ | ✓ (delegates to tmux) | ✓ (CLI) | ✓ (Go binary) | ✓ | ✓ (zoxide/worktree dirs) | partial (2.6k★, ~1 dev, since 2023) | ✓ (MIT) |

## Per-contender notes

**herdr** — An "agent multiplexer" single Rust binary: real terminal per agent, a sidebar rolling every pane up to 🔴blocked/🟡working/🔵done/🟢idle with zero config, background server for detach/reattach (incl. `--remote` over ssh), and a local socket API + CLI agents can drive. It is the *only* candidate that natively nails criteria 1+2+3+4 together. Governance is the catch: created **2026-03-27** (~3 months old), and of ~1,000 commits **885 are from one person** (the rest bots) despite 12k stars — it is a very active but essentially solo project. Note the user's "v0.4" belief is stale: it's at **v0.7.1 (Jun 2026), 66 releases**. Pick it for capability; the risk is bus-factor-of-one, not abandonment.

**zellij** — Mature (34k★, ~190 contributors, MIT, since 2020) Rust terminal workspace with persistence, a scriptable CLI, and a real WASM plugin system. It has **no built-in agent-awareness** — you'd build a status plugin yourself. The most *stable* terminal-native base, but it does not match herdr's #1 differentiator out of the box.

**tmux + sesh/resurrect** — The user's current substrate, essentially. Rock-solid persistence, decades of stability, ISC license, superb CLI/control-mode for scripting. Zero agent-awareness beyond bell/hook hacks you wire yourself — which is exactly the pain point being escaped. Keep as fallback, not the destination.

**WezTerm native mux** — WezTerm already ships a mux server + `wezterm cli` that can spawn/list/manipulate panes programmatically, giving you criteria 2+3+4 on a very stable base (27k★, ~430 contributors, since 2018). No agent state layer — but combined with a thin status script driven by `wezterm cli`, it's a credible DIY path that avoids betting on a young project.

**claude-squad** — Terminal-native Go TUI (8k★, AGPL-3.0) that manages multiple agents each in its **own git worktree** with per-agent status — conceptually the closest OSS match to herdr's intent and genuinely worktree-first. Governance is only mildly better than herdr: ~2 primary maintainers (smtg-ai). Backs onto tmux for sessions; scripting is TUI-first, not an orchestration API.

**Conductor / emdash / Crystal(Nimbalyst) / Warp** — The GUI/Electron cohort. All show agent state and use worktrees, but violate criterion 4 (terminal-native): Conductor and Warp are closed macOS apps; emdash (YC W26, Apache-2.0, very active) and Crystal are Electron. None offer real detach/reattach-over-ssh. Crystal has **pivoted to Nimbalyst and its repo is stale (last push 2026-02)** — do not adopt. emdash is the healthiest of these but is a desktop app, not a driveable terminal fleet.

**container-use** — Dagger-backed (Apache-2.0, healthy governance), an MCP server + CLI giving agents isolated *container* environments. Solves isolation, not fleet visibility or worktree-native workflows; complementary to, not a replacement for, a multiplexer.

## Ranked shortlist (top 3)

1. **herdr** — Still the best single-tool fit: only option that natively delivers agent-awareness + persistence + scriptable API + terminal-native binary. **Nothing here is *more stable* while also matching its agent-awareness** — the alternatives that match #1 (Conductor/emdash/claude-squad) each fail another hard criterion or aren't meaningfully better-governed.
2. **WezTerm native mux + thin status script** — The "more stable" hedge: bet on WezTerm's proven mux/CLI (which you're adopting anyway) and script the blocked/working/done rollup yourself from Claude Code hooks. More work, near-zero abandonment risk.
3. **zellij (or claude-squad)** — zellij as the most stable terminal-native base if you'll build a status plugin; claude-squad if you want an OSS worktree-per-agent tool today and can tolerate its ~2-dev bus factor and TUI-only scripting.

## Verdict

**herdr is still the best despite its youth — there is no clear "more stable AND equally agent-aware" winner.** Every tool that matches herdr's headline agent-awareness is either a closed/Electron GUI (Conductor, Warp, emdash, Crystal — failing terminal-native + ssh persistence) or is itself a small-team project (claude-squad). The single most important finding for the decision: **herdr's stability risk is bus-factor, not activity** — it's only ~3 months old with 885/~1000 commits from one maintainer, *not* the abandoned v0.4 the user feared (it's v0.7.1, shipping daily). If that single-maintainer risk is unacceptable, the honest hedge is **WezTerm's own mux + `wezterm cli` + a homemade status layer**, trading herdr's polish for a foundation that cannot be orphaned. Mitigation if adopting herdr: it's a 10MB binary with an AGPL escape hatch and a plain socket/CLI API, so exit cost is bounded — keep the tmux scripts as a fallback and don't hard-couple your orchestrator to herdr-only APIs.
