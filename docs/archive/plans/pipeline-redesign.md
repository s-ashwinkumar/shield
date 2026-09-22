# rdev Pipeline Design -- Final

## Architecture

Claude Code only. Uses **custom subagents** for pipeline stages within a single session.

```
rstream USENG-492

  ┌─────────┐    ┌─────────┐    ┌──────────┐    ┌───────────┐    ┌────────┐
  │  PLAN   │───▶│  BUILD  │───▶│ UX REVIEW│───▶│CODE REVIEW│───▶│   PR   │
  │interact │    │autonomo │    │user gate │    │loop x N   │    │auto    │
  └─────────┘    └─────────┘    └──────────┘    └───────────┘    └────────┘
  rbuild →                      rpromote →                       notify
                                rforward →
```

## Agent Architecture

```
coordinator (main agent, runs the pipeline)
├── spawns → builder (code + tests, full edit permissions)
└── spawns → reviewer (read-only, fresh eyes, no edit)
```

- **coordinator.md** -- orchestrates stages, manages state, spawns subagents
- **builder.md** -- implements code, fixes review findings (bypassPermissions)
- **reviewer.md** -- reviews code against standards (read-only tools only)

## Commands

| Command | What it does |
|---------|-------------|
| `rdev` | Start tmux session + services |
| `rstream <ticket>` | Create worktree + launch coordinator for planning |
| `rbuild <name>` | Approve plan → send build instruction to coordinator |
| `rpromote <name>` | Checkout stream branch in main repo for testing |
| `runpromote <name>` | Restore main repo to previous branch |
| `rforward <name>` | Unpromote + advance to code review loop |
| `rstatus` | Show streams with pipeline stages |
| `rclean <name>` | Tear down worktree + tmux window |

## Key Decisions

1. **Claude Code only** -- uses subagents, `-r` resume, `--agent` flag
2. **Subagents over Agent Teams** -- features are independent (no inter-feature communication needed), Agent Teams adds unnecessary complexity
3. **Reviewer cannot edit** -- separation of concerns makes the review loop trustworthy
4. **Shell scripts are thin wrappers** -- they handle git/tmux, then send instructions to the coordinator via tmux send-keys
5. **State on disk** -- `.rdev/state.json` tracks pipeline stage, enables `rstatus`
6. **Promote/unpromote** -- explicit branch switching in main repo because worktrees can't run services

## Considered and Rejected

- **Agent Teams**: designed for parallel inter-agent communication, our features don't need to talk to each other
- **Agent SDK**: adds Python/TS dependency, subagents via `.claude/agents/` are simpler
- **Agent-agnostic design**: Claude Code's subagent system is the key differentiator, no reason to abstract it away
- **gstack approach**: pure skills without orchestration, requires external tool (Conductor) for multi-agent
