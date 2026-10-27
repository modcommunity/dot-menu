This is the **menu** asset for TMC's **Dot** collection. It adds in-game menus as data: an Escape menu whose pages are made of rows that read and write your settings, the stock audio, video and general settings with the code that applies them, rebindable keys, a help screen, a numbered picker, a HUD layout editor, and themes that a game, a file or a server can add to.

This collection of assets provides modular building blocks for creating games and applications within the TMC ecosystem, ensuring consistency and interoperability across all `dot-*` assets. This includes core functionality, networking, authentication, cloud integration, and more.

**These assets are COMPLETELY OPEN SOURCE**. You are free to use, modify, and distribute them under the terms of the MIT license. The only thing not open source is the back-end web infrastructure. So if you opt into using your own authentication backend instead of integrating with TMC, you will need to build and integrate your own back-end infrastructure.

## From Maintainer & WARNING
This asset, along with all the others, was built initially with **Claude Code** and will continue to be maintained and extended using it. This is because I (`gamemann`) cannot build the entire TMC platform alone (I wish I could lol).

**Please treat this as partially tested.** Every asset has its own headless test suite and those suites pass, but very little of this has been in front of real players yet. Expect rough edges, and please report anything you run into.

I intend on reviewing code, testing, and editing documentation regularly. If you're interested in helping out, please let me know!

