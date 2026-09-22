# Prompt: MCP → CLI audit (run in a fresh session, own branch → own PR)

> Paste this into a fresh Claude Code session started in the **rhythms** repo (or wherever the MCP/agent config lives). Run it on a NEW branch; it should end by opening a PR. It is self-contained. Runs independently of any other audit.

## Why (context — do not skip)
Agent tools cost context: every connected MCP server injects its full tool schema into the model's context, whether used or not. Independent benchmarks (TOON/AXI study, Atlassian `mcp-compressor`, Anthropic/Cloudflare "Code Mode") show the reliable win is **"a CLI beats an MCP"** for the same capability — the MCP's schema overhead is pure context tax, and a CLI the agent calls via Bash costs ~nothing until used. TOON output formats add a further (smaller, less-proven, less-readable) saving; we are NOT adopting TOON here — only the CLI-over-MCP part, which is well-supported.

Goal: **find MCP servers we can replace with a CLI + a short instruction, remove them, and document the CLI usage** — reducing always-on context cost without losing capability.

## Steps

1. **Inventory every MCP the agent sees.** Check all sources:
   - `~/.claude.json`, `~/.claude/settings.json`, `~/.claude/mcp*.json`
   - project `.mcp.json`, `.claude/settings.json`, `.claude/settings.local.json`
   - `.cursor/mcp.json` and any Cursor/Codex MCP config
   - Distinguish **local/self-hosted MCPs** (candidates for CLI replacement) from **hosted claude.ai integrations** (managed; usually NOT swappable to a local CLI — note but don't force).
   Produce a table: MCP name · scope (global/project) · what it does · local or hosted · rough tool-count/schema size.

2. **For each local MCP, find the CLI equivalent.** Examples of the pattern:
   - a GitHub MCP → `gh` CLI
   - a Postgres/DB MCP → `psql` / the project's db scripts
   - a filesystem/search MCP → ripgrep/`fd`/native tools
   - a fetch/http MCP → `curl` (or the repo's context-mode `ctx_*` tools if those are the sanctioned path)
   For each: does a CLI cover the same capability at equal or better ergonomics? Verify the CLI is installed / installable. Note any capability the CLI genuinely can't match (keep those MCPs).

3. **Decide per MCP:** `REMOVE (CLI covers it)` · `KEEP (no CLI equal / hosted)` · `REPLACE-LATER (CLI exists but needs wrapper)`. Be conservative — only remove when the CLI is a real, tested substitute.

4. **For every REMOVE:** 
   - Remove the MCP from the relevant config file(s).
   - Add a concise instruction to the appropriate `AGENTS.md`/`CLAUDE.md` (or a small skill) telling the agent to use `<cli>` for that job, with 1–2 example invocations. Keep it terse (agent-ergonomic: short, copy-pasteable, low-token).

5. **Measure the win** (rough): sum of tool-schemas removed / approximate token reduction in the always-on context. State it plainly; don't overclaim.

6. **Verify nothing broke:** grep the repo + skills + agent files for references to the removed MCP tools; update or remove them. Confirm the CLIs run.

7. **Open a PR** titled `chore(agents): replace redundant MCPs with CLI instructions`. Body: the inventory table, per-MCP decisions + rationale, the CLI instructions added, the estimated context saving, and an explicit list of MCPs deliberately KEPT and why.

## Guardrails
- Do NOT remove hosted claude.ai integrations you can't replace locally — just note them.
- Do NOT adopt TOON/AXI output formats in this pass (separate, unproven, readability cost).
- Prefer reversible changes; the PR should be easy to revert per-MCP.
