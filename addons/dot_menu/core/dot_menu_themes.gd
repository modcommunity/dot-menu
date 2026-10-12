class_name DotMenuThemes
extends RefCounted

## Every theme a player can pick, in the order the menu offers them and a key cycles them.
##
## [codeblock]
## var themes := DotMenuThemes.stock()          # the seven this addon ships
## themes.add(my_palette)                       # a game's own
## themes.load_json("res://ui/themes.json")     # or a file of them
## themes.keep_only(["midnight", "paper"])      # an operator's choice of which to offer
## [/codeblock]
##
## [b]The first theme is the default[/b], and an id nobody knows — a settings document from
## a newer build, a theme a server no longer offers, one typed by hand — resolves to it
## rather than to no palette. A menu that cannot draw is worse than one in the wrong colours.
##
## [b]An instance, not a static list.[/b] Two menus in one process — a server and a client
## in one editor session, a launcher and the game it launched — may offer different themes,
## and a static catalogue would make one of them wrong.

const CHANNEL := "menu.themes"

var _palettes: Array[DotMenuPalette] = []


## The seven stock themes. [b]Midnight[/b] is the default, a dark HUD on deep plates;
## [b]Arcade[/b] is the first arena HUD's bright look; [b]Paper[/b] is light; [b]High
## contrast[/b] is for a player who cannot read grey on grey.
static func stock() -> DotMenuThemes:
	var t := DotMenuThemes.new()
	for data in STOCK:
		var res := DotMenuPalette.from_dictionary(data)
		# The stock data is this file's; a failure here is a typo in it and the suite says so.
		if res.ok:
			t.add(res.value)
	return t