## What it does
Escape opens a menu with a sidebar of pages (General, Video, Audio, Controls, Advanced, plus any your game adds), a Resume button, Help and Leave. Every switch, slider and drop-down on a page is a view of a [dot-settings](https://github.com/modcommunity/dot-settings) value: it shows what is stored and writes it back when changed. There is no Apply button. A value changed from the console shows up the next time the menu opens.

It started as game-g2gfast's menus and was pulled out so every game gets the same look, the same help screen and the same settings without copying them.

- **Stock settings.** Master, effects, interface and voice volume (music if you ask for it), window mode, V-Sync, frame-rate cap, render scale, field of view, effects quality, sensitivity, invert mouse, camera shake, screen flashes, the theme, a frame-rate counter and the chat box. Declared once with the same keys and scopes the games already used, so moving a game onto this keeps every player's choices.
- **An applier.** `DotMenuApplier` pushes each of those at what it controls (the engine, the audio buses or a dot-audio mixer, a dot-fx config, a dot-player-controller sampler, a camera), once at load and again on every change.
- **Keys.** `DotMenuBindings` is one table of actions. It declares a setting per key, puts them on the InputMap, draws a key button per row on the Controls page and lists them on the help screen. Binding a key that is already used swaps the two, so nothing is left unbound. Escape can never be bound.
- **Help.** On H in every game unless you say otherwise. Your game's goal and modes, every key as it is bound right now, the server's chat commands, your own cards, and in a browser, what the browser does with Ctrl+W and friends.
- **A picker.** A numbered list, seven to a page: 1 to 7 picks, 8 and 9 turn the page, 0 closes. Maps, teams, classes.
- **A HUD layout editor.** Drag your HUD's pieces anywhere and right-click to put one back. Positions are saved as fractions of the screen, so a layout made on a laptop fits a 4K monitor.
- **Themes.** Six ship (Midnight, Ember, Violet, Classic, Paper, High contrast). A theme is a palette of colours for both the menus and the HUD, and can be written as JSON. P (or whatever you bind) cycles them.
- **net_stat.** A connection overlay drawn over the game: frame rate, ping and jitter, bytes and packets each way, loss, and a graph of what arrives by channel with ping across it (level 2), plus what leaves, the frame time and the server's own frame (level 3). Three settings drive it (`net_stat`, `net_stat_height`, `net_stat_position`), so the Advanced page and a console's `net_stat 2` are the same value. A game with its own settings and no menu declares them with `DotMenuStock.declare_net_stat(schema)` and draws them with `DotMenuNetStat.follow(self, settings)`. It reads the meter the client link's connection runs through (dot-core's `DotMeteredPeer`, which dot-server's client link uses), so it works over WebSocket in a browser as well as over ENet.
- **Server rules.** While connected, a server can hide rows and pages, narrow the themes, reword Leave, and cap settings like field of view through dot-settings' clamps. It can never change or read a player's stored value. Leaving puts everything back.
- **A scoreboard.** Hold Tab: the server's name, game, map and slots, the teams side by side in their colours, and a row per player with name, score, time connected and ping (coloured by how bad it is), plus any columns your game adds. Your own row is picked out and players on no team are listed as spectating. It never takes the mouse or stops you moving.
- **The browser.** When a browser takes the mouse away on Escape, the menu opens anyway, and an Escape that arrives right after is ignored so the menu does not flash shut.

## Getting started
You need [Godot 4.7](https://godotengine.org/download). The easiest way to get this addon and the ones it needs is [dot-bootstrap](https://github.com/modcommunity/dot-bootstrap), which clones every project and links the addons into each one.

To add it to your own project by hand, copy `addons/dot_menu/` into it along with `addons/dot_core/` from [dot-core](https://github.com/modcommunity/dot-core), `addons/dot_ui/` from [dot-ui](https://github.com/modcommunity/dot-ui) and `addons/dot_settings/` from [dot-settings](https://github.com/modcommunity/dot-settings), then enable dot-menu in **Project → Project Settings → Plugins**.

`godot --path .` opens the demo, a small world with the menu on it. Escape, H, P and M all work.

## Using it

```gdscript
# The keys your game reads.
var keys := DotMenuBindings.new()
keys.add_movement()                                       # WASD, Space, Ctrl
keys.add(&"mygame_flashlight", &"bind_flashlight", "Flashlight", "F", "View")
keys.add_help()                                           # H opens help; rebindable like any key

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
menu.help.about = "First to twenty frags wins."          # the help screen's goal card
menu.help.add_text("Modes", "Deathmatch, and Teams on a team map.")
menu.leave_on_its_own = true                              # Leave disconnects, or quits a solo game

menu.overlays_changed.connect(func(open): sampler.suspended = open)
```

Your own page goes in beside the stock ones:

```gdscript
var page := DotMenuPage.make(&"gameplay", "Gameplay", "Your view and the HUD.")
page.section("HUD").add(DotMenuRow.toggle(&"show_speed", "Speed", "Under the clock."))
page.section("View").add(DotMenuRow.live_toggle("Flashlight", "",
    func(): return light.on, func(on): light.on = on)
    .enabled_when(func(): return server_allows_flashlight))
menu.add_page(page, &"video")       # before Video
```

A row is one of `toggle`, `slider`, `select` (over a setting), `live_toggle`, `live_select`, `live_slider` (over state your game owns, which is not stored), `button`, `note` and `custom` (any Control you build). A setting row takes its range and options from the setting, so you only write them when you want to narrow them. A row for a setting your schema does not have is not drawn, which is how the stock pages fit a game that only declared some of the stock settings.

Everything on a stock page can be moved, reworded or hidden: `menu.page(&"general").take_row(&"show_fps")` hands you the row to put somewhere else, `menu.find_row(&"fx_quality")` finds one anywhere.

On a server, hand the menu what the server allows and take it back on leaving:

```gdscript
menu.apply_server_rules({"clamps": {"field_of_view": 100}, "rows_hidden": ["render_scale"],
    "themes": ["midnight", "contrast"], "leave_text": "Disconnect"})
menu.release_server_rules()
```

The scoreboard is held on whatever action you name:

```gdscript
menu.scoreboard_action = &"mygame_scores"                 # bind it to Tab in your keys table
menu.scoreboard.feed_from(link)                           # online: the server's roster
menu.scoreboard.add_column({"key": &"kills", "title": "K", "kind": DotMenuScoreboard.KIND_NUMBER}, &"score")
menu.scoreboard.decorate = func(row): row["avatar"] = faces.get(row["id"])
```

Online, [dot-server](https://github.com/modcommunity/dot-server) sends the roster only while a player holds the board: name, score, ping and time connected for everyone, which a client has no other way to know. Your server adds its own columns and teams:

```gdscript
server.scoreboard_fields = func(session): return {"team": team_of(session), "kills": kills_of(session)}
server.scoreboard_extra = func(): return {"teams": [{"id": 1, "name": "Red", "color": "#e5534b", "score": 4}],
    "header": {"Time left": "7:42"}}
```

Offline, or for a board that is entirely your own numbers, set `menu.scoreboard.source` to a function returning the same dictionary. Columns are data (`key`, `title`, `kind` of text, number, ping, duration, avatar or custom, `width`, `format`, `build`, `required`, `hidden`), `group_by` and `sort_by` choose teams and order, and `build_header`, `build_team_header` and `build_row` replace those pieces with your own.

**Players choose their columns, with no game code.** Settings > General > Scoreboard lists the live board's columns by title as switches and stores the choice in `scoreboard_hidden` (column keys; `+key` is "show this one though the game hides it"). A column with `"required": true` cannot be hidden (the `name` column is required unless it says `"required": false`); one with `"hidden": true` starts hidden and the player's choice wins. Choices are keyed by column key, so reordering or retitling columns keeps them and a key no column has is ignored. A column with no `title` (the avatar) gets no switch. `build_row` is given only the visible columns.

A game whose Escape is its own (a garage, a lobby) sets `menu.open_on_escape = false` and opens the menu some other way; Escape still closes it.

The other screens: `menu.open_help(commands, online)`, `menu.open_picker(items, title)` with the choice on `picked`, and `menu.open_layout_editor(hud, {&"timer": "Timer"})` with the layout on `menu.layout_editor.saved`. A screen of your own joins the same Escape handling with `menu.add_overlay(control)`. `theme_changed` gives you the new palette for your HUD.

## Settings
`DotMenuConfig` holds what a game developer can change without code. Like every Dot config it is layered: inspector defaults, then a JSON file, then the environment, then the command line.

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
DOT_MENU_THEME=paper godot --path . -- --menu-browser-tips=on
```

`settings` changes the schema (a default, a range, the options), so apply it with `config.apply_to_schema(schema)` before the settings are loaded. A changed default reaches a player who has never run the game; a player who already has a value keeps it.

| Setting | Default | What it does |
| --- | --- | --- |
| `brand_mark` | "" | The small filled mark at the top of the sidebar |
| `brand_name` | "Menu" | The words beside it |
| `theme` | midnight | The theme a new player gets |
| `themes_allowed` | all | Which themes are offered |
| `themes_file` | "" | A JSON file of more themes |
| `pages_hidden` | none | Page ids left out of the sidebar |
| `rows_hidden` | none | Row ids (a setting's key, or a row's own id) left off every page |
| `page_order` | as added | Page ids in sidebar order |
| `settings` | {} | Per setting: `default`, `min`, `max`, `step`, `options`, `description` |
| `rows` | {} | Per row: `title`, `description` |
| `fps_choices` | 0, 30, 60, 75, 120, 144, 165, 240, 300 | The frame-rate caps offered. 0 is unlimited |
| `show_help` | true | A Help entry in the sidebar |
| `help_hint` | top_right | Where the HUD's small "H  Help" plate sits: top_right, top_left, bottom_right, bottom_left or off |
| `show_leave` | true | A Leave entry in the sidebar |
| `leave_text` | Leave | The words on it |
| `browser_tips` | auto | The help screen's browser card: auto (in a browser), on or off |
| `command_prefix` | ! | Shown before each chat command on the help screen |
| `window_max_width` | 1060 | Widest the menu gets |
| `window_max_height` | 680 | Tallest the menu gets |
| `window_margin` | 24 | Gap kept from the window's edge |
| `sidebar_width` | 236 | Width of the sidebar |
| `layer` | 110 | The CanvasLayer the menus draw on, over the HUD and the chat box |
| `open_on_pointer_release` | true | Open the menu when the mouse is taken away (a browser's Escape) |
| `escape_grace_ms` | 250 | An Escape this soon after opening is ignored |
| `fps_counter` | true | Show the counter when the `show_fps` setting is on |
| `net_stat` | true | Draw the connection overlay when the `net_stat` setting asks for it |

The stock settings and their defaults:

| Key | Default | Range | Stored per |
| --- | --- | --- | --- |
| `master_volume` | 0.8 | 0 to 1 | device |
| `sfx_volume` | 1.0 | 0 to 1 | device |
| `ui_volume` | 0.8 | 0 to 1 | device |
| `voice_volume` | 1.0 | 0 to 1 | device |
| `ambience_volume` | 0.7 | 0 to 1 | device |
| `slide_volume` | 1.0 | 0 to 1 | device (applied by dot-game's slide sounds) |
| `music_volume` (asked for) | 0.6 | 0 to 1 | device |
| `window_mode` | windowed | windowed, borderless, fullscreen | device |
| `vsync` | off | | device |
| `fps_max` | 0 (unlimited) | 0 to 1000 | device |
| `render_scale` | 1.0 | 0.5 to 1 | device |
| `field_of_view` | 90 | 70 to 120 | account, a server may cap it |
| `viewmodel_fov` | 65 | 50 to 100 | device; only in a project with a `ZeeViewModel`, applied to every node in group `dot_view_model` |
| `fx_quality` | 3 | 0 to 3 | device |
| `sensitivity` | 2.5 | 0.05 to 20 | account, shared between games |
| `invert_mouse` | off | | account |
| `shake_scale` | 1.0 | 0 to 2 | device |
| `allow_flashes` | on | | device |
| `ui_theme` | midnight | the themes | account |
| `scoreboard_hidden` | empty | | device |
| `show_fps` | off | | device |
| `net_stat` | 0 (off) | 0 to 3 | device |
| `net_stat_height` | 96 | 32 to 320 pixels | device |
| `net_stat_position` | top_right | top_right, bottom_right, top_left, bottom_left | device |
| `chat_window` | auto | auto, on, off | account |

A theme file is a list of palettes. Any colour left out comes from `base`:

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

The self-test covers themes and theme files, the config and what it does to a schema, that every stock setting is applied by something and has a row, the key table and its swaps, the applier, the screens driven through their own controls, Escape and help and the theme key, what a server may do and how leaving undoes it, the help screen, the picker, the layout editor and the scoreboard. `tools/screenshot.sh` renders every page, every theme and every screen to `screenshots/` so you can look at them.

## License
MIT. See [LICENSE](LICENSE).
