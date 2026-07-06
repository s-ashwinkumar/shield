# Lessons from Kun Chen's agentic workflow (transcript) — mapped to rdev

Source: `l8-agentic-workflow-transcript.txt`. Each lesson classified: **NEW** (rdev lacks) vs **HAVE** (rdev already does) vs **ENHANCE** (rdev has a weaker version). Recommendation: fold into Phase 1 / defer to Phase 2 / personal / skip.

| # | Lesson | rdev status | Recommendation |
|---|---|---|---|
| 1 | **AXI — agent-ergonomic tooling.** 10 design principles; token-efficient output saves ~40% vs JSON; benchmark tools for agent turns/tokens. | ENHANCE (context-mode is philosophically aligned) | **Phase 1 design principle** — the `rdev-mux` adapter + `rlocal` lease CLI + docker-exec wrappers should emit terse, single-turn, token-lean output. Free; just a rule. |
| 2 | **no-mistakes = the gate-to-PR pipeline.** Runs in an ISOLATED throwaway worktree (validation never touches your repo) → infers real intent from the AGENT SESSION → rebases on latest main + resolves conflicts upfront → adversarial review in a FRESH context window (self-corrects obvious, escalates ambiguous/product) → e2e → docs → emits a PR with intent summary + **evidence** (screenshot/video/log proving it works). Triggerable as a skill. You never watch it; return when "all checks passed." | ENHANCE (rdev has /review adversarial+codex, /qa, rpromote, pipeline) | **Phase 1.5 pipeline upgrades — steal 4 specifics:** (a) run validation in an isolated worktree; (b) infer intent from the session, not just the diff; (c) upfront rebase-on-main + conflict resolve as a step; (d) **PR evidence artifact** (screenshot/video/log). |
| 3 | **gnhf — overnight autonomous loops with caps.** Token cap / iteration cap / stop condition — more precise than Claude Code `/go` (which can burn your weekly quota). Keeps agents running long so you're freed up. | **NEW — rdev has nothing** | **Strong candidate — directly attacks the >10-sessions pain.** Some streams self-drive unattended on verifiable objectives → fewer live-attention sessions. rbuild already does autonomous build; extend with caps + loop-until-condition. Phase 1.5 standalone OR Phase 2 (pairs with orchestrator). |
| 4 | **Memory ramp = accumulated corrections.** Project memory file = collective learning of all sessions; built by correcting the agent and telling it to store the learning; plain markdown; periodically compacted when bloated. Global memory + skills too. | ENHANCE (user has memory system; `/learn` planned in handover) | **Validates `/learn` (Phase 2).** The manual ritual — "correct → append learning to project memory" — is adoptable **free now**. |
| 5 | **lavish — interactive planning via HTML artifacts.** Instead of a wall-of-text plan, agent renders an HTML artifact in the project's design system to visualize options; you give feedback on specific parts. Installed as a skill so it auto-triggers for planning. | ENHANCE (rdev planning = coordinator + markdown = the "wall of text" Kun criticizes) | **Phase 2 / optional** — fits the "lighthouse-of-the-week" UI work where visualizing options matters. (Note: superpowers brainstorming has a parallel "visual companion".) |
| 6 | **Voice input (OpenSuperWhisper).** Talking ~3× faster than typing (Stanford paper); custom vocabulary via system prompt for project names. | N/A (personal) | **Personal — essentials repo.** No rdev build. Low priority. |
| 7 | **Captain mindset / bottleneck shift.** Once orchestration is handled you run out of asks → bottleneck shifts to knowing what matters (users, competitive landscape, good "treasure map"/direction). | Meta | Informs **Phase 2** orchestrator philosophy. |

## The three worth acting on soon
1. **gnhf-style capped autonomous loops (#3)** — the only genuinely NEW capability, and it hits the core pain. Fewer sessions need you live if some grind unattended with safe caps.
2. **no-mistakes evidence artifact + isolated-validation-worktree (#2)** — concrete upgrades to rdev's existing review/promote pipeline; the "evidence in the PR" idea is high-value (you apply judgment on proof, not diffs).
3. **AXI ergonomics (#1)** — a free design rule for the CLIs/adapters we're about to build in Phase 1.

## Decisions after deep research (2026-07-05)

- **gnhf:** DEFERRED to Phase 2 or later (user call).
- **AXI:** token claim only weakly substantiated (self-judged n=5), TOON hurts readability → **do NOT adopt TOON/AXI wholesale.** The robust, independent signal is *CLI-beats-MCP* (schema overhead). Action = **MCP→CLI audit**, delivered as a parallel-runnable prompt: `docs/prompts/mcp-to-cli-audit.md`. Details: `axi-research.md`.
- **no-mistakes:** **BORROW, don't swap** rdev's /review+/qa. Steal: (1) autonomous-QA **evidence contract** (infer intent → run tests → force screenshot/video/log capture attached to PR — this is the fix for "QA never runs autonomously"); (2) **review-before-test** ordering (rationale: agent reads fresh code, not code it just touched); (3) `risk_level` + human-gate-on-review. Skip his bare-repo/daemon transport (rdev orchestrates; rpromote going away). Details: `no-mistakes-research.md`. → fold into Phase 1 or 1.5 (pending user).
- **lavish:** **ADOPT AS-IS** — matches the plan→interactive-HTML→surgical-feedback pain exactly. Install `npx skills add kunchenguid/lavish-axi --skill lavish`; trigger `/lavish`. No MCP/cloud, low cost. Standalone quick-win, independent of the rdev redesign. Details: `lavish-research.md`.
- **AGENTS.md slimming + skills eval:** delivered as a parallel-runnable prompt: `docs/prompts/agents-md-and-skills-audit.md` (one PR, two parts).

## Notably: we already independently arrived at his biggest ideas
- **State-at-a-glance (blocked/working/done)** → we're adopting via **herdr**.
- **treehouse (worktree automation)** → rdev's worktree lifecycle.
- **firstmate (orchestrator)** → our **Phase 2**.
So the transcript mostly *validates* the direction; the deltas are gnhf, the no-mistakes evidence/isolation specifics, and AXI ergonomics.
