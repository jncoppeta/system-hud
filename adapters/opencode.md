# opencode adapter (stub)

opencode is not installed on this machine yet, so this adapter is a
placeholder. Wire it once opencode is available.

## Goal

Render the two HUD lines (`agent-hud render --cwd <cwd>`) inside opencode's TUI
status area.

## When opencode is installed

1. Inspect opencode config (`~/.config/opencode/`) for a statusline, footer, or
   custom-command hook. opencode is a TUI, so it may expose theme/status
   extension points rather than a shell-command statusline.

2. If a shell-command hook exists, point it at:

   ```sh
   agent-hud render --cwd "$OPENCODE_CWD"
   ```

3. If not, options: a tmux/WezTerm status integration that runs `agent-hud
   render` for the active pane, or an on-demand keybind.

4. `bin/agent-hud` stays unchanged — only the trigger + cwd source are
   opencode-specific.

> TODO: confirm opencode's status extension mechanism and fill in.
