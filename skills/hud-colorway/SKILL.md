---
name: hud-colorway
description: List, preview, or switch the color scheme (colorway) of the agent-hud status-line HUD. agent-hud ships four built-in colorways rendered with truecolor ANSI — gruvbox (default, warm), catppuccin (matches the Catppuccin Mocha terminal theme), tokyonight, and mono (labels only, values left in the default foreground). The active colorway resolves in this order — first the AGENT_HUD_COLORWAY environment variable, then `colorway=<name>` in ~/.config/agent-hud/config, else gruvbox. Use when the user wants to change the HUD colors, see what colorways exist, preview them, set a persistent default, or use a one-off colorway for a single session. For installing or wiring the HUD itself, use the hud-setup skill instead.
---

# agent-hud — Colorways

Swap the HUD's color scheme. Colors are real terminal truecolor escapes, so the
preview in your pane is exactly what the statusline shows.

## When to Activate

- "change the HUD colors", "use tokyonight / catppuccin / gruvbox / mono"
- "what colorways are there?", "preview the colorways"
- "make catppuccin the default", "set the HUD theme permanently"

## Built-in colorways

| Name         | Look |
|--------------|------|
| `gruvbox`    | Warm; default. |
| `catppuccin` | Matches Catppuccin Mocha (pairs with the user's WezTerm theme). |
| `tokyonight` | Cool blues/greens. |
| `mono`       | Only the `⊳ session` / `⊳ system` labels are colored; values stay default. |

List them from the tool: `<plugin-root>/bin/agent-hud colorways`.

## Preview

Render each on demand (no config change):

```sh
for cw in gruvbox catppuccin tokyonight mono; do
  echo "-- $cw --"
  AGENT_HUD_COLORWAY=$cw <plugin-root>/bin/agent-hud render --cwd "$PWD"
done
```

## Switch

- **One-off (this command only):** `AGENT_HUD_COLORWAY=tokyonight agent-hud render`
- **Persistent default:** write it to the config file —
  ```sh
  mkdir -p ~/.config/agent-hud
  printf 'colorway=%s\n' catppuccin > ~/.config/agent-hud/config
  ```
  The statusline picks it up on its next refresh; no reinstall needed.

## Add a new colorway

Edit `resolve_colorway()` in `bin/agent-hud`: add a `case` arm setting the six
slots (`CSESS`, `CSYS`, `CCPU`, `CMEM`, `CSTORE`, `CDIM`) via `_rgb R G B`, and
list the name in `cmd_colorways`. Keep the `gruvbox|*)` arm last as the default.
