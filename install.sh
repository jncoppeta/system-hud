#!/usr/bin/env bash
# agent-hud installer: daemon (launchd) + Claude Code statusline wiring.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN="$ROOT/bin/agent-hud"
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/agent-hud"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/agent-hud"
LA_DIR="$HOME/Library/LaunchAgents"
PLIST="$LA_DIR/com.coppetaj.agent-hud.plist"
CLAUDE_SL="$HOME/.claude/statusline-command.sh"
MARKER="agent-hud HUD"

chmod +x "$BIN"
mkdir -p "$CACHE_DIR" "$CONFIG_DIR" "$LA_DIR"

# default config
if [ ! -f "$CONFIG_DIR/config" ]; then
  printf 'colorway=gruvbox\n' > "$CONFIG_DIR/config"
  echo "wrote default config -> $CONFIG_DIR/config (colorway=gruvbox)"
fi

# launchd daemon
sed -e "s#__BIN__#$BIN#g" -e "s#__CACHE__#$CACHE_DIR#g" \
  "$ROOT/com.coppetaj.agent-hud.plist" > "$PLIST"
launchctl bootout "gui/$(id -u)/com.coppetaj.agent-hud" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$PLIST"
echo "daemon loaded (launchd: com.coppetaj.agent-hud)"

# Claude Code statusline wiring (non-destructive, backed up, idempotent).
# Re-running strips any prior agent-hud block and re-appends a fresh one with
# the current $BIN path — so moving the plugin re-points the statusline.
if [ -f "$CLAUDE_SL" ]; then
  cp "$CLAUDE_SL" "$CLAUDE_SL.bak.$(date +%Y%m%d%H%M%S)"
  if grep -q "$MARKER" "$CLAUDE_SL"; then
    # drop everything from the marker line to EOF (the block lives at the end)
    awk -v m="$MARKER" 'index($0,m){exit} {print}' "$CLAUDE_SL" > "$CLAUDE_SL.tmp"
    # trim a trailing blank line left behind, then replace
    awk 'NR>1{print prev} {prev=$0} END{if(prev!="")print prev}' "$CLAUDE_SL.tmp" > "$CLAUDE_SL" 2>/dev/null \
      || mv "$CLAUDE_SL.tmp" "$CLAUDE_SL"
    rm -f "$CLAUDE_SL.tmp"
    action="re-wired"
  else
    action="wired"
  fi
  cat >> "$CLAUDE_SL" <<EOF

# --- $MARKER (added by agent-hud install) ---
__HUD=\$("$BIN" render --cwd "\$CWD" 2>/dev/null)
[ -n "\$__HUD" ] && printf "\n%s" "\$__HUD"
EOF
  echo "$action Claude statusline -> $BIN (backup saved alongside it)"
else
  echo "no Claude statusline at $CLAUDE_SL — see adapters/claude.sh to wire manually"
fi

echo "done. Open a new agent session (or refresh statusline) to see the HUD."