## The stock palettes as data, in the format [method DotMenuPalette.from_dictionary] reads,
## so they are also the worked example of a theme file.
const STOCK: Array[Dictionary] = [
	{
		"id": "midnight", "name": "Midnight",
		"backdrop": [0.02, 0.03, 0.05, 0.62], "surface": [0.075, 0.085, 0.115, 0.97],
		"sidebar": [0.055, 0.063, 0.088, 1.0], "card": [1, 1, 1, 0.035],
		"card_hover": [1, 1, 1, 0.06], "line": [1, 1, 1, 0.07],
		"text": [0.93, 0.945, 0.965], "muted": [0.63, 0.67, 0.73], "dim": [0.44, 0.48, 0.55],
		"accent": [0.33, 0.87, 0.78], "accent_deep": [0.13, 0.58, 0.52],
		"warn": [0.98, 0.74, 0.35], "danger": [0.95, 0.43, 0.45],
		"keycap": [0.16, 0.18, 0.23], "keycap_edge": [0.27, 0.3, 0.37],
		"hud_plate": [0.02, 0.028, 0.045, 0.76], "hud_text": [0.97, 0.98, 1.0], "hud_detail": [0.72, 0.77, 0.85],
		"hud_ahead": [0.42, 0.9, 0.55], "hud_behind": [1.0, 0.36, 0.32],
		"hud_edge": [0.33, 0.87, 0.78, 0.2], "hud_ink": [0, 0, 0, 0.9], "hud_highlight": [1.0, 0.8, 0.25],
		"hud_keycap": [0.11, 0.13, 0.18, 0.96], "hud_keycap_text": [0.95, 0.97, 0.99],
		"hud_keycap_edge": [0.33, 0.87, 0.78, 0.55], "hud_team_fill": 0.35,
	},
	{
		"id": "ember", "name": "Ember",
		"backdrop": [0.05, 0.03, 0.02, 0.62], "surface": [0.11, 0.08, 0.065, 0.97],
		"sidebar": [0.085, 0.06, 0.05, 1.0], "card": [1, 0.9, 0.8, 0.04],
		"card_hover": [1, 0.9, 0.8, 0.07], "line": [1, 0.9, 0.8, 0.08],
		"text": [0.97, 0.94, 0.9], "muted": [0.74, 0.66, 0.6], "dim": [0.55, 0.47, 0.42],
		"accent": [1.0, 0.6, 0.25], "accent_deep": [0.72, 0.36, 0.1],
		"warn": [1.0, 0.82, 0.4], "danger": [0.95, 0.38, 0.38],
		"keycap": [0.21, 0.16, 0.13], "keycap_edge": [0.36, 0.27, 0.22],
		"hud_plate": [0.07, 0.035, 0.02, 0.76], "hud_text": [1.0, 0.96, 0.9], "hud_detail": [0.92, 0.78, 0.64],
		"hud_ahead": [0.5, 0.92, 0.45], "hud_behind": [1.0, 0.42, 0.32],
		"hud_edge": [1.0, 0.6, 0.25, 0.22], "hud_ink": [0.04, 0.01, 0.0, 0.9], "hud_highlight": [1.0, 0.75, 0.3],
		"hud_keycap": [0.2, 0.12, 0.08, 0.96], "hud_keycap_text": [1.0, 0.95, 0.88],
		"hud_keycap_edge": [1.0, 0.6, 0.25, 0.55], "hud_team_fill": 0.38,
	},
	{
		"id": "violet", "name": "Violet",
		"backdrop": [0.03, 0.02, 0.06, 0.62], "surface": [0.09, 0.075, 0.13, 0.97],
		"sidebar": [0.065, 0.055, 0.1, 1.0], "card": [0.9, 0.85, 1, 0.04],
		"card_hover": [0.9, 0.85, 1, 0.07], "line": [0.9, 0.85, 1, 0.08],
		"text": [0.95, 0.93, 0.99], "muted": [0.69, 0.65, 0.78], "dim": [0.5, 0.46, 0.6],
		"accent": [0.72, 0.55, 1.0], "accent_deep": [0.46, 0.3, 0.78],
		"warn": [0.98, 0.76, 0.4], "danger": [1.0, 0.45, 0.6],
		"keycap": [0.18, 0.15, 0.26], "keycap_edge": [0.31, 0.26, 0.42],
		"hud_plate": [0.04, 0.02, 0.09, 0.76], "hud_text": [0.96, 0.94, 1.0], "hud_detail": [0.8, 0.74, 0.95],
		"hud_ahead": [0.45, 0.95, 0.65], "hud_behind": [1.0, 0.45, 0.6],
		"hud_edge": [0.72, 0.55, 1.0, 0.22], "hud_ink": [0.02, 0.0, 0.05, 0.9], "hud_highlight": [1.0, 0.82, 0.35],
		"hud_keycap": [0.15, 0.11, 0.24, 0.96], "hud_keycap_text": [0.96, 0.94, 1.0],
		"hud_keycap_edge": [0.72, 0.55, 1.0, 0.55], "hud_team_fill": 0.38,
	},
	{
		"id": "classic", "name": "Classic",
		"backdrop": [0.0, 0.0, 0.0, 0.55], "surface": [0.17, 0.18, 0.16, 0.97],
		"sidebar": [0.13, 0.14, 0.12, 1.0], "card": [0.0, 0.0, 0.0, 0.18],
		"card_hover": [0.0, 0.0, 0.0, 0.28], "line": [1, 1, 1, 0.09],
		"text": [0.86, 0.87, 0.82], "muted": [0.66, 0.68, 0.6], "dim": [0.5, 0.52, 0.45],
		"accent": [0.85, 0.78, 0.3], "accent_deep": [0.55, 0.5, 0.18],
		"warn": [0.95, 0.7, 0.3], "danger": [0.9, 0.35, 0.3],
		"keycap": [0.24, 0.25, 0.22], "keycap_edge": [0.38, 0.39, 0.34],
		"hud_plate": [0.0, 0.0, 0.0, 0.64], "hud_text": [1.0, 1.0, 1.0], "hud_detail": [0.85, 0.82, 0.6],
		"hud_ahead": [0.3, 1.0, 0.3], "hud_behind": [1.0, 0.3, 0.3],
		"hud_edge": [1, 1, 1, 0.1], "hud_ink": [0, 0, 0, 0.9], "hud_highlight": [0.95, 0.85, 0.35],
		"hud_keycap": [0.22, 0.23, 0.2, 0.95], "hud_keycap_text": [0.95, 0.95, 0.9],
		"hud_keycap_edge": [0.85, 0.78, 0.3, 0.5], "hud_team_fill": 0.5,
	},
	{
		# The first arena HUD's bright look, kept for a player who liked it: pale see-through
		# plates, white key caps, score plates painted in the side's colour.
		"id": "arcade", "name": "Arcade",
		"backdrop": [0.03, 0.04, 0.09, 0.6], "surface": [0.09, 0.11, 0.19, 0.97],
		"sidebar": [0.07, 0.085, 0.15, 1.0], "card": [1, 1, 1, 0.045],
		"card_hover": [1, 1, 1, 0.08], "line": [1, 1, 1, 0.09],
		"text": [0.96, 0.97, 1.0], "muted": [0.7, 0.75, 0.86], "dim": [0.5, 0.55, 0.68],
		"accent": [0.36, 0.66, 1.0], "accent_deep": [0.2, 0.45, 0.9],
		"warn": [1.0, 0.8, 0.22], "danger": [1.0, 0.36, 0.4],
		"keycap": [0.93, 0.94, 0.97], "keycap_edge": [0.7, 0.73, 0.8],
		"hud_plate": [0.06, 0.07, 0.11, 0.62], "hud_text": [0.97, 0.98, 1.0], "hud_detail": [0.82, 0.85, 0.92],
		"hud_ahead": [0.45, 0.92, 0.55], "hud_behind": [1.0, 0.32, 0.28],
		"hud_edge": [1, 1, 1, 0.14], "hud_ink": [0.02, 0.02, 0.05, 0.85], "hud_highlight": [1.0, 0.8, 0.22],
		"hud_keycap": [0.93, 0.94, 0.97, 0.95], "hud_keycap_text": [0.08, 0.09, 0.14],
		"hud_keycap_edge": [0, 0, 0, 0], "hud_team_fill": 1.0,
	},
	{
		"id": "paper", "name": "Paper",
		"backdrop": [0.92, 0.93, 0.95, 0.5], "surface": [0.97, 0.97, 0.96, 0.98],
		"sidebar": [0.92, 0.92, 0.9, 1.0], "card": [0, 0, 0, 0.035],
		"card_hover": [0, 0, 0, 0.06], "line": [0, 0, 0, 0.09],
		"text": [0.1, 0.11, 0.13], "muted": [0.34, 0.36, 0.4], "dim": [0.5, 0.52, 0.56],
		"accent": [0.1, 0.45, 0.85], "accent_deep": [0.1, 0.4, 0.78],
		"warn": [0.75, 0.45, 0.0], "danger": [0.78, 0.15, 0.2],
		"keycap": [1.0, 1.0, 1.0], "keycap_edge": [0.72, 0.73, 0.76],
		# The menus are light; the HUD is not. It is drawn over the world, where a plate the
		# colour of the sky is not a plate and a game's white names vanish on it (arena's
		# kill feed, rendered 2026-10-12). Dark plates edged in the theme's blue, paper caps.
		"hud_plate": [0.05, 0.06, 0.09, 0.78], "hud_text": [0.98, 0.98, 1.0], "hud_detail": [0.78, 0.8, 0.86],
		"hud_ahead": [0.35, 0.85, 0.45], "hud_behind": [1.0, 0.38, 0.38],
		"hud_edge": [0.25, 0.55, 0.95, 0.4], "hud_ink": [0, 0, 0, 0.9], "hud_highlight": [1.0, 0.78, 0.25],
		"hud_keycap": [0.96, 0.96, 0.97, 0.96], "hud_keycap_text": [0.1, 0.11, 0.13],
		"hud_keycap_edge": [0.25, 0.55, 0.95, 0.7], "hud_team_fill": 0.45,
	},
	{
		"id": "contrast", "name": "High contrast",
		"backdrop": [0, 0, 0, 0.8], "surface": [0, 0, 0, 1.0],
		"sidebar": [0.06, 0.06, 0.06, 1.0], "card": [1, 1, 1, 0.06],
		"card_hover": [1, 1, 1, 0.14], "line": [1, 1, 1, 0.3],
		"text": [1, 1, 1], "muted": [0.9, 0.9, 0.9], "dim": [0.78, 0.78, 0.78],
		"accent": [1.0, 0.86, 0.0], "accent_deep": [0.85, 0.7, 0.0],
		"warn": [1.0, 0.7, 0.0], "danger": [1.0, 0.35, 0.35],
		"keycap": [0.12, 0.12, 0.12], "keycap_edge": [1, 1, 1, 0.7],
		"hud_plate": [0, 0, 0, 0.88], "hud_text": [1, 1, 1], "hud_detail": [1.0, 0.92, 0.4],
		"hud_ahead": [0.3, 1.0, 0.4], "hud_behind": [1.0, 0.35, 0.35],
		"hud_edge": [1, 1, 1, 0.55], "hud_ink": [0, 0, 0, 1], "hud_highlight": [1.0, 0.86, 0.0],
		"hud_keycap": [0, 0, 0, 1], "hud_keycap_text": [1, 1, 1],
		"hud_keycap_edge": [1, 1, 1, 0.9], "hud_team_fill": 0.3,
	},
]


