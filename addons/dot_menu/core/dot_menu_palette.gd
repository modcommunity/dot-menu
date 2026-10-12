@tool
class_name DotMenuPalette
extends Resource

## One theme: every colour a menu and a HUD are drawn in, under one id.
##
## [b]A whole palette, not an accent swap.[/b] A different accent on the same dark surface
## is one theme in four colours. A light theme and a high-contrast theme — for a player who
## cannot read grey on grey — need the surfaces and the text to move with the accent, so
## every colour a screen uses is here and nothing a screen draws is a literal.
##
## [b]The HUD's half is here too[/b] ([member hud_plate] and the eleven after it), because a
## player who picks a theme picks it for everything they look at. A light theme's HUD
## should still usually draw on a dark plate: the HUD is over the world, and a plate the
## colour of the sky is not a plate.
##
## [b]Data, so a theme can arrive from anywhere.[/b] [method from_dictionary] reads a
## colour as `"#rrggbb"`, `"#rrggbbaa"`, `[r, g, b]` or `[r, g, b, a]`, so a game can ship a
## theme as JSON, an operator can add one in a config file, and none of it needs code.
## A key the dictionary leaves out keeps the value of [param base], which is how a theme
## that only changes the accent stays three lines long.

## The id stored in the `ui_theme` setting. Unique within a [DotMenuThemes].
@export var id: StringName = &"midnight"

## What the menu calls it.
@export var display_name: String = "Midnight"

@export_group("Menus")
## Dims the game behind an open menu.
@export var backdrop := Color(0.02, 0.03, 0.05, 0.62)
## The menu's own window.
@export var surface := Color(0.075, 0.085, 0.115, 0.97)
## The column of page buttons down the left.
@export var sidebar := Color(0.055, 0.063, 0.088, 1.0)
## A rounded group of rows.
@export var card := Color(1.0, 1.0, 1.0, 0.035)
@export var card_hover := Color(1.0, 1.0, 1.0, 0.06)
## Borders and the rules between rows.
@export var line := Color(1.0, 1.0, 1.0, 0.07)
@export var text := Color(0.93, 0.945, 0.965)
## A description under a row's title.
@export var muted := Color(0.63, 0.67, 0.73)
## The least important words on the screen.
@export var dim := Color(0.44, 0.48, 0.55)
@export var accent := Color(0.33, 0.87, 0.78)
## The accent where it is filled behind text: a primary button, a switch that is on.
@export var accent_deep := Color(0.13, 0.58, 0.52)
@export var warn := Color(0.98, 0.74, 0.35)
@export var danger := Color(0.95, 0.43, 0.45)
@export var keycap := Color(0.16, 0.18, 0.23)
@export var keycap_edge := Color(0.27, 0.3, 0.37)

@export_group("HUD")
## The plate behind a HUD block drawn over the world. Deep and dark by default: the first
## play test (2026-10-11) found the bright plates read as a toy over a pale map.
@export var hud_plate := Color(0.025, 0.03, 0.05, 0.74)
@export var hud_text := Color(0.97, 0.98, 1.0)
@export var hud_detail := Color(0.72, 0.76, 0.84)
## Ahead of a comparison: a split under the record, health going up.
@export var hud_ahead := Color(0.42, 0.9, 0.55)
## Behind, and low: health or ammunition running out, a clock nearly done.
@export var hud_behind := Color(1.0, 0.34, 0.3)
## The thin line round a HUD plate.
@export var hud_edge := Color(1.0, 1.0, 1.0, 0.12)
## The outline round every HUD word, so it reads on any ground.
@export var hud_ink := Color(0.0, 0.0, 0.0, 0.9)
## "Yours" and "special" on the HUD: your own row, a headshot's number. A game's own accent
## usually replaces it (see [method hud_theme]).
@export var hud_highlight := Color(1.0, 0.8, 0.22)
## A key drawn as a key on the HUD ("[E] Open door"): the cap, its letter and its edge.
@export var hud_keycap := Color(0.13, 0.15, 0.2, 0.96)
@export var hud_keycap_text := Color(0.95, 0.96, 0.99)
@export var hud_keycap_edge := Color(1.0, 1.0, 1.0, 0.3)
## How much of a side's own colour fills its score plate, 0 to 1: a dark theme tints its
## plate and edges it in the colour; the bright one paints it.
@export_range(0.0, 1.0, 0.01) var hud_team_fill: float = 0.38

@export_group("")
## Colours a game names for itself — a team, a rarity, a medal — so they change with the
## theme too. Read with [method color]. Keys are StringNames, values Colors.
@export var extra: Dictionary = {}

## The colour fields, in the order [method to_dictionary] writes them. One list, read by
## both directions of the conversion, so the two can never disagree about a key.
const FIELDS: Array[StringName] = [
	&"backdrop", &"surface", &"sidebar", &"card", &"card_hover", &"line",
	&"text", &"muted", &"dim", &"accent", &"accent_deep", &"warn", &"danger",
	&"keycap", &"keycap_edge",
	&"hud_plate", &"hud_text", &"hud_detail", &"hud_ahead", &"hud_behind",
	&"hud_edge", &"hud_ink", &"hud_highlight", &"hud_keycap", &"hud_keycap_text", &"hud_keycap_edge",
]

## The non-colour numbers a theme holds, read and written beside [constant FIELDS].
const NUMBERS: Array[StringName] = [&"hud_team_fill"]


## The accent as a faint wash: a selected page, a hovered item, a listening key.
## Derived rather than stored, so a theme that changes its accent cannot forget it.
func accent_wash() -> Color:
	return Color(accent, 0.13)


