# no-mistakes — Research Notes

**Tool:** `git push no-mistakes` by Kun Chen (ex-Meta/Microsoft/Atlassian L8 principal; author of AXI/axi.md, lavish, treehouse, firstmate, "goodnight-have-fun/gnhf").
**Repo:** https://github.com/kunchenguid/no-mistakes · **Docs:** https://kunchenguid.github.io/no-mistakes/
**Sources indexed (ctx labels):** `no-mistakes README`, `no-mistakes intro`, `no-mistakes gate-model`, `no-mistakes quickstart`, `no-mistakes pipeline concept`, `no-mistakes pipeline-steps ref`, plus video transcript `l8-agentic-workflow`.

All claims below are **verified from source** (docs + video transcript) unless marked *(inferred)*.

---

## 1. The exact ordered pipeline (VERIFIED)

Order is **fixed and NOT configurable** (what each step *runs* is configurable; the order is not):

```
intent → rebase → review → test → document → lint → push → pr → ci
```

| # | Step | What it does | Default auto-fix limit |
|---|------|--------------|------------------------|
| 1 | **Intent** | Use agent-supplied intent, else infer author intent from recent local agent transcripts (Claude Code, Codex, OpenCode, Rovo Dev, Pi, Copilot). Best-effort; never blocks. | n/a |
| 2 | **Rebase** | Fetch fresh upstream + configured branch target, rebase onto them, resolve conflicts up front. Stops if branch would silently bundle unpushed default-branch commits. Skips rest if no diff remains. | 3 |
| 3 | **Review** | Adversarial AI code review of the diff in a **fresh context window**. Returns findings (error/warning/info) + `action` (no-op / auto-fix / ask-user) + a `risk_level` (low/medium/high) and `risk_rationale`. | **0** (requires human approval) |
| 4 | **Test** | Run baseline test command, then agent validates change against intent with **evidence-oriented tests**. | 3 |
| 5 | **Document** | Update docs to match working code; report unresolved gaps. | initial pass |
| 6 | **Lint** | Run configured/detected linters + static analysis. | 3 |
| 7 | **Push** | Safely push validated branch to configured target (guarded against discarding unincorporated commits). | n/a |
| 8 | **PR** | Create/update the pull request with intent, what changed, how tested, evidence, and pipeline findings. | n/a |
| 9 | **CI** | Poll CI, watch PR mergeability, auto-fix failures + merge conflicts ("babysit until merged"). | 3 |

This matches the video description exactly (branch/commit → isolated worktree → infer intent → rebase+resolve → adversarial fresh-context review → e2e test w/ evidence → docs → lint → PR + CI babysitting).

---

## 2. Where functional QA / e2e sits — and why review comes first (VERIFIED)

**Test (step 4) comes AFTER Review (step 3).** The docs give an explicit rationale:

> **"Review before test** so the agent reads fresh code, not code it may have touched during fixes."

Rationale chain from the docs:
- **Review before test** → reviewer sees the original diff, uncontaminated by any fix commits.
- **Document after test** → docs are written against code *known to work*.
- **Lint last among local checks** → doesn't churn over code that may still change.

So the ordering answer to "why would adversarial review come before functional QA?": Review is a **static, diff-based** pass meant to catch defects and escalate intent-challenging questions cheaply *before* spending time executing/validating. Also, Review is the only step with auto-fix limit `0` (hard human gate), so it front-loads the human-judgment checkpoint. Test then validates the (possibly review-fixed) behavior and produces evidence. This is a defensible design, not an oversight.

Note: e2e/QA is **one step (Test)**, not a separate phase. It combines a baseline test command AND agentic evidence validation.

---

## 3. How QA runs autonomously (VERIFIED — this is the key part for rdev)

This directly addresses the "QA has always been manual" pain. no-mistakes **does run functional/e2e verification autonomously**:

- **Baseline:** if `commands.test` is configured, it runs that first (via `sh -c` / `cmd.exe /c`), captures output; non-zero exit = `error` finding.
- **Agentic evidence validation:** if no test command is set, OR user intent is available after the baseline passes, the pipeline agent **validates the change with evidence-oriented tests or manual checks** against the inferred intent. It returns structured findings (severity + description + action).
- **Visual evidence for UI/frontend:** for "UI, HTML, CSS, browser, visual layout, or copy-placement changes, the agent attempts reviewer-visible visual evidence" — **screenshots, images, videos, GIFs, or rendered HTML artifacts** — and must explain in `testing_summary` when it *couldn't* capture them.
- **Evidence artifacts** land in an `artifacts` array attached to the run/PR:
  - `path` — repo-relative or absolute under the temp `no-mistakes-evidence/<runID>` dir (or in-repo `<test.evidence.dir>/<branch-slug>` if `test.evidence.store_in_repo: true`)
  - `url` — externally-visible link
  - `content` — short logs / command output shown directly in the PR
