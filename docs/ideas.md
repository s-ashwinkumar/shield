# Ideas parking lot

Not commitments — things worth revisiting. Date each entry.

## 2026-07-12 · Remote captain access
The first mate / captain is a plain Claude Code session in tmux window 0, so
remote access comes free two ways: (1) `tmux attach` from any device over SSH,
(2) **Claude Code remote control** — attach to the same live session from
claude.ai/code on another device. Design attention items so they read well on
a small screen (short summary + inline-answerable). No build needed until we
want push-to-phone.

## 2026-07-12 · Daily-aid agent (separate from first mate)
The "D" role deliberately kept OUT of the first mate: a standing personal
agent for Linear triage, Slack conversation digestion, daily prep ("what
should I look at today?"). Different context, tools, and trust envelope than
fleet management. Candidate substrate: **Hermes agent** (research what it
actually offers before building — don't assume). Builds on Kun's pattern of
role-separated agents.
