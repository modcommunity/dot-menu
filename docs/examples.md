# Examples

The usage snippets that used to sit in class doc comments.

## dot_menu_bindings

```gdscript
var keys := DotMenuBindings.new()
keys.add_movement()                                   # dot_fps_* — WASD, Space, Ctrl
keys.add(&"mygame_reload", &"bind_reload", "Reload", "R", "Combat")
keys.add_to_schema(schema)                            # one binding setting per row
keys.apply_all(settings)                              # onto the InputMap, at boot
```

## dot_menu_config

```gdscript
{
  "brand_mark": "g2g", "brand_name": "fast",
  "theme": "ember", "themes_allowed": ["ember", "paper", "contrast"],
  "themes_file": "res://ui/themes.json",
  "pages_hidden": ["audio"], "rows_hidden": ["render_scale", "raw_input"],
  "settings": {
    "field_of_view": {"default": 90, "min": 75, "max": 120},
    "shake_scale":   {"default": 0.0},
    "window_mode":   {"options": ["windowed", "fullscreen"]}
  },
  "rows": {"fx_quality": {"title": "Particles", "description": "At the gates."}},
  "fps_choices": [0, 60, 144, 240]
}
```

## dot_menu_kit

```gdscript
var kit := DotMenuKit.new(themes.named(&"ember"))
kit.font = preload("res://ui/my_font.ttf")
kit.size_body = 16
```

## dot_menu_page

```gdscript
var page := DotMenuPage.make(&"gameplay", "Gameplay", "Your style and your view.")
page.section("View").add(DotMenuRow.toggle(&"show_own_body", "Your own body"))
menu.add_page(page, &"video")        # before Video
```

## dot_menu_row

```gdscript
DotMenuRow.toggle(&"show_fps", "Frame rate counter", "In the top-right corner.")
DotMenuRow.slider(&"master_volume", "Master").formatted(DotMenuRow.FORMAT_PERCENT)
DotMenuRow.select(&"window_mode", "Window")          # options from the setting itself
DotMenuRow.live_toggle("Flashlight", "", is_on, set_on).enabled_when(server_allows)
DotMenuRow.button("Arrange", "Drag the HUD around.", "Move HUD elements", open_editor)
DotMenuRow.custom("Name", "", func(kit): return LineEdit.new())
```

## dot_menu_themes

```gdscript
var themes := DotMenuThemes.stock()          # the seven this addon ships
themes.add(my_palette)                       # a game's own
themes.load_json("res://ui/themes.json")     # or a file of them
themes.keep_only(["midnight", "paper"])      # an operator's choice of which to offer
```

## dot_menu

```gdscript
var menu := DotMenu.new()
menu.settings = settings                       # a DotSettingsManager, set up
menu.bindings = keys                           # a DotMenuBindings
menu.config = config                           # a DotMenuConfig; null is the stock one
menu.help_action = &"mygame_help"              # optional: H is dot_menu_help already
menu.theme_action = &"mygame_theme_next"       # optional: a key that cycles themes
add_child(menu)
menu.setup()                                   # the stock pages, the themes, the screens
menu.page(&"general").section("HUD").add(DotMenuRow.toggle(&"show_speed", "Speed"))
menu.action_requested.connect(func(id): if id == &"leave": leave())
menu.overlays_changed.connect(func(open): sampler.suspended = open)
```

## dot_menu (apply_server_rules)

```gdscript
{
  "rows_hidden":  ["field_of_view"],        # left off every page
  "pages_hidden": ["audio"],
  "themes":       ["midnight", "contrast"], # offered; the player's own stays if allowed
  "clamps":       {"field_of_view": 100},   # through dot-settings' policy
  "leave_text":   "Disconnect"
}
```

## dot_menu_applier

```gdscript
var applier := DotMenuApplier.new()
applier.settings = settings
applier.bindings = keys
add_child(applier)
applier.bind_audio(audio)                  # a DotAudioManager, or its mixer
applier.bind_fx(fx)                        # a DotFxManager, or its config
applier.bind_look(sampler.tunables)        # sensitivity and invert
applier.bind_camera(camera)                # field of view
applier.on(&"show_own_body", func(v, _why): player.show_own_body = v)
applier.setup()                            # connects, and applies everything now
```

## dot_menu_loadout

```gdscript
var loadout := menu.use_loadout(
	func() -> Variant: return await game.loadouts.offer_for(my_key),      # solo: the offer
	func(picks: Dictionary) -> Variant: return await game.choose(picks),  # solo: save them
	func(slot_id: String, choice: Dictionary) -> Dictionary:              # art and numbers
		return {"icon": icons[choice.id], "stats": stats_for(choice.id)})
loadout.remember_as("arena", account_name)
loadout.restore()      # after joining: re-sends what this account chose last time
```

