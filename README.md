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

| Metric           | Source (macOS / Linux)                                          |
|------------------|----------------------------------------------------------------|
| system CPU%      | background **daemon** samples `top` deltas / `/proc/stat` deltas |
| session CPU/MEM  | `ps -t <tty>` over the session's controlling terminal          |
| system MEM       | `vm_stat` + `sysctl hw.memsize` / `/proc/meminfo`              |
| pwd size         | `du`, run async with a timeout + short per-cwd cache            |
| disk free        | `df` of the cwd's volume                                        |

Only system CPU% needs sampling state (a delta between two reads), so the daemon
owns just that. Every other metric is a cheap per-render one-shot, keeping the
statusline render fast. If the daemon isn't running, system CPU% falls back to a
load-average estimate.

## Install (macOS / Linux)

```sh
./install.sh
```

This loads the CPU-sampler daemon — **launchd** on macOS, a **systemd --user**
service on Linux (falling back to a `nohup` background process if systemd is
absent) — and wires the Claude Code statusline
(`~/.claude/statusline-command.sh`, backed up first). Open a new Claude session
to see the HUD.

Codex is not wired by this installer; see `adapters/codex.md` for the current
limitation.

## Colorways

Default is **gruvbox**. Built-ins: `gruvbox`, `catppuccin`, `tokyonight`, `mono`.

```sh
agent-hud colorways                 # list
AGENT_HUD_COLORWAY=tokyonight agent-hud render   # one-off
echo 'colorway=catppuccin' > ~/.config/agent-hud/config   # persistent
```

## Other agents

- **Claude Code** — wired by `install.sh` (see `adapters/claude.sh`).
- **Codex** — `adapters/codex.md` documents the current custom-HUD limitation.
- **opencode** — `adapters/opencode.md` (stub; not installed yet).

## Layout

```
agent-hud/
  bin/agent-hud                     core: render + daemon + colorways
  adapters/{claude.sh,codex.md,opencode.md}
  com.coppetaj.agent-hud.plist      launchd template (macOS)
  agent-hud.service                 systemd --user template (Linux)
  install.sh
```

## Notes & limits

- macOS + Linux (bash + coreutils). macOS reads `top`/`vm_stat`/`sysctl`; Linux
  reads `/proc/stat`/`/proc/meminfo`/`/proc/loadavg`. No other deps.
- Container-aware on Linux: in a Kubernetes pod / Docker container the system
  CPU%/MEM reflect the **cgroup limits** (cgroup v2 `memory.max`/`cpu.max`/
  `cpu.stat`, or v1 equivalents), not the host node. Falls back to `/proc` when
  no cgroup limit is set (bare metal unchanged).
- "Session" = the controlling tty of the agent process. Daemons launched outside
  the pane are correctly excluded.
- `du` on a huge tree shows the last cached value (or `…` on first sight) rather
  than blocking the statusline.
