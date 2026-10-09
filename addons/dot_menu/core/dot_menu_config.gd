@tool
class_name DotMenuConfig
extends DotConfig

## What a game developer, and then a server operator, may change about a menu without
## writing code.
##
## [codeblock]
## {
##   "brand_mark": "g2g", "brand_name": "fast",
##   "theme": "ember", "themes_allowed": ["ember", "paper", "contrast"],
##   "themes_file": "res://ui/themes.json",
##   "pages_hidden": ["audio"], "rows_hidden": ["render_scale", "raw_input"],
##   "settings": {
##     "field_of_view": {"default": 90, "min": 75, "max": 120},
##     "shake_scale":   {"default": 0.0},
##     "window_mode":   {"options": ["windowed", "fullscreen"]}
##   },
##   "rows": {"fx_quality": {"title": "Particles", "description": "At the gates."}},
##   "fps_choices": [0, 60, 144, 240]
## }
## [/codeblock]
##
## Layered like every [DotConfig] — exported defaults < JSON file < environment < command
## line — so `DOT_MENU_THEME=paper` tries a theme for one run without editing anything.
##
## [b]Two times it is read, and they differ on purpose.[/b] [member settings] changes the
## SCHEMA — a default, a range, the options — so it has to be in place before the settings
## document is loaded, which makes it the game developer's: a JSON file in the game. What a
## SERVER may change arrives later, over the wire, into a document already loaded, and is
## narrower — see [method DotMenu.apply_server_rules]: it may hide rows and pages, offer
## fewer themes, and clamp what dot-settings lets it clamp. It can never change a player's
## stored value or read one.
##
## [b]A default is a first-run value, not a reset.[/b] dot-settings stores every value,
## defaults included, so a default changed here reaches a player who has never run the game
## and nobody else. That is correct — a player who has been playing at 90 should not wake
## up at 100 because an operator changed a file — and it is the reason a server clamps
## rather than sets.

## The small filled mark at the top of the sidebar ("g2g"). Empty draws none.
@export var brand_mark: String = ""

## The words beside it ("fast"). Empty draws none.
@export var brand_name: String = "Menu"

## The theme a player who has never chosen gets, and the one an unknown id resolves to.
@export var theme: StringName = &"midnight"

## The themes offered, in the catalogue's order. Empty is every theme.
@export var themes_allowed: PackedStringArray = PackedStringArray()

## A JSON file of further themes. See [method DotMenuThemes.load_json].
@export var themes_file: String = ""

## Page ids left out of the sidebar.
@export var pages_hidden: PackedStringArray = PackedStringArray()

## Row ids (a setting's key, or a row's own id) left off every page.
@export var rows_hidden: PackedStringArray = PackedStringArray()

## Page ids in the order the sidebar shows them. Pages not listed follow, in their own
## order. Empty keeps the order they were added in.
@export var page_order: PackedStringArray = PackedStringArray()

## Per setting: `{default, min, max, step, options, description}`. Applied to the schema by
## [method apply_to_schema], before the document is loaded.
@export var settings: Dictionary = {}

## Per row id: `{title, description}`. Rewords a row without touching code — a game's own
## words, or a translation.
@export var rows: Dictionary = {}

## The frame-rate caps the Video page offers. 0 is unlimited.
@export var fps_choices: Array = [0, 30, 60, 75, 120, 144, 165, 240, 300]

## Whether the sidebar has a Help entry, and a Leave entry.
@export var show_help: bool = true
@export var show_leave: bool = true

## The words on the Leave entry. A game that knows whether it is online sets it per open.
@export var leave_text: String = "Leave"

## "auto" (a browser), "on" or "off": the help screen's card of what a browser does with
## keys the game never sees.
@export var browser_tips: StringName = &"auto"

## Typed before a chat command on the help screen ("!rtv").
@export var command_prefix: String = "!"

## The menu window's largest size, and the gap it keeps from the edge of a small one.
@export var window_max_width: int = 1060
@export var window_max_height: int = 680
@export var window_margin: int = 24
@export var sidebar_width: int = 236

## The CanvasLayer the menu draws on. Over the HUD and over a chat box (dot-ui's is 100):
## a menu drawn under the chat is a menu with somebody's line across it.
@export var layer: int = 110

## Open the menu when a browser takes the pointer away. See [DotMenu].
@export var open_on_pointer_release: bool = true

## An Escape this soon after the menu opened is swallowed rather than closing it. See
## [DotMenu].
@export var escape_grace_ms: int = 250

## Show a frame-rate counter when the `show_fps` setting is on.
@export var fps_counter: bool = true


func env_prefix() -> String:
	return "DOT_MENU_"


func cli_prefix() -> String:
	return "--menu-"


func validate() -> DotResult:
	if not [&"auto", &"on", &"off"].has(browser_tips):
		return DotResult.fail(DotError.CODE_INVALID, "browser_tips is auto, on or off, not '%s'." % browser_tips)
	if window_max_width < 320 or window_max_height < 240:
		return DotResult.fail(DotError.CODE_INVALID, "The menu window cannot be smaller than 320 x 240.")
	for key in settings:
		if not (settings[key] is Dictionary):
			return DotResult.fail(DotError.CODE_INVALID, "settings.%s must be an object." % str(key))
	for key in rows:
		if not (rows[key] is Dictionary):
			return DotResult.fail(DotError.CODE_INVALID, "rows.%s must be an object." % str(key))
	return DotResult.success(null)


