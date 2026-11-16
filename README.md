In-game menus for Godot 4 games, built from data. Press Escape and get a settings menu (General, Video, Audio, Controls, Advanced and any pages your game adds), a help screen, rebindable keys, a Tab scoreboard, a numbered picker, a HUD layout editor, themes, and a connection overlay. Every switch and slider is a view of a [dot-settings](https://github.com/gamespice-platform/settings) value, so there is no Apply button: a change is saved and applied at once. Part of TMC's open source **Gamespice** collection (MIT licence).

> Built with Claude Code. Every addon has a headless test suite and the suites pass, but little of this has met real players yet. Please report rough edges.

## Install

You need Godot 4.7. [dot-bootstrap](https://github.com/gamespice-platform/bootstrap) clones every project and links the addons for you. To add it by hand, copy these into your project and enable dot-menu under **Project > Project Settings > Plugins**:

- `addons/dot_menu/` (this repo)
- `addons/dot_core/` from [dot-core](https://github.com/gamespice-platform/core)
- `addons/dot_ui/` from [dot-ui](https://github.com/gamespice-platform/ui)
- `addons/dot_settings/` from [dot-settings](https://github.com/gamespice-platform/settings)

Run `godot --path .` to open the demo. Escape, H, P and M all work.

## What you get

| Feature | What it does |
| --- | --- |
| Stock settings | Volumes, window mode, V-Sync, frame-rate cap, render scale, field of view, effects quality, mouse sensitivity, invert mouse, camera shake, screen flashes, theme, HUD size, frame-rate counter, chat box, voice. Declared once, so moving a game onto dot-menu keeps each player's choices. |
| `DotMenuApplier` | Applies each setting to what it controls (engine, audio buses or a dot-audio mixer, a dot-fx config, a mouse sampler, a camera) at load and on every change. |
| `DotMenuBindings` | One table of key actions. Declares a setting per key, adds them to the InputMap, draws the Controls page and lists them in Help. Binding a used key swaps the two. Escape cannot be bound. |
| Help screen | Opens on H unless you turn it off: your game's goal and modes, every key as currently bound, the server's chat commands, your own cards, and what a browser does with Ctrl+W and friends. |
| Picker | A numbered list, seven to a page: 1 to 7 pick, 8 and 9 turn the page, 0 closes. Used for maps, teams and classes. |
| Map, team and loadout menus | M opens a map picker, the period key a team screen, B a loadout screen. On a server the server decides; solo, the game does. See [docs/examples.md](docs/examples.md). |
| HUD layout editor | Drag HUD pieces anywhere, right-click to reset one. Positions are saved as fractions of the screen. |
| Themes | Eight ship: Midnight, Ember, Violet, Classic, Arcade, Paper, High contrast and Gamespice. A theme colours the menus and the HUD. Games, JSON files and servers can add more, and a host can set `dot_menu/theme/platform_default` so every game it runs opens in its theme. |
| Scoreboard | Hold Tab: server name, map and slots, teams in their colours, and a row per player with score, time connected and ping, plus your own columns. Players choose which columns to show under Settings > General > Scoreboard. |
| Connection overlay | `net_stat` shows frame rate, ping, jitter, loss and bytes in and out, with a graph. See [docs/net-stat.md](docs/net-stat.md). |
| Server rules | While connected, a server can hide rows and pages, narrow the themes, reword Leave and cap a setting such as field of view. It can never read or change a player's stored value. Leaving restores everything. |
| Browser and touch | The menu opens even when a browser swallows Escape, and a touch screen gets a Menu button and finger-sized rows. |

## Using it

```gdscript
# The keys your game reads.
var keys := DotMenuBindings.new()
keys.add_movement()                                       # WASD, Space, Ctrl
keys.add(&"mygame_flashlight", &"bind_flashlight", "Flashlight", "F", "View")
keys.add_help()                                           # H opens help

# The settings: the stock ones, your own, and your config over both.
var config := DotMenuConfig.new()
config.load_layered("res://menu.json")
var schema := DotSettingsSchema.new()
DotMenuStock.declare(schema)
schema.add(DotSettingsDef.boolean(&"show_speed", true, &"hud"))
keys.add_to_schema(schema)
config.apply_to_schema(schema)

var settings := DotMenuStock.manager(schema, "user://my_game_settings", &"my_game")
add_child(settings)
settings.setup()

# What applies them.
var applier := DotMenuApplier.new()
applier.settings = settings
applier.bindings = keys
add_child(applier)
applier.bind_audio(audio)            # a DotAudioManager; without one the buses are set directly
applier.bind_look(sampler.tunables)  # sensitivity and invert
applier.bind_camera(camera)          # field of view
applier.on(&"show_speed", func(on, _why): hud.speed.visible = on)
applier.setup()

# The menu.
var menu := DotMenu.new()
menu.settings = settings
menu.bindings = keys
menu.config = config
add_child(menu)
menu.setup()
menu.help.about = "First to twenty frags wins."
menu.help.add_text("Modes", "Deathmatch, and Teams on a team map.")
menu.leave_on_its_own = true                              # Leave disconnects, or quits a solo game

menu.overlays_changed.connect(func(open): sampler.suspended = open)
```

### Add your own page

```gdscript
var page := DotMenuPage.make(&"gameplay", "Gameplay", "Your view and the HUD.")
page.section("HUD").add(DotMenuRow.toggle(&"show_speed", "Speed", "Under the clock."))
page.section("View").add(DotMenuRow.live_toggle("Flashlight", "",
    func(): return light.on, func(on): light.on = on)
    .enabled_when(func(): return server_allows_flashlight))
menu.add_page(page, &"video")       # before Video
```

Row types:

| Row | Backed by |
| --- | --- |
| `toggle`, `slider`, `select` | A setting. Range and options come from the setting. |
| `live_toggle`, `live_select`, `live_slider` | State your game owns, which is not stored. |
| `button`, `note`, `custom` | A button, a line of text, or any Control you build. |

A row for a setting your schema does not declare is not drawn, so the stock pages fit a game that declared only some stock settings. Move or hide a stock row with `menu.page(&"general").take_row(&"show_fps")` and find one with `menu.find_row(&"fx_quality")`.

### Server rules and other screens

```gdscript
menu.apply_server_rules({"clamps": {"field_of_view": 100}, "rows_hidden": ["render_scale"],
    "themes": ["midnight", "contrast"], "leave_text": "Disconnect"})
menu.release_server_rules()
```

- `menu.open_help(commands, online)`, `menu.open_picker(items, title)` (the choice arrives on `picked`), and `menu.open_layout_editor(hud, {&"timer": "Timer"})` (layout on `menu.layout_editor.saved`).
- A screen of your own joins the Escape handling with `menu.add_overlay(control)`. `theme_changed` hands your HUD the new palette.
- A game whose Escape is its own (a garage, a lobby) sets `menu.open_on_escape = false`.

### Scoreboard

```gdscript
menu.scoreboard_action = &"mygame_scores"                 # bind it to Tab in your keys table
menu.scoreboard.feed_from(link)                           # online: the server's roster
menu.scoreboard.add_column({"key": &"kills", "title": "K", "kind": DotMenuScoreboard.KIND_NUMBER}, &"score")
```

Online, [dot-server](https://github.com/gamespice-platform/server) sends the roster only while a player holds the board. Add columns and teams on the server with `server.scoreboard_fields` (per player) and `server.scoreboard_extra` (teams and header). Offline, set `menu.scoreboard.source` to a function that returns the same dictionary.

A column is data: `key`, `title`, `kind` (text, number, ping, duration, avatar or custom), `width`, `format`, `build`, `required`, `hidden`. `group_by` and `sort_by` choose teams and order. A `required` column cannot be hidden; a `hidden` one starts hidden and the player's choice wins. The choice is stored in `scoreboard_hidden`, by column key.

## Settings

`DotMenuConfig` holds what a developer can change without code. It is layered like every Gamespice config: defaults, then a JSON file, then environment variables, then the command line.

```json
{
  "brand_mark": "g2g", "brand_name": "fast",
  "theme": "ember", "themes_allowed": ["ember", "paper", "contrast"],
  "rows_hidden": ["render_scale"],
  "settings": {
    "field_of_view": {"default": 90, "min": 75, "max": 120},
    "shake_scale": {"default": 0.0}
  },
  "rows": {"fx_quality": {"title": "Particles"}},
  "fps_choices": [0, 60, 144, 240]
}
```

```bash
GS_MENU_THEME=paper godot --path . -- --menu-browser-tips=on
```

`settings` changes the schema (a default, a range, the options), so call `config.apply_to_schema(schema)` before settings load. A changed default reaches players who have never run the game; players with a stored value keep it.

| Option | Default | What it does |
| --- | --- | --- |
| `brand_mark` | empty | Small filled mark at the top of the sidebar. |
| `brand_name` | `Menu` | The words beside it. |
| `theme` | `midnight` | The theme a new player gets. |
| `themes_allowed` | all | Which themes are offered. |
| `themes_file` | empty | A JSON file of more themes. |
| `pages_hidden` | none | Page ids left out of the sidebar. |
| `rows_hidden` | none | Row ids (a setting key or a row id) left off every page. |
| `page_order` | as added | Page ids in sidebar order. |
| `settings` | `{}` | Per setting: `default`, `min`, `max`, `step`, `options`, `description`. |
| `rows` | `{}` | Per row: `title`, `description`. |
| `fps_choices` | 0, 30, 60, 75, 120, 144, 165, 240, 300 | Frame-rate caps offered. 0 is unlimited. |
| `show_help` | true | A Help entry in the sidebar. |
| `help_hint` | `top_right` | Where the HUD's "H Help" plate sits: `top_right`, `top_left`, `bottom_right`, `bottom_left` or `off`. |
| `menu_button_corner` | `top_right` | Corner of the touch Menu button. |
| `touch` | `auto` | Touch layout: `auto`, `on` or `off`. |
| `show_leave` | true | A Leave entry in the sidebar. |
| `leave_text` | `Leave` | The words on it. |
| `browser_tips` | `auto` | The help screen's browser card: `auto` (in a browser), `on`, `off`. |
| `command_prefix` | `!` | Shown before chat commands on the help screen. |
| `window_max_width` / `window_max_height` | 1060 / 680 | Largest menu size in pixels. |
| `window_margin` | 24 | Gap kept from the window edge. |
| `sidebar_width` | 236 | Sidebar width in pixels. |
| `layer` | 110 | CanvasLayer the menus draw on, above the HUD and chat. |
| `open_on_pointer_release` | true | Open the menu when the mouse is taken away (a browser's Escape). |
| `escape_grace_ms` | 250 | An Escape this soon after opening is ignored. |
| `fps_counter` | true | Show the counter when the `show_fps` setting is on. |
| `net_stat` | true | Draw the connection overlay when the `net_stat` setting asks for it. |

### Stock player settings

Stored per device unless the last column says otherwise.

| Key | Default | Range or options | Scope |
| --- | --- | --- | --- |
| `master_volume` | 0.8 | 0 to 1 | device |
| `sfx_volume` | 1.0 | 0 to 1 | device |
| `ui_volume` | 0.8 | 0 to 1 | device |
| `voice_volume` | 1.0 | 0 to 1 | device |
| `ambience_volume` | 0.35 | 0 to 1 | device |
| `slide_volume` | 1.0 | 0 to 1 | device |
| `music_volume` (only if you ask for it) | 0.6 | 0 to 1 | device |
| `window_mode` | `windowed` | `windowed`, `borderless`, `fullscreen` | device |
| `vsync` | off | on, off | device |
| `fps_max` | 0 | 0 (unlimited) to 1000 | device |
| `render_scale` | 1.0 | 0.5 to 1 | device |
| `field_of_view` | 90 | 70 to 120 | account; a server may cap it |
| `viewmodel_fov` | 54 | 50 to 100 | device; only with a view model in group `dot_view_model` |
| `fx_quality` | 3 | 0 to 3 | device |
| `aniso`, `aa`, `mip_bias`, `sharpness` | -1, 0, 0.0, 0.2 | texture filtering and anti-aliasing | device |
| `sensitivity` | 2.5 | 0.05 to 20 | account, shared between games |
| `invert_mouse` | off | on, off | account |
| `shake_scale` | 1.0 | 0 to 2 | device |
| `allow_flashes` | on | on, off | device |
| `reduce_motion` | off | on, off | device |
| `ui_theme` | `midnight` | the themes | account |
| `hud_scale` | 1.0 | 0.7 to 1.4 | account |
| `show_fps` | off | on, off | device |
| `scoreboard_hidden` | empty | column keys | device |
| `net_stat` | 0 (off) | 0 to 3 | device |
| `net_stat_height` | 96 | 32 to 320 pixels | device |
| `net_stat_position` | corner | `top_right`, `bottom_right`, `top_left`, `bottom_left` | device |
| `net_stat_style` | `solid` | `solid`, `line` | device |
| `chat_window` | `auto` | `auto`, `on`, `off` | account |
| `voice_mode`, `voice_input_device` | | push to talk or open mic, and the microphone | account |

A theme file is a list of palettes; any colour left out comes from `base`:

```json
{"themes": [
  {"id": "forest", "name": "Forest", "base": "midnight", "accent": "#5fd38d", "accent_deep": "#2e8b57"}
]}
```

## Testing

```bash
godot --headless --path . --import
godot --headless --path . res://examples/menu_selftest.tscn
tools/screenshot.sh
```

The self-test covers themes, config, that every stock setting has an applier and a row, the key table, the screens, server rules, help, the picker, the layout editor and the scoreboard. `tools/screenshot.sh` renders every page, theme and screen to `screenshots/`. Other checks sit in `examples/`.

## Licence

MIT. See [LICENSE](LICENSE).
