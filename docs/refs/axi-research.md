# AXI (Agent eXperience Interface) — Research Notes

Source: https://axi.md/ (fetched 2026-07), GitHub `kunchenguid/axi`, plus `toon-format/toon`.
Author: "Kun" (Kun Chen, presented as an L8 principal engineer).

## 1. What AXI actually is

AXI is **not a protocol, not a runtime, and not a single library**. It is:

- **A set of ~10 design principles** ("design standards") for building CLI tools whose
  *output and command surface* are optimized for AI-agent ergonomics rather than human UX.
- **A catalog + convention.** An "AXI" is any CLI tool built to those principles. The site
  maintains a catalog of official reference implementations (`gh-axi`, `chrome-devtools-axi`,
  `lavish-axi`) and community ones (`npm-axi`, `sqlite-axi`, `slack-axi`, `gws-axi`, `notion-axi`,
  `metabase-axi`, etc.).
- **A position/argument:** that a *hand-crafted, agent-first CLI* beats both raw CLIs and MCP
  servers. The framing is explicitly "AXI over MCP."

How you "use" one: it's a normal shell CLI. Most AXIs are npm executables that **wrap** an
existing tool/API (e.g. `gh-axi` wraps the `gh` CLI; `chrome-devtools-axi` wraps
chrome-devtools-mcp) and re-shape the output into TOON with pre-computed summaries. The agent
just runs shell commands and pipes them (`| grep`, `| tail`). One AXI (`specops`) is shipped
embedded in a Claude skill rather than as a standalone binary, so the pattern is flexible.

## 2. The 10 principles

Organized into four categories (Efficiency / Robustness / Discoverability, roughly):

1. **Token-efficient output** — emit TOON instead of JSON (~40% fewer tokens).
2. **Minimal default schemas** — 3–4 fields per list item, not 10+.
3. **Content truncation** — truncate big text fields with a size hint + `--full` escape hatch.
4. **Pre-computed aggregates** — include `totalCount`, CI summaries ("27 passed, 0 failed"),
   so the agent avoids round-trips. Also applied to *actions* (combined ops like `fill --submit`).
5. **Definitive empty states** — explicit "0 results", not ambiguous blank output.
6. **Structured errors & exit codes** — idempotent mutations, structured errors, no interactive
   prompts, fail loud on unknown flags.
7. **Ambient context** — opt-in session integration first, then an on-demand skill.
8. **Content first** — show data, not a wall of help text.
9. **Contextual disclosure** — append relevant next-step commands *after* output, not all upfront.
10. **Consistent help** — concise per-subcommand `--help` when the agent needs it.

## 3. Token / latency claims — EVIDENCE QUALITY

**Verdict: better-than-marketing, but weak-to-moderate as science. Directionally credible, not authoritative.**

There *is* real data, not just assertion:

- **Two benchmarks, published with raw artifacts.**
  - Browser automation: 490 runs (14 tasks × 7 conditions × 5 repeats).
  - GitHub API: 425 runs (17 tasks × 5 conditions × 5 repeats), with `results.jsonl`,
    per-run judge verdicts, and CSV published in the repo. This is reproducible and above
    the bar for a typical blog post.
- **Headline results** (GitHub bench): AXI 100% success @ $0.050/task/3 turns; raw `gh` CLI 86% @
  $0.054; MCP variants 82–87% @ $0.101–$0.148 and 6–8 turns. Browser bench shows the same shape.
- **The 40% TOON claim is independently corroborated.** The separate `toon-format/toon` project
  benchmarks TOON at ~39.9% fewer tokens than JSON with *equal-or-better* retrieval accuracy
  (76.4% vs 75.0% acc). So the token number is not AXI-specific hand-waving.

Caveats that lower confidence:

- **n=5 repeats per cell; no confidence intervals or significance tests reported.** Cost/turn
  deltas (esp. AXI vs raw CLI: $0.050 vs $0.054) are small and within plausible noise.
- **Single model, single judge, both Claude Sonnet 4.6.** LLM-as-judge grades success; no human
  validation of the judge. Self-consistent but not model-independent.
- **Narrow task universe / single repo** (`openclaw/openclaw`) for GitHub bench — risk of tasks
  tuned to where AXI shines (e.g. `tables --url`, combined ops).
- **Author is also the tool author** — the reference AXIs were built to win these benchmarks.
  This is advocacy research, not a neutral third-party study.