## The frame-rate caps as ints, sorted, with [param keep] added when it is not one of them —
## a value a player typed at the console must not vanish from the list that shows it.
func fps_list(keep: int = -1) -> Array[int]:
	var out: Array[int] = []
	for n in fps_choices:
		if (n is int or n is float) and not out.has(int(n)):
			out.append(int(n))
	if keep >= 0 and not out.has(keep):
		out.append(keep)
	out.sort()
	return out


## The theme catalogue this config describes: the stock six, the file's, narrowed to
## [member themes_allowed], with [member theme] first. What [DotMenu] draws with when it is
## given no catalogue of its own, and what [method apply_to_schema] offers.
func make_themes(base: DotMenuThemes = null) -> DotMenuThemes:
	var t := base if base != null else DotMenuThemes.stock()
	var loaded := t.load_json(themes_file)
	if not loaded.ok:
		DotLog.warn(CHANNEL, "themes file not used", {"why": loaded.error.message})
	var _kept := t.keep_only(themes_allowed)
	var _first := t.make_default(theme)
	return t


## Applies [member settings] to [param schema], and the theme catalogue to its `ui_theme`.
## Returns what it could not: a key the schema does not have, a field no setting has, a value
## the setting's kind cannot hold.
##
## [b]The themes go into the schema here, before the document is loaded, or they are lost.[/b]
## `ui_theme` is a choice over theme ids, and dot-settings corrects a stored value that is
## not one of the options when it LOADS. A theme that arrived from a file after that would be
## a value the setting refuses, and a player who chose it would be put back on the default
## at every start. Pass the catalogue the menu will use as [param themes] when a game adds
## themes in code; null builds it from this config.
##
## [b]Reported, not fatal[/b], for [DotConfig]'s reason: a menu that refuses to open because
## a config file mentions a setting from a newer build is worse than one that ignores it.
## A default outside a narrowed range is pulled inside it, because a default the setting
## would refuse is a document that cannot be loaded.
func apply_to_schema(schema: DotSettingsSchema, themes: DotMenuThemes = null) -> PackedStringArray:
	var problems := PackedStringArray()
	if schema == null:
		return problems

	var theme_def := schema.find(&"ui_theme")
	if theme_def != null:
		var t := themes if themes != null else make_themes()
		theme_def.options = t.ids()
		theme_def.default_value = t.default_id()

	for raw_key in settings:
		var key := StringName(str(raw_key))
		var def := schema.find(key)
		if def == null:
			problems.append("%s: no such setting" % key)
			continue

		var over: Dictionary = settings[raw_key]
		for field in over:
			match str(field):
				"min":
					def.min_value = float(over[field])
				"max":
					def.max_value = float(over[field])
				"step":
					def.step = float(over[field])
				"description":
					def.description = str(over[field])
				"options":
					var opts: Array[StringName] = []
					for o in (over[field] as Array):
						opts.append(StringName(str(o)))
					if opts.is_empty():
						problems.append("%s: an empty options list" % key)
					else:
						def.options = opts
				"default":
					pass
				_:
					problems.append("%s: no field '%s'" % [key, str(field)])

		if over.has("default"):
			var coerced := def.coerce(over["default"])
			if coerced.ok:
				def.default_value = coerced.value
			else:
				problems.append("%s: default %s (%s)" % [key, str(over["default"]), coerced.error.message])

		# Whatever moved, the default must still be a value the setting accepts.
		if def.kind == DotSettingsDef.Kind.ENUM and not def.options.has(StringName(str(def.default_value))):
			def.default_value = def.options[0]
		var held := def.coerce(def.default_value)
		if held.ok:
			def.default_value = held.value

	for p in problems:
		DotLog.warn(CHANNEL, "a menu setting override was not applied", {"why": p})
	return problems


## The words for [param row_id]: the config's, or the row's own.
func row_title(row_id: StringName, fallback: String) -> String:
	var over: Variant = rows.get(String(row_id), rows.get(row_id))
	return str((over as Dictionary).get("title", fallback)) if over is Dictionary else fallback


func row_description(row_id: StringName, fallback: String) -> String:
	var over: Variant = rows.get(String(row_id), rows.get(row_id))
	return str((over as Dictionary).get("description", fallback)) if over is Dictionary else fallback


func describe_lines(_redact_sensitive: bool = true) -> PackedStringArray:
	var out := PackedStringArray()
	out.append("menu: theme %s, %s" % [theme, "all themes" if themes_allowed.is_empty() else ", ".join(themes_allowed)])
	if not pages_hidden.is_empty():
		out.append("  pages hidden: %s" % ", ".join(pages_hidden))
	if not rows_hidden.is_empty():
		out.append("  rows hidden: %s" % ", ".join(rows_hidden))
	if not settings.is_empty():
		out.append("  settings overridden: %s" % ", ".join(PackedStringArray(settings.keys().map(func(k: Variant) -> String: return str(k)))))
	return out