- The video confirms: PR shows intent + what changed + how tested + **clickable evidence (screenshot / video demo / log file)** proving the change works.

**How the browser/e2e actually runs** *(inferred)*: the docs don't pin a specific harness; the agent is prompt-steered to produce visual evidence and Kun's ecosystem includes a **Chrome DevTools AXI** browser tool. Kun's global memory rule ("always start bug fixes by reproducing end-to-end as an end user would") is the cultural driver. So autonomy = **agent + intent + evidence-capture prompt contract**, not a fixed Playwright/Cypress dependency. The mechanism is: infer intent → tell the agent to prove the intent holds → require it to attach reviewer-visible artifacts.

---

## 4. Packaging (VERIFIED)

Two entry points, same fixed pipeline:

1. **Git-remote gate (the "real" mechanism):** `no-mistakes init` puts a **local bare git repo** between your working repo and origin. It installs a `post-receive` hook, adds a `no-mistakes` remote, and runs a **daemon** (SQLite state + IPC socket). `git push no-mistakes <branch>` triggers the pipeline in a **disposable/detached worktree** under `~/.no-mistakes/worktrees/`. `origin` is never hijacked. `--fork-url` supports fork-based contribution (push to fork, PR against parent).
2. **Agent skill:** `init` installs a user-level `/no-mistakes` skill at `~/.claude/skills/no-mistakes/SKILL.md` and `~/.agents/skills/no-mistakes/SKILL.md`. You can just **type "no mistakes"** to the agent to gate a task or existing committed work. The skill drives `no-mistakes axi` — a non-interactive **TOON** (token-efficient) interface to the same approval flow.
3. **Interaction surfaces:** a **TUI** and an **AXI** client (`no-mistakes axi respond` to approve/fix/skip; `yolo` mode auto-resolves paused steps). Steps pause for human approval on error/warning findings.

**Strictness config:** each step has an `auto_fix.<step>` limit (Review defaults to `0` = always ask). Firstmate exposes a per-repo strictness choice — the "**full gate to PR**" option is exactly "use no-mistakes as the validation pipeline for every change." Distribution: install script → binary in `~/.no-mistakes/bin`, macOS/Linux/Windows, self-hosted telemetry (opt-out via `NO_MISTAKES_TELEMETRY=0`).

---

## 5. Dependencies / assumptions (VERIFIED)

- **git** required. Assumes a working repo with an `origin` remote.
- **One supported agent binary:** claude, codex, `acli` (Rovo Dev), opencode, pi, or copilot — or `acpx` for ACP targets. **Agent-agnostic with ordered fallbacks.**
- **For PR/CI:** `gh` (GitHub), `glab` (GitLab), Bitbucket Cloud creds, or `az` + azure-devops extension.
- **Worktrees:** hard dependency — the whole pipeline runs in a disposable worktree so your working dir is never touched.
- **Daemon** must be running (started/refreshed by `init`).
- Evidence writes are a **soft** prompt-steered boundary (temp `no-mistakes-evidence` dir), **not OS-level sandboxing**.
- Intent inference reads **local agent transcripts** — assumes you ran the agent locally in a supported harness.

---

## Verdict: swap vs. borrow (for rdev's `/review` + `/qa`)

**Borrow, don't wholesale swap.** rdev already has an isolated-worktree pipeline (`rbuild`/`rpromote`/etc.) and its own `/review` + `/qa` skills; no-mistakes' *transport* (bare-repo gate + daemon + push-triggered runs) is heavier than rdev needs and would duplicate rdev's promotion machinery. But three ideas are worth stealing directly:

1. **The autonomous-QA evidence contract** — the single most valuable piece. Make `/qa` infer intent, run e2e against that intent, and *require* it to emit reviewer-visible artifacts (screenshot/video/log) into a per-run evidence dir surfaced in the PR. This is the concrete answer to "QA has always been manual."
2. **Ordering rationale** — run review on the *pristine* diff before any fix commits; validate/test after; docs after test; lint last. rdev's `/review` and `/qa` should adopt this ordering + the `risk_level` output so low-risk PRs can skip deep human review.
3. **Structured findings + human-gate on Review only** (`auto_fix.review: 0`, ask-user for intent-challenging findings) — a clean model for what to auto-fix vs. escalate.

Skip: the bare-repo/daemon/remote gate, the TOON/AXI TUI, and firstmate integration — rdev's harness already covers orchestration. If wanting a fast path, `no-mistakes init --fork-url` could be trialed on one repo to feel the evidence artifacts before reimplementing in rdev's skills.