- The biggest wins come from **specialized combined commands** (fewer turns), *not* purely from
  TOON. Much of the "AXI beats MCP" gap is really "CLI beats MCP" (schema overhead: MCP used
  2.3× the input tokens) — which the author's own related-work citations already established.

Bottom line on claims: the ~40% token saving is real and independently replicated; the
end-to-end "cheaper + more reliable than MCP" result is plausible and backed by open data, but
under-powered statistically and produced by an interested party. Treat as a strong hypothesis,
not proof.

## 4. Side effects / tradeoffs

- **Human readability:** TOON is more readable than minified JSON but a custom-ish format; humans
  and existing tooling expect JSON. You lose `jq`, schema validators, and IDE/type tooling.
- **Format fragility:** TOON's savings depend on *uniform arrays of objects*. For deeply nested
  or non-uniform data, TOON can be *worse* than compact JSON (per TOON's own docs); for flat
  tables, CSV beats it. Wrong data shape = negative ROI.
- **Build/maintenance cost:** every AXI is a bespoke wrapper you must build, version, and keep in
  sync with the underlying API/CLI. Pre-computed aggregates and combined ops are extra logic to
  maintain. This is real engineering, not config.
- **Loss of type safety / discoverability** that MCP gives for free (typed schemas, tool
  catalogs). Agents rely on `--help` + convention instead.
- **Lock-in / fragmentation risk:** AXI is one person's convention with a small community catalog;
  TOON is a separate spec. No standards body. Betting on it is betting on adoption.
- **Determinism vs flexibility:** opinionated truncation/aggregation can hide data the agent
  actually needed (`--full` mitigates but adds a round-trip).

## 5. Alternatives / prior art

AXI is one entry in an active "agent-first tooling" space:

- **MCP (Model Context Protocol, Anthropic)** — the incumbent AXI positions against. Typed tools,
  discoverable, but heavy schema/token overhead.
- **CLI-over-MCP wrappers:** **Atlassian `mcp-compressor`** (wraps any MCP server into one CLI;
  AXI cites it as validating the CLI-over-MCP thesis, ~$0.091/task).
- **"Code Mode" / code execution with MCP:** Anthropic ("code execution with MCP") and Cloudflare
  (Varda/Pai, "Code Mode") — have the agent write TS against a tool API instead of direct calls.
  Reliable but slowest/most expensive in AXI's browser bench.
- **Mao & Pradhan (Smithery) benchmark** — 756 runs, raw API vs CLI vs MCP; found MCP more
  reliable but CLI far cheaper; explicitly left "would a hand-crafted agent-first CLI win?" open —
  the gap AXI claims to fill.
- **Serialization formats for LLMs:** **TOON** (used by AXI), plus CSV-for-LLMs, YAML, and
  compact-JSON — all benchmarked in the TOON repo. TOON is the token-efficiency prior art AXI
  depends on.
- **Documentation/context conventions:** **`llms.txt`** (site → LLM-readable content) and
  **`AGENTS.md`** (repo → agent instructions). Adjacent, complementary conventions rather than
  competitors — they shape *context*, AXI shapes *tool I/O*.

## Bottom line — is AXI worth adopting for a solo Claude-Code developer?

**Adopt the principles; don't over-invest in the framework.**

- **High-value, low-cost, do it now:** For any tool *you already wrap* for Claude Code, apply the
  cheap principles — minimal default fields, `totalCount`/aggregate summaries, definitive empty
  states, truncation with `--full`, structured errors, contextual next-step hints. These reduce
  turns and context bloat with almost no downside and no lock-in. This is just good agent-tool
  hygiene and matches Anthropic's own tool-design guidance.
- **Prefer CLIs + shell composability over bespoke MCP servers** for solo/local workflows — the
  strongest, most defensible takeaway from the benchmarks (and it's really "CLI > MCP" more than
  "AXI > everything").
- **TOON: use selectively.** Worth it for uniform tabular/list output going into the model; skip
  it for nested/irregular data (compact JSON) or flat tables (CSV). Measure, don't cargo-cult the
  40%.
- **Don't:** rebuild your whole toolchain around the AXI catalog, treat the benchmark deltas as
  gospel, or assume the format is a stable standard. It's one engineer's well-argued, open-data
  advocacy — a good playbook, not a proven, neutral standard.
