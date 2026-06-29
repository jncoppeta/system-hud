#!/usr/bin/env bash
# agent-hud installer: CPU-sampler daemon (launchd on macOS, systemd on Linux)
# + Claude Code statusline wiring.
set -euo pipefail

OS="$(uname -s)"                            # Darwin | Linux
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN="$ROOT/bin/agent-hud"
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/agent-hud"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/agent-hud"
CLAUDE_SL="$HOME/.claude/statusline-command.sh"
MARKER="agent-hud HUD"

chmod +x "$BIN"
mkdir -p "$CACHE_DIR" "$CONFIG_DIR"

# default config
if [ ! -f "$CONFIG_DIR/config" ]; then
  printf 'colorway=gruvbox\n' > "$CONFIG_DIR/config"
  echo "wrote default config -> $CONFIG_DIR/config (colorway=gruvbox)"
fi

# ---------- daemon (system CPU% sampler) ------------------------------------
if [ "$OS" = Darwin ]; then
  # launchd: copy the binary out of the repo so a quarantine xattr / repo move
  # can't break the loaded agent.
  SUPPORT_DIR="$HOME/Library/Application Support/agent-hud"
  DAEMON_BIN="$SUPPORT_DIR/agent-hud"
  LA_DIR="$HOME/Library/LaunchAgents"
  PLIST="$LA_DIR/com.coppetaj.agent-hud.plist"
  mkdir -p "$SUPPORT_DIR" "$LA_DIR"
  cp "$BIN" "$DAEMON_BIN"
  chmod +x "$DAEMON_BIN"
  xattr -c "$DAEMON_BIN" 2>/dev/null || true
  sed -e "s#__BIN__#$DAEMON_BIN#g" -e "s#__CACHE__#$CACHE_DIR#g" \
    "$ROOT/com.coppetaj.agent-hud.plist" > "$PLIST"
  launchctl bootout "gui/$(id -u)/com.coppetaj.agent-hud" 2>/dev/null || true
  launchctl bootstrap "gui/$(id -u)" "$PLIST"
  echo "daemon loaded (launchd: com.coppetaj.agent-hud -> $DAEMON_BIN)"
elif command -v systemctl >/dev/null 2>&1; then
  # systemd user service, pointed straight at the repo binary.
  UNIT_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"
  UNIT="$UNIT_DIR/agent-hud.service"
  mkdir -p "$UNIT_DIR"
  sed -e "s#__BIN__#$BIN#g" -e "s#__CACHE__#$CACHE_DIR#g" \
    "$ROOT/agent-hud.service" > "$UNIT"
  systemctl --user daemon-reload
  systemctl --user enable --now agent-hud.service
  echo "daemon loaded (systemd --user: agent-hud.service -> $BIN)"
else
  # no systemd: best-effort background launch (system CPU% otherwise falls back
  # to a load-average estimate).
  pkill -f "$BIN daemon" 2>/dev/null || true
  nohup "$BIN" daemon >/dev/null 2>>"$CACHE_DIR/daemon.err" &
  echo "daemon started (nohup background; no systemd found -> won't survive reboot)"
fi

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
