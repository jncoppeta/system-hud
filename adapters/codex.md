# Codex adapter

Codex is not wired by this project today.

Current Codex builds expose a built-in TUI footer, but not a documented
Claude-style shell-command statusline hook. Because `agent-hud` needs Codex to
run `agent-hud render --cwd <session cwd>` on each footer refresh, there is no
repo-side Codex setup to apply yet.

Use the Claude Code adapter for the live two-line HUD, or run the renderer on
demand:

```sh
bin/agent-hud render --cwd "$PWD"
```

If Codex later adds a custom command statusline/footer hook, this adapter should
wire that hook to `agent-hud render --cwd <codex cwd>`.
