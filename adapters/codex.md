# Codex adapter (stub)

Codex CLI is not installed on this machine yet, so this adapter is a
placeholder. Wire it once Codex is available.

## Goal

Call `agent-hud render --cwd <session cwd>` and surface the two HUD lines in
Codex's status/footer area.

## When Codex is installed

1. Check whether Codex supports a custom status line / footer command in its
   config (`~/.codex/config.*`). If it pipes context (cwd, model) to a command
   like Claude does, point it at:

   ```sh
   agent-hud render --cwd "$CODEX_CWD"
   ```

2. If Codex has no statusline hook, fall back to a keybinding or a prompt-prefix
   that runs `agent-hud render` on demand.

3. The core `agent-hud` script is agent-agnostic — only the cwd source and the
   render trigger differ per agent. No changes to `bin/agent-hud` needed.

> TODO: confirm Codex's statusline/footer extension mechanism and fill in.
