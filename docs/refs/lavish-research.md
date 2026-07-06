# lavish-axi research

Research on **lavish-axi** ("Lavish Editor") by Kun Chen (`kunchenguid`). Repo: https://github.com/kunchenguid/lavish-axi · npm: `lavish-axi` · listed as an official AXI on axi.md. ~1.6k stars.

Tagline: "HTML is the new markdown. Lavish is the new editor for your HTML artifacts." It's the human-review counterpart to Kun's other AXIs (gh-axi, chrome-devtools-axi; sibling tooling no-mistakes, treehouse, firstmate).

Legend: **[V]** verified from README/SKILL.md, **[I]** inferred.

## 1. How it works end-to-end

1. **Agent generates an HTML artifact** [V]. The skill tells the agent: when about to give a plan/comparison/diagram/table/report — anything easier to grasp visually than prose — write a rich interactive HTML file, default location `.lavish/<name>.html` in the working dir.
2. **Design system pickup is prompt-driven, not injected** [V]. Lavish does NOT inject any design system — the saved HTML renders identically in `lavish-axi` or a plain browser. Instead the skill instructs the agent to choose styling in strict priority order: (a) user-requested look; (b) inspect the *subject* project (the product the artifact represents, which may differ from cwd) and match its Tailwind/theme config, CSS variables, design tokens, component library, brand assets, or existing styled pages; (c) only if both empty, run `lavish-axi design` for a copy-pasteable Tailwind v4 + DaisyUI v5 CDN fallback (default `luxury` theme) plus a content-to-playbook router and pinned Mermaid CDN snippet.
3. **Serving / opening** [V]. `npx -y lavish-axi <html-file>` opens/resumes a review session in a **local browser tab** served by a **local express.js server**. The artifact runs in an **iframe**; Lavish injects a small SDK for annotations, snapshots, feedback controls, and render-time layout checks. Sessions are keyed by canonical HTML file path (no opaque IDs). Local assets (img/css/fonts/scripts) must sit in the same dir and use relative paths (never leading `/`). Live-reload watches the file and preserves scroll.
4. **Feedback flows back via long-poll** [V]. The user annotates in the browser — pinpoints **DOM elements, selected text ranges (with range anchors), or Mermaid diagram nodes** — and can queue prompts / type messages. Native form controls are interactive automatically; `window.lavish.queuePrompt()` queues answers. The agent runs `npx -y lavish-axi poll <html-file>`, which **long-polls silently** until the user acts or the browser reports fresh `layout_warnings`. Poll returns the annotations/prompts as TOON (token-efficient). Agent applies feedback, edits the HTML, then polls again with `--agent-reply "<msg>"` to reply in the browser and continue the loop. `npx -y lavish-axi end <html-file>` finishes.
5. **Layout self-check** [V]. The injected SDK reports render-time `layout_warnings` (e.g. overflow issues); the agent fixes fresh error-severity ones before bothering the human, and proceeds-with-a-note when warnings are persistent/low-severity.
6. **Session etiquette** [V]. Tracks who ended the session. If the *human* clicks "End session," a plain re-open command refuses to reopen (returns guidance); agent must deliver remaining updates in chat. `--reopen` overrides only when warranted.
7. **Optional hosted sharing** [V]. Export/share via third-party **ht-ml.app** is explicit, opt-in, bearer-token gated (`LAVISH_AXI_HTML_APP_TOKEN`), with inline asset caps. Not part of the core local loop.

## 2. Install / trigger

- **Recommended** [V]: `npx skills add kunchenguid/lavish-axi --skill lavish` — installs the `lavish` skill (Agent Skills format) into `.claude/skills/` (or `-g` for `~/.claude/skills/`). No global npm install; the CLI rides along via `npx -y lavish-axi`.
- **Trigger** [V]: In Claude Code (skills-as-slash-commands), invoke `/lavish <what to show>`. Otherwise the agent auto-loads the skill when it recognizes a plan/comparison/diagram/report task. Skill frontmatter also carries Hermes metadata for Hermes-compatible harnesses. There is a private `lavish-design` brand skill hidden unless `INSTALL_INTERNAL_SKILLS=1`.
- **Zero-setup** [V]: no skill needed — just tell any capable agent: "Use `npx lavish-axi` to write a plan for what we discussed."

## 3. Dependencies / assumptions

- **Harness** [V]: Claude Code compatible (explicitly cited); any capable CLI agent works — it's "just a CLI."
- **Runtime** [V/I]: Node + `npx` (fetches `lavish-axi` from npm on demand) [V]. Local **express.js** server + a browser [V]. Node/npm required [I].
- **AXI dependency** [V]: none at runtime — AXI is a design philosophy (agent-ergonomic CLI, TOON output, long-poll, contextual disclosure), not a required framework. No MCP server. No cloud in the core loop (ht-ml.app is opt-in).

## 4. Adoption cost (Claude Code solo dev wanting exactly this)

**Very low.** One command (`npx skills add kunchenguid/lavish-axi --skill lavish`), then `/lavish`. No servers to run manually, no npm global, no config, no API keys (unless using ht-ml.app sharing). Requires Node/npx + a browser. The interactive review loop (element/text/Mermaid pins → long-poll → agent edits HTML → reply-in-browser) is exactly the "agent plans → interactive HTML the user gives surgical feedback on" workflow requested, and it works out of the box. Main "cost" is trusting `npx -y` to fetch an external package each session, and the agent spending tokens generating good HTML (mitigated by the design-system guidance + `lavish-axi design` fallback).

## 5. Comparison: superpowers "brainstorming visual companion"

[I, from local skill list] The superpowers `brainstorming` skill is a *pre-implementation intent/requirements exploration* flow; its visual companion opens a browser tab to show mockups. Key difference: superpowers' companion is (as far as visible here) a **one-way display** of mockups during brainstorming, whereas Lavish is a **structured bidirectional review protocol** — pin a specific element/text-range/diagram-node, queue it, agent long-polls and picks it up, edits, and replies back into the same browser session, with session-end etiquette and layout self-checks. Lavish is purpose-built for the surgical-feedback loop; the brainstorming companion is a lighter visualization aid inside a different (requirements-gathering) workflow. Could not inspect the companion's source here, so exact capabilities are inferred.

## Verdict

**Adopt lavish-axi as-is.** It is precisely the requested capability (agent → interactive design-system-matched HTML → surgical element/text/diagram feedback → agent edits, no markdown copy-paste), install is one command, it's Claude-Code-native and local-first with no server babysitting. Building a lighter equivalent isn't worth it — the long-poll loop, iframe SDK, annotation anchoring, and layout checks are the hard parts and are already solved. Use the superpowers brainstorming companion only for its distinct upfront requirements-exploration role, not as a substitute for the review loop. Only caveat for a security-conscious solo dev: it fetches from npm via `npx` each run — pin/vendor the version if that matters.
