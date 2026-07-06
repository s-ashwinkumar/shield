# Prompt: AGENTS.md slimming + skills evaluation (fresh session, own branch → own PR)

> Paste into a fresh Claude Code session in the **rhythms** repo (and it should also inspect `~/.claude` global skills/AGENTS.md). Run on a NEW branch; end by opening ONE PR covering both parts. Self-contained. The two parts are independent — you MAY run them as two parallel subagents and merge results into one PR.

## Principles (from Kun Chen's workflow — apply, don't cargo-cult)
- **AGENTS.md should be lean.** It loads into *every* session's context. Content that's only needed *situationally* belongs in a **skill** (loaded on demand), not in always-on AGENTS.md. Keep in AGENTS.md only what's true and needed for (nearly) every task: project overview, repo layout, key conventions, how to run/test, hard rules.
- **Skills must earn their place.** Be skeptical of skills that claim to "make the agent better" without rigorous evidence. A skill is worth keeping only if it (a) is invoked in real workflows, (b) encodes non-obvious, correct, current knowledge, and (c) isn't duplicated by AGENTS.md or another skill.

## Part A — Slim & sharpen AGENTS.md
1. Locate all agent-instruction files: root `AGENTS.md` (+ its symlinks like `CLAUDE.md`/`README.md` — note the symlink, edit the real file), per-service `AGENTS.md` (webui/railsapi/mlai/…), `~/AGENTS.md` / `~/.claude/CLAUDE.md`, `claude.local.md`.
2. For each, classify every section: `KEEP (always-needed)` · `MOVE-TO-SKILL (situational)` · `DELETE (stale/duplicated/obvious)`. Flag anything factually stale (verify against the current repo — don't trust the doc).
3. For `MOVE-TO-SKILL` items, draft the skill (name, `description` trigger, body) and remove the content from AGENTS.md, leaving at most a one-line pointer if needed.
4. Result: a tighter AGENTS.md (report before/after line + approx token counts) with situational knowledge relocated to on-demand skills.

## Part B — Evaluate the skills we use
1. Enumerate all skills: project (`.claude/skills/`, `docs/skills/`, `.agents/skills/`), global (`~/.claude/skills/`), and plugin skills. For each: name · trigger/description · where it lives · last modified.
2. For each skill, judge and label: `KEEP` · `REVISE` (stale/verbose/unclear trigger) · `REMOVE` (unused, duplicated, or unsubstantiated "magic"). Evidence to weigh: is it actually invoked? does it duplicate AGENTS.md or another skill? is its knowledge still true against the current codebase? is any efficacy claim backed by anything?
3. Check for drift/duplication (e.g. a canonical skill copied into multiple locations that have since diverged) and note the source-of-truth problem.
4. Result: a skills scorecard table + concrete edits/removals for the `REVISE`/`REMOVE` ones.

## Deliverable
Open ONE PR titled `chore(agents): slim AGENTS.md + skills audit`. Body must include:
- Part A: AGENTS.md before/after (sections kept/moved/deleted, token delta), list of new skills created from moved content.
- Part B: the skills scorecard (keep/revise/remove + reason each), and any drift/duplication found.
- A short "risks / anything I was unsure about" section — do NOT silently delete anything load-bearing; when unsure, flag rather than remove.

## Guardrails
- Verify staleness against the actual code before deleting — the doc may lie.
- Preserve hard rules (security, "do not do X") even if they seem obvious.
- Keep everything terse and agent-ergonomic (short, high-signal).