## Adds [param palette], or replaces the theme that has its id in place — so a game can
## restyle a stock theme without moving it in the list.
func add(palette: DotMenuPalette) -> DotMenuThemes:
	if palette == null:
		return self
	for i in range(_palettes.size()):
		if _palettes[i].id == palette.id:
			_palettes[i] = palette
			return self
	_palettes.append(palette)
	return self


## Adds a theme from data. See [method DotMenuPalette.from_dictionary]; [code]"base"[/code]
## names a theme already here to start from, which is how a theme that changes only the
## accent stays three lines long.
func add_dictionary(data: Dictionary) -> DotResult:
	var base: DotMenuPalette = null
	if data.has("base"):
		base = find(StringName(str(data["base"])))
		if base == null:
			return DotResult.fail(
				DotError.CODE_INVALID,
				"Theme '%s' starts from '%s', which is not a theme." % [str(data.get("id", "")), str(data["base"])]
			)
	var res := DotMenuPalette.from_dictionary(data, base)
	if res.ok:
		var _added := add(res.value)
	return res


## Adds every theme in a JSON file: `{"themes": [ {...}, ... ]}` or a bare array.
##
## A missing file is not an error, for [DotConfig]'s reason: "no themes file" is the first
## launch. A file that exists and does not parse is — somebody wrote it and meant it.
## Returns the ids it added.
func load_json(path: String) -> DotResult:
	if path == "" or not FileAccess.file_exists(path):
		return DotResult.success(PackedStringArray())

	var read := DotPaths.read_json(path)
	if not read.ok:
		return read.wrap("Could not read themes '%s'." % path)

	var list: Variant = read.value
	if list is Dictionary:
		list = (list as Dictionary).get("themes", [])
	if not (list is Array):
		return DotResult.fail(DotError.CODE_PARSE, "Themes '%s' must hold an array of themes." % path)

	var added := PackedStringArray()
	for entry in (list as Array):
		if not (entry is Dictionary):
			return DotResult.fail(DotError.CODE_PARSE, "Themes '%s': every theme is an object." % path)
		var res := add_dictionary(entry as Dictionary)
		if not res.ok:
			return res.wrap("Themes '%s'." % path)
		added.append(String((res.value as DotMenuPalette).id))

	DotLog.debug(CHANNEL, "themes loaded", {"path": path, "ids": ", ".join(added)})
	return DotResult.success(added)


