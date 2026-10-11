# dot-menu

In-game menus as data: an Escape menu whose rows are views of dot-settings, stock settings and pages every game shares, a key table, themes, the held Tab scoreboard, and the `net_stat` connection overlay. Extracted from game-g2gfast's menu.

**The distributable is `addons/dot_menu/`.** It depends on dot-core, dot-ui and dot-settings and nothing else; dot-audio, dot-fx, dot-player-controller and dot-server are reached duck-typed or through dot-core. Read the family [CLAUDE.md](../../CLAUDE.md) first, and dot-ui's and dot-settings' own, because this sits on both and keeps their rules.

## Read before

| Read | Before |
| --- | --- |
| [docs/design.md](docs/design.md) | rows and pages, stock keys, themes, the key table, server rules, Escape and the pointer, `DotMenuSettings`, the scoreboard |
| [docs/net-stat.md](docs/net-stat.md) | changing how net_stat scales, where it sits or what it draws |

## Layout

| Path | What |
| --- | --- |
| `addons/dot_menu/core/` | `dot_menu_page.gd`, `_section.gd`, `_row.gd` (a page is data), `dot_menu_config.gd` (`apply_to_schema`), `dot_menu_bindings.gd` (the key table), `dot_menu_kit.gd`, `_palette.gd`, `_themes.gd` |
| `addons/dot_menu/runtime/` | `dot_menu.gd` (overlays, Escape, pointer, theme, server rules), `dot_menu_applier.gd` (the one place a stock setting is applied), `dot_menu_settings.gd` (the node games subclass) |
| `addons/dot_menu/stock/dot_menu_stock.gd` | the stock keys, groups and pages; `declare`, `declare_net_stat` |
| `addons/dot_menu/ui/` | `dot_menu_screen.gd`, `_scoreboard.gd`, `_net_stat.gd`, `_help.gd`, `_picker.gd`, `_layout_editor.gd`, `_key_button.gd`, `_switch.gd` |
| `addons/dot_menu/dot_menu_api.gd` | the API level |
| `examples/` | `menu_selftest` (the suite), `menu_demo` (what the screenshots render) |
| `tools/screenshot.sh` | every page, theme and screen, net_stat levels |

## Running and testing

```bash
godot --headless --path . --import
godot --headless --path . res://examples/menu_selftest.tscn
tools/screenshot.sh
```

- **`tools/screenshot.sh` is not optional after a visual change**: a menu is the thing no assertion can judge. Its first run found an engine error per unnamed row that the suite never drew. Look at `screenshots/theme_paper.png` after touching the kit: the light theme is where a hard-coded colour shows.
- A scene that fails to parse HANGS the render rather than failing it; parse-check `examples/menu_demo.gd` first.

## Rules that bite

- A row is a view of a setting: read when drawn, written when changed, applied only by `DotMenuApplier`. No Apply button, no Controls kept between draws. [design](docs/design.md#the-one-idea)
- A row's range and options come from its `DotSettingsDef`; a row whose setting is not declared is not drawn. [design](docs/design.md#the-one-idea)
- Stock keys and scopes never change; a game overrides a default in `DotMenuConfig.settings`, and leaves out what it cannot apply with `declare(..., except)`. [design](docs/design.md#the-stock-keys-are-a-contract)
- Every stock key is covered by `APPLIES`, `APPLIED_BY_MENU` or `LEFT_TO_THE_GAME`, and has a row; the suite enforces it. [design](docs/design.md#the-stock-keys-are-a-contract)
- `DotMenuConfig.apply_to_schema` runs before `settings.setup()`, or an added theme is reset at every start. [design](docs/design.md#themes-go-into-the-schema-before-the-settings-load)
- A theme change rebuilds the screen; never walk the tree to recolour. [design](docs/design.md#themes-go-into-the-schema-before-the-settings-load)
- Rebinding a taken key swaps; compare effective bindings (`stored()`), never stored text. [design](docs/design.md#the-keys-table)
- A server may hide and clamp, never set or read; a clamped row shows the player's own choice. [design](docs/design.md#a-server-may-hide-and-clamp-it-may-never-set-or-read)
- `DotMenu` owns overlays, Escape and the pointer; while anything is open every key is the menu's. [design](docs/design.md#the-pointer-escape-and-overlays-one-list)
- The scoreboard is held, not opened: it closes on release wherever that arrives and never takes the pointer. [design](docs/design.md#the-scoreboard-the-servers-numbers-held)
- Never name dot-server: the scoreboard feed and net_stat's meter are duck-typed or dot-core's. [design](docs/design.md#the-scoreboard-the-servers-numbers-held), [net_stat](docs/net-stat.md)
- `DotMenuNetStat.follow` connects a method, never a lambda capturing the overlay. [net_stat](docs/net-stat.md)
- **A delivered game that uses `DotMenu*` needs a client shell built with dot-menu in it**; in an older shell every script naming `DotMenu` fails to parse. Tag dot-menu, lock it in dot-server-deploy and rebuild the shell before publishing such a game ([dot-server-deploy releases](../dot-server-deploy/docs/releases.md)).

## Who uses it

Every game uses dot-menu's Tab scoreboard. The Escape menu: game-g2gfast (where it came from), the `mg-*` games, game-zombie-zone, game-hide-n-seek and dot-game-template through `DotMenuSettings`; game-playground (Escape only; its spawn menu and server browser stay on its own stack); game-arena (with its server browser as a page). Exception:

- **game-hungario: the Tab board and net_stat only, deliberately for now.** Its settings are a `DotConfig`, and dot-menu's menu is a view of dot-settings, so moving changes how settings are stored.