## The [Theme] a HUD drawn in this palette sets on its root: dot-ui's glance pieces
## ([DotHudPiece]) and every plain Label under the root take their colours from it.
## [param accent] is the game's own: a [Theme] whose [DotHudPiece] colours (usually
## `highlight` and `plate_edge`, a game's identity) are laid over the palette's, so each game
## keeps its accent in every theme. An accent theme should leave the plate, the text and the
## ink alone, or a light or high-contrast theme cannot change them.
##
## A fresh [Theme] every call, for [DotUiTheme]'s reason. [DotMenu.follow_hud] sets it,
## and sets it again on every theme change.
func hud_theme(accent: Theme = null) -> Theme:
	var t := DotHudPiece.theme_from({
		&"plate": hud_plate, &"plate_edge": hud_edge, &"text": hud_text, &"dim": hud_detail,
		&"low": hud_behind, &"good": hud_ahead, &"highlight": hud_highlight, &"ink": hud_ink,
		&"keycap": hud_keycap, &"keycap_text": hud_keycap_text, &"keycap_edge": hud_keycap_edge,
	}, {&"team_fill": roundi(hud_team_fill * 100.0)})
	if accent != null:
		t.merge_with(accent)
	return t


## Whether the surfaces are light. A few things drawn straight in white — a switch's knob
## — need to know.
func is_light() -> bool:
	return surface.get_luminance() > 0.5


## A game's own colour, or [param fallback] when this theme does not name it.
func color(name: StringName, fallback: Color = Color.MAGENTA) -> Color:
	var c: Variant = extra.get(name, extra.get(String(name)))
	if c is Color:
		return c
	if c != null:
		var parsed: Variant = parse_color(c)
		if parsed is Color:
			return parsed
	return fallback


## Black or white, whichever reads on [param fill]. For text on the accent, which is a dark
## teal in one theme and a bright yellow in another.
static func ink_on(fill: Color) -> Color:
	return Color(0.04, 0.04, 0.05) if fill.get_luminance() > 0.55 else Color(0.97, 0.99, 1.0)


## A copy under a new id. What a theme that starts from another one is built with.
func derive(new_id: StringName, new_name: String) -> DotMenuPalette:
	var p := duplicate(true) as DotMenuPalette
	p.id = new_id
	p.display_name = new_name
	return p


## The palette as JSON-safe data: `"#rrggbbaa"` per colour.
func to_dictionary() -> Dictionary:
	var out := {"id": String(id), "name": display_name}
	for field in FIELDS:
		out[String(field)] = "#" + (get(field) as Color).to_html(true)
	for field in NUMBERS:
		out[String(field)] = float(get(field))
	if not extra.is_empty():
		var more := {}
		for k in extra:
			var c: Variant = extra[k]
			more[str(k)] = "#" + (c as Color).to_html(true) if c is Color else c
		out["extra"] = more
	return out


## A palette from data, on top of [param base] (or the stock default when null).
##
## Returns a [DotResult] rather than a half-built palette: a theme file with a colour
## nobody can read is a mistake its author wants to hear about, with the key named, and
## a theme that quietly drew that one colour in magenta would be found by a player.
static func from_dictionary(data: Dictionary, base: DotMenuPalette = null) -> DotResult:
	var p: DotMenuPalette = base.duplicate(true) if base != null else DotMenuPalette.new()

	var raw_id := str(data.get("id", ""))
	if raw_id == "":
		return DotResult.fail(DotError.CODE_INVALID, "A theme needs an id.")
	p.id = StringName(raw_id)
	p.display_name = str(data.get("name", data.get("display_name", raw_id.capitalize())))

	for field in FIELDS:
		var key := String(field)
		if not data.has(key):
			continue
		var c: Variant = parse_color(data[key])
		if c == null:
			return DotResult.fail(
				DotError.CODE_INVALID,
				"Theme '%s': '%s' is not a colour (%s)." % [raw_id, key, str(data[key])]
			)
		p.set(field, c)

	for field in NUMBERS:
		var key2 := String(field)
		if not data.has(key2):
			continue
		var n: Variant = data[key2]
		if not (n is float or n is int):
			return DotResult.fail(
				DotError.CODE_INVALID,
				"Theme '%s': '%s' is not a number (%s)." % [raw_id, key2, str(n)]
			)
		p.set(field, clampf(float(n), 0.0, 1.0))

	var more: Variant = data.get("extra", {})
	if more is Dictionary:
		for k in (more as Dictionary):
			var c2: Variant = parse_color((more as Dictionary)[k])
			if c2 == null:
				return DotResult.fail(
					DotError.CODE_INVALID,
					"Theme '%s': extra colour '%s' is not a colour." % [raw_id, str(k)]
				)
			p.extra[StringName(str(k))] = c2

	return DotResult.success(p)


## `"#rgb"`, `"#rrggbb"`, `"#rrggbbaa"`, a named colour, `[r, g, b]`, `[r, g, b, a]`, or a
## [Color]. Null for anything else.
static func parse_color(value: Variant) -> Variant:
	if value is Color:
		return value
	if value is String or value is StringName:
		var s := str(value).strip_edges()
		if s == "":
			return null
		if Color.html_is_valid(s):
			return Color.html(s)
		var named := Color.from_string(s, Color(-1, -1, -1, -1))
		return null if named.r < 0.0 else named
	if value is Array:
		var a := value as Array
		if a.size() < 3 or a.size() > 4:
			return null
		for n in a:
			if not (n is float or n is int):
				return null
		return Color(float(a[0]), float(a[1]), float(a[2]), float(a[3]) if a.size() == 4 else 1.0)
	return null


func describe() -> Dictionary:
	return {"id": String(id), "name": display_name, "light": is_light(), "extra": extra.size()}
