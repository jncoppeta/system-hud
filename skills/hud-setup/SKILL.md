---
name: hud-setup
description: Install, wire, inspect, or remove the agent-hud resource HUD on macOS. agent-hud renders a two-level status-line HUD — a top line for THIS TUI session (CPU% and memory summed across every process sharing the agent pane's controlling tty, plus the size of the current working directory) and a bottom line for the whole machine (system CPU%, used/total RAM, and free disk on the cwd's volume, each with a parenthetical %). Setup runs the plugin's install.sh, which (1) writes a default config, (2) loads a launchd daemon (com.coppetaj.agent-hud) that samples system CPU% into a cache so per-render reads stay fast, and (3) wires the HUD into Claude Code's ~/.claude/statusline-command.sh non-destructively (the prior statusline is backed up). The wiring is idempotent and migration-safe — re-running install.sh after moving the plugin re-points the statusline and daemon at the new path. Use when the user wants to install/enable the HUD, re-wire it after moving the repo, check that the daemon is running, troubleshoot a missing or stale HUD, or uninstall it. For changing the HUD colors, use the hud-colorway skill instead.
---

# agent-hud — Setup

Install and manage the two-level resource HUD. The plugin root holds
`bin/agent-hud` (renderer + daemon), `install.sh`, the launchd template
`com.coppetaj.agent-hud.plist`, and `adapters/`.

## When to Activate

- "install the HUD", "set up agent-hud", "enable the resource HUD", "wire the statusline"
- "the HUD disappeared / shows 0% / is stale", "is the daemon running?"
- "I moved the repo and the HUD broke" → re-run install (rewires the new path)
- "remove the HUD", "uninstall agent-hud"

## Install / re-wire

Run the installer from the plugin root (paths are resolved relative to it):

```sh
bash "$(dirname "$0")/../../install.sh"   # or: bash <plugin-root>/install.sh
```

It is idempotent. It will:
1. Write `~/.config/agent-hud/config` (default `colorway=gruvbox`) if absent.
2. Generate `~/Library/LaunchAgents/com.coppetaj.agent-hud.plist` from the
   template with the current absolute `bin/agent-hud` path, then
   `bootout`+`bootstrap` it (so a move re-points the daemon).
3. Back up `~/.claude/statusline-command.sh`, remove any prior agent-hud block,
   and append a fresh block calling `agent-hud render --cwd "$CWD"`.

Open a new agent session (or wait for the statusline to refresh) to see it.

## Verify

```sh
launchctl list | grep agent-hud                 # daemon loaded?
cat ~/.cache/agent-hud/sys                       # latest system CPU% sample
<plugin-root>/bin/agent-hud render --cwd "$PWD"  # render once, standalone
```

Expected render (gruvbox):
```
⊳ session   CPU 14%   MEM 0.8G (2%)          pwd 36K
⊳ system    CPU 10%   MEM 16.2G/32.0G (50%)  disk 293.4G free (68% used)
```

## Troubleshoot

- **Session line shows 0%** — the renderer walks parent PIDs to find the pane's
  controlling tty (Claude spawns the statusline without one). If it still reads
  0, the agent process chain has no tty; this is expected outside a real pane.
- **System CPU% looks like load average** — the daemon isn't running, so the
  renderer fell back to a loadavg estimate. Check `launchctl list | grep agent-hud`
  and re-run install.
- **`pwd` shows `…`** — first sight of a large dir; `du` runs async with a
  timeout and a short per-cwd cache, so the value fills in on the next render.

## Uninstall

```sh
launchctl bootout "gui/$(id -u)/com.coppetaj.agent-hud"
rm -f ~/Library/LaunchAgents/com.coppetaj.agent-hud.plist
# then restore the statusline backup created at install time:
#   ~/.claude/statusline-command.sh.bak.<timestamp>
```