## dot_menu_maps

```gdscript
var maps := menu.use_maps(
	func() -> Array: return [{"id": "dm_atrium", "name": "Atrium", "mode": "Deathmatch",
		"thumbnail": "res://maps/atrium.png", "current": true}, ...],
	func(id: StringName) -> DotResult: return world.change_map_now(id))
```

## dot_menu_settings

```gdscript
var settings := DotMenuSettings.new()
settings.directory = "user://my_game_settings"
settings.app_namespace = &"my_game"
settings.schema = my_schema()          # null is the stock set
add_child(settings)
settings.setup()                       # loads, applies everything, builds the menu
settings.bind_look(sampler.tunables)
settings.bind_camera(camera)
settings.bind_audio(audio)
settings.menu_state_changed.connect(func(open): sampler.suspended = open)
```

## dot_menu_stock

```gdscript
var schema := DotSettingsSchema.new()
DotMenuStock.declare(schema)                 # audio, video, controls, comfort, interface
# ... the game's own settings ...
config.apply_to_schema(schema)               # the developer's defaults and ranges

var pages := DotMenuStock.pages()            # General, Video, Audio, Controls
```

## dot_addon_config_editor_screen

```gdscript
var ed := DotAddonConfigEditorScreen.new()
add_child(ed)
ed.add_file("dot-weapon", "tuning.yml", schema, "Weapon tuning")
ed.open("dot-weapon", "tuning.yml")   # Apply saves to the user tier; Reset deletes the file
```

## dot_menu_frame_clock

```gdscript
var clock := DotMenuFrameClock.new()
clock.start(get_tree())
# ... later, any number of frames on:
var s := clock.summary(1.0)   # {fps, mean_ms, worst_ms, physics_ms, steps, ...}
```

## dot_menu_layout_editor

```gdscript
editor.target = hud
editor.pieces = {&"timer": "Timer", &"keys": "Keys"}
editor.saved.connect(func(text): settings.set_value(&"hud_positions", text))
editor.open()
```

## dot_menu_loadout_screen

```gdscript
screen.open({
	"choose": true, "budget": 7, "note": "",
	"slots": [{"id": "primary", "name": "Primary", "current": "rifle", "fixed": false,
		"choices": [{"id": "rifle", "name": "Rifle", "cost": 2, "tags": ["automatic"],
			"icon": rifle_texture, "detail": "Full auto, steady at range",
			"stats": [{"label": "Damage", "value": 0.4, "text": "24"}, ...]}]}]})
screen.committed.connect(func(picks: Dictionary): send(picks))   # slot -> item, changed only
```

## dot_menu_net_stat

```gdscript
net_stat 1    # numbers: frame rate, ping and jitter, in and out, loss
net_stat 2    # and a graph of what arrives, by channel, with ping drawn across it
net_stat 3    # and what leaves, where each frame went, prediction, the server's frame
net_stat 0    # off
```

## dot_menu_picker

```gdscript
picker.title_text = "Change map — this server"
picker.open([{"id": "surf_intro", "name": "Surf Intro", "tags": ["tier 1"], "current": true}])
picker.chosen.connect(func(id): change_map(id))
# in the host's input handler, while it is open:
if picker.key(event.keycode): get_viewport().set_input_as_handled()
```

## dot_menu_scoreboard

```gdscript
var board := menu.scoreboard                      # DotMenu builds one; Tab holds it open
board.columns = DotMenuScoreboard.default_columns()
board.add_column({"key": &"kills", "title": "K"}, &"score")   # before Score
board.feed_from(link)                             # the server's roster, while held
# or, offline / for a game's own numbers:
board.source = func() -> Dictionary: return {"server": {...}, "players": [...]}
board.decorate = func(row): row["avatar"] = faces.get(row["id"])
```

## dot_menu_screen

```gdscript
var screen := DotMenuScreen.new()
screen.kit = DotMenuKit.new(themes.named(&"midnight"))
screen.settings = settings
screen.bindings = keys
screen.pages = DotMenuStock.pages()
add_child(screen)
screen.open()
```

## dot_profile_editor_screen

```gdscript
var ed := DotProfileEditorScreen.new()
add_child(ed)
ed.add_set(npc_set, "NPCs")
ed.open("npc", "zombie")   # Apply saves to the player's user tier by default
```
