# system-hud

A portable **two-level resource HUD** for AI-agent status lines. One core script
(`bin/agent-hud`) renders the same HUD; thin adapters wire it into each agent.

```
⊳ session   CPU   17%   MEM 0.8G (2%)          pwd  12K
⊳ system    CPU   11%   MEM 16.3G/32.0G (50%)  disk 293.4G free (68% used)
```

- **Top line — this TUI session:** CPU% and memory summed across every process
  sharing this pane's controlling tty (shell + agent + children), plus the size
  of the current working directory.
- **Bottom line — the whole machine:** system CPU%, used/total RAM, and free disk
  on the cwd's volume. MEM and disk carry a parenthetical `%`.

## How it works

| Metric           | Source                                                        |
|------------------|---------------------------------------------------------------|
| system CPU%      | background **daemon** samples `top` deltas into a cache        |
| session CPU/MEM  | `ps -t <tty>` over the session's controlling terminal         |
| system MEM       | `vm_stat` + `sysctl hw.memsize`                               |
| pwd size         | `du`, run async with a timeout + short per-cwd cache           |
| disk free        | `df` of the cwd's volume                                       |

Only system CPU% needs sampling state (a delta between two reads), so the daemon
owns just that. Every other metric is a cheap per-render one-shot, keeping the
statusline render fast. If the daemon isn't running, system CPU% falls back to a
load-average estimate.

## Install (macOS)

```sh
./install.sh
```

This loads the launchd daemon and wires the Claude Code statusline
(`~/.claude/statusline-command.sh`, backed up first). Open a new session to see
the HUD.

## Colorways

Default is **gruvbox**. Built-ins: `gruvbox`, `catppuccin`, `tokyonight`, `mono`.

```sh
agent-hud colorways                 # list
AGENT_HUD_COLORWAY=tokyonight agent-hud render   # one-off
echo 'colorway=catppuccin' > ~/.config/agent-hud/config   # persistent
```

## Other agents

- **Claude Code** — wired by `install.sh` (see `adapters/claude.sh`).
- **Codex / opencode** — `adapters/{codex,opencode}.md` (stubs; not installed yet).

## Layout

```
agent-hud/
  bin/agent-hud                     core: render + daemon + colorways
  adapters/{claude.sh,codex.md,opencode.md}
  com.coppetaj.agent-hud.plist      launchd template
  install.sh
```

## Notes & limits

- macOS-only (bash + `top`/`vm_stat`/`ps`/`df`). A Go port would add Linux.
- "Session" = the controlling tty of the agent process. Daemons launched outside
  the pane are correctly excluded.
- `du` on a huge tree shows the last cached value (or `…` on first sight) rather
  than blocking the statusline.