## Keeps only the themes in [param ids], in their current order. Empty keeps everything.
## Refuses to empty the catalogue: a list naming no theme there is a typo, and a menu with
## no theme cannot draw.
func keep_only(ids: PackedStringArray) -> int:
	if ids.is_empty():
		return _palettes.size()
	var kept: Array[DotMenuPalette] = []
	for p in _palettes:
		if ids.has(String(p.id)):
			kept.append(p)
	if kept.is_empty():
		DotLog.warn(CHANNEL, "no listed theme exists; every theme is kept", {"ids": ", ".join(ids)})
		return _palettes.size()
	_palettes = kept
	return kept.size()


## Makes [param id] the first theme, which is the default. False if there is no such theme.
func make_default(id: StringName) -> bool:
	for i in range(_palettes.size()):
		if _palettes[i].id == id:
			var p := _palettes[i]
			_palettes.remove_at(i)
			_palettes.insert(0, p)
			return true
	return false


func remove(id: StringName) -> bool:
	if _palettes.size() <= 1:
		return false
	for i in range(_palettes.size()):
		if _palettes[i].id == id:
			_palettes.remove_at(i)
			return true
	return false


func find(id: StringName) -> DotMenuPalette:
	for p in _palettes:
		if p.id == id:
			return p
	return null


## The theme called [param id], or the default for an id nobody knows.
func named(id: StringName) -> DotMenuPalette:
	var p := find(id)
	if p != null:
		return p
	return _palettes[0] if not _palettes.is_empty() else DotMenuPalette.new()


## The theme after [param id], round the end. What the theme key does.
func next(id: StringName) -> StringName:
	if _palettes.is_empty():
		return id
	for i in range(_palettes.size()):
		if _palettes[i].id == id:
			return _palettes[(i + 1) % _palettes.size()].id
	return _palettes[0].id


func ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for p in _palettes:
		out.append(p.id)
	return out


## `[[id, name], ...]`, the shape a select row takes.
func options() -> Array:
	var out: Array = []
	for p in _palettes:
		out.append([p.id, p.display_name])
	return out


func size() -> int:
	return _palettes.size()


func default_id() -> StringName:
	return _palettes[0].id if not _palettes.is_empty() else &"midnight"


func describe() -> Dictionary:
	return {"themes": ids().map(func(i: StringName) -> String: return String(i))}
