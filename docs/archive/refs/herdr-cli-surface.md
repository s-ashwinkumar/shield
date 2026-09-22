# Herdr CLI surface (v0.7.1) — captured for the rdev-mux adapter

Captured 2026-07-06 from `herdr <sub> --help` on the real install. All subcommands are "helpers over the socket API" — safe to script. Many support `--json`.

## Worktree lifecycle (native — can subsume rstream/treehouse worktree bits)
```
herdr worktree list   [--workspace ID | --cwd PATH] [--json]
herdr worktree create [--workspace ID | --cwd PATH] [--branch NAME] [--base REF] [--path PATH] [--label TEXT] [--focus|--no-focus] [--json]
herdr worktree open   [--workspace ID | --cwd PATH] (--path PATH | --branch NAME) [--label TEXT] [--focus|--no-focus] [--json]
herdr worktree remove --workspace ID [--force] [--json]
```
Note: `--path` lets us place the worktree INSIDE the rhythms mount (`~/code/rhythms/.claude/worktrees/<stream>`) as the container-centric model requires.

## Agent (spawn + drive + state)
```
herdr agent start <name> [--cwd PATH] [--workspace ID] [--tab ID] [--split right|down] [--env K=V] [--focus|--no-focus] -- <argv...>
herdr agent list | get <target> | read <target> [--source visible|recent|recent-unwrapped] [--lines N] [--format text|ansi]
herdr agent send <target> <text>        # literal text (no Enter)
herdr agent rename <target> <name>|--clear | focus <target> | attach <target> [--takeover]
herdr agent wait <target> --status idle|working|blocked|unknown [--timeout MS]
herdr agent explain <target> [--json]    # why it's in a given state
```

## Pane control
```
herdr pane list [--workspace ID] | get <id> | current | layout | process-info
herdr pane split [<id>|--current] --direction right|down [--ratio F] [--cwd PATH] [--env K=V] [--focus|--no-focus]
herdr pane send-text <id> <text> | send-keys <id> <key...> | run <id> <command>   # run = text + Enter
herdr pane read <id> [--source visible|recent|recent-unwrapped] [--lines N] [--format text|ansi]
herdr pane rename <id> <label>|--clear | close <id> | zoom | move | swap | resize | focus | neighbor
herdr pane report-agent <id> --source ID --agent LABEL --state idle|working|blocked|unknown [...]   # how state is reported
```

## Workspace / tab (organization)
```
herdr workspace list | create [--cwd PATH] [--label TEXT] [--env K=V] [--focus] | get|focus|rename|close <id>
herdr tab       list [--workspace ID] | create [...] | get|focus|rename|close <id>
```

## Blocking waits (key for later orchestration / gnhf)
```
herdr wait agent-status <pane_id> --status idle|working|blocked|done|unknown [--timeout MS]
herdr wait output <pane_id> --match <text> [--source ...] [--lines N] [--timeout MS] [--regex] [--raw]
```

## Server / session / env
```
herdr status [server|client] | server stop | server reload-config
herdr --session <name> ... ; herdr session attach <name>   ; env: HERDR_SESSION, HERDR_SOCKET_PATH, HERDR_CONFIG_PATH
Custom-command panes get: HERDR_ACTIVE_WORKSPACE_ID, HERDR_ACTIVE_TAB_ID, HERDR_ACTIVE_PANE_ID, HERDR_ACTIVE_PANE_CWD
```

## rdev-mux adapter → herdr mapping (for Plan 2)
| rdev-mux verb | herdr command |
|---|---|
| `spawn-agent` (stream coordinator) | `herdr agent start <name> --cwd <worktree> --workspace <id> -- claude …` |
| `spawn-pane` (shell) | `herdr pane split --direction down --cwd <worktree>` |
| `list` | `herdr agent list` / `herdr pane list --json` |
| `send` | `herdr agent send` / `herdr pane run` |
| `read` | `herdr pane read` / `herdr agent read` |
| `label` | `herdr pane rename` / `herdr agent rename` |
| `kill` | `herdr pane close` |
| `state` / triage | `herdr agent get` / `herdr agent wait --status` |
| `worktree create/remove` | `herdr worktree create --path … --branch …` / `herdr worktree remove` |

**Implication:** herdr owns worktree+pane+workspace lifecycle and state; `rdev-mux` is a thin, substrate-agnostic wrapper over these verbs; rdev keeps the rhythms-specific logic (dep-sharing, lease, tests, pipeline). Confirms the §5 design.
