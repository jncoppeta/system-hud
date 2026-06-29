# Claude Code adapter for agent-hud
#
# install.sh wires this automatically. To do it by hand, append the block
# below to ~/.claude/statusline-command.sh (after its final printf). The
# script already defines $CWD from the statusline JSON, so the HUD reflects
# the session's working directory.

# --- agent-hud HUD ---
__HUD=$("$HOME/projects/agent-hud/bin/agent-hud" render --cwd "$CWD" 2>/dev/null)
[ -n "$__HUD" ] && printf "\n%s" "$__HUD"

# Notes:
# - Claude renders multi-line statusline output, so the two HUD lines stack
#   under your existing line. If a future version collapses to one line, drop
#   the leading "\n" and the lines will be joined.
# - Override colors per session with: AGENT_HUD_COLORWAY=tokyonight
