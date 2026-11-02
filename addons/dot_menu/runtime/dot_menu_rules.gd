class_name DotMenuRules
extends RefCounted
## What a server (and the game's own `hide_rows`) hides, clamps or offers in a [DotMenu] while connected.

var rules: Dictionary = {}
## reason -> rows hidden for it.
var hidden_by: Dictionary = {}
var _menu: DotMenu


func _init(menu: DotMenu) -> void:
	_menu = menu


func apply(new_rules: Dictionary) -> PackedStringArray:
	rules = new_rules.duplicate(true)
	var applied := PackedStringArray()
	var screen := _menu.screen
	var settings := _menu.settings

	if screen != null:
		screen.extra_hidden_rows = hidden_rows()
		screen.extra_hidden_pages = strings(rules.get("pages_hidden", []))
		if rules.has("leave_text"):
			screen.set_action_text(&"leave", str(rules["leave_text"]))

	var clamps: Variant = rules.get("clamps", {})
	if clamps is Dictionary and not (clamps as Dictionary).is_empty() and settings != null and settings.policy != null:
		applied = settings.apply_server_clamps(clamps as Dictionary)

	var allowed := strings(rules.get("themes", []))
	if not allowed.is_empty():
		offer_themes(allowed)

	if screen != null:
		screen.refresh()
	return applied


func release() -> void:
	rules.clear()
	var screen := _menu.screen
	if screen != null:
		screen.extra_hidden_rows = hidden_rows()
		screen.extra_hidden_pages = PackedStringArray()
		screen.set_action_text(&"leave", _menu.leave_label())
	if _menu.settings != null and _menu.settings.policy != null:
		_menu.settings.release_clamps()
	offer_themes(PackedStringArray())
	if screen != null:
		screen.refresh()


func hide_rows(reason: StringName, rows: PackedStringArray) -> void:
	if rows.is_empty():
		hidden_by.erase(reason)
	else:
		hidden_by[reason] = rows
	if _menu.screen != null:
		_menu.screen.extra_hidden_rows = hidden_rows()
		_menu.screen.refresh()


func hidden_rows() -> PackedStringArray:
	var out := strings(rules.get("rows_hidden", []))
	for reason in hidden_by:
		for row in (hidden_by[reason] as PackedStringArray):
			if not out.has(row):
				out.append(row)
	return out


## Narrows the theme row to [param allowed] (empty is every theme) and moves off a theme the
## server does not offer, for this connection only; the stored choice is untouched.
func offer_themes(allowed: PackedStringArray) -> void:
	var row := _menu.find_row(&"ui_theme")
	var offered: Array = []
	for o in _menu.themes.options():
		if allowed.is_empty() or allowed.has(String(o[0])):
			offered.append(o)
	if row != null:
		row.options = offered
	var stored := _menu.stored_theme()
	if not allowed.is_empty() and not allowed.has(String(stored)):
		var _changed := _menu.use_theme(StringName(allowed[0]))
	else:
		var _changed := _menu.use_theme(stored)


static func strings(v: Variant) -> PackedStringArray:
	var out := PackedStringArray()
	if v is Array or v is PackedStringArray:
		for s in v:
			out.append(str(s))
	return out
