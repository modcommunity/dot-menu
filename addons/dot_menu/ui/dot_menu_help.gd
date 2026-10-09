class_name DotMenuHelp
extends Control

## The help screen: every key as it is bound now, the server's commands, and — in a browser —
## what the browser does with keys the game never sees.
##
## [b]Nothing on it is written down here.[/b] The keys come from [DotMenuBindings] and show
## the player's own bindings, not the defaults; the commands come from whatever the server
## said when this client joined. A key rebound a minute ago and a command added to the server
## last week are both on it, and neither needed this file edited. A help screen that is a
## list somebody typed is wrong the first time anybody changes anything, and nothing says so.
##
## A game adds its own cards with [method add_section] — "Running", "Your objective" — which
## go in the right-hand column above the commands.

signal closed()

var kit: DotMenuKit = null
var bindings: DotMenuBindings = null
var config: DotMenuConfig = null

## `[[name, help], ...]` from the server. Empty offline.
var commands: Array = []

## Whether this client has a server to send commands to.
var online: bool = false

## The action that opens this screen, for the "H or Esc to close" hint. Empty draws Esc alone.
var help_action: StringName = &""

var title_text: String = "Help"
var intro: String = "Your keys as they are bound now — change them under Menu → Controls. Commands are typed in chat."

## Lines added to a key group's card after its bindings: `{group: [[key, what], ...]}`.
## [DotMenu] puts Escape here, which is in no binding row on purpose.
var extra_keys: Dictionary = {}

## Whether to draw the browser card. Null follows the config ("auto" is a browser); settable
## so a screenshot of a desktop build can show what a browser player sees.
var show_browser_tips: Variant = null

var _sections: Array[Dictionary] = []
var _window: PanelContainer = null
var _keys_column: VBoxContainer = null
var _side_column: VBoxContainer = null
var _built := false


func _ready() -> void:
	if kit == null:
		kit = DotMenuKit.new()
	if config == null:
		config = DotMenuConfig.new()
	DotMenuKit.fill_parent(self)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_build()
	get_viewport().size_changed.connect(_fit)
	_fit()


## A card in the right-hand column: `[[label, text], ...]`. [param style] &"keys" draws the
## labels as keycaps, &"tips" as warning-coloured words, &"plain" as accent words. A section
## with the same title replaces the old one.
func add_section(title: String, lines: Array, style: StringName = &"tips") -> void:
	for s in _sections:
		if s["title"] == title:
			s["lines"] = lines
			s["style"] = style
			return
	_sections.append({"title": title, "lines": lines, "style": style})


func remove_section(title: String) -> bool:
	for i in range(_sections.size()):
		if _sections[i]["title"] == title:
			_sections.remove_at(i)
			return true
	return false


## Rebuilds this screen in [param new_kit]. See [method DotMenuScreen.restyle].
func restyle(new_kit: DotMenuKit) -> void:
	kit = new_kit
	if not _built:
		return
	DotMenuKit.clear(self)
	_build()
	_fit()
	if visible:
		_rebuild()


func _build() -> void:
	var p := kit.palette
	theme = kit.theme()

	var back := ColorRect.new()
	back.color = Color(p.backdrop, 0.72)
	DotMenuKit.fill_parent(back)
	add_child(back)

	var centre := CenterContainer.new()
	DotMenuKit.fill_parent(centre)
	add_child(centre)

	_window = PanelContainer.new()
	var s := kit.surface_box()
	s.content_margin_left = 30
	s.content_margin_right = 22
	s.content_margin_top = 24
	s.content_margin_bottom = 20
	_window.add_theme_stylebox_override(&"panel", s)
	centre.add_child(_window)

	var col := VBoxContainer.new()
	col.add_theme_constant_override(&"separation", 8)
	_window.add_child(col)

	var head := HBoxContainer.new()
	head.name = "Head"
	var title := kit.label(title_text, kit.size_title, p.text, true)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var hint := HBoxContainer.new()
	hint.name = "Hint"
	hint.add_theme_constant_override(&"separation", 6)
	head.add_child(hint)
	col.add_child(head)
	col.add_child(kit.paragraph(intro))

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)

	var pad := MarginContainer.new()
	pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pad.add_theme_constant_override(&"margin_right", 10)
	pad.add_theme_constant_override(&"margin_top", 8)
	scroll.add_child(pad)

	var body := HBoxContainer.new()
	body.add_theme_constant_override(&"separation", 22)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pad.add_child(body)

	_keys_column = VBoxContainer.new()
	_keys_column.name = "Keys"
	_keys_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_keys_column.add_theme_constant_override(&"separation", 10)
	body.add_child(_keys_column)

	_side_column = VBoxContainer.new()
	_side_column.name = "Side"
	_side_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_side_column.size_flags_stretch_ratio = 1.25
	_side_column.add_theme_constant_override(&"separation", 10)
	body.add_child(_side_column)
	_built = true


func open() -> void:
	_rebuild()
	visible = true


func close() -> void:
	if not visible:
		return
	visible = false
	closed.emit()


func is_open() -> bool:
	return visible


func _fit() -> void:
	if _window == null:
		return
	var view := get_viewport_rect().size
	var m := float(config.window_margin) * 2.0
	_window.custom_minimum_size = Vector2(
		clampf(view.x - m, 320.0, float(config.window_max_width) + 40.0),
		clampf(view.y - m, 300.0, float(config.window_max_height) + 20.0)
	)


func browser_tips_shown() -> bool:
	if show_browser_tips != null:
		return bool(show_browser_tips)
	match config.browser_tips:
		&"on":
			return true
		&"off":
			return false
	return DotPlatform.is_web()


func _rebuild() -> void:
	if not _built:
		return
	var p := kit.palette

	# The hint is rebuilt with the rest: the help key may have been rebound since.
	var hint := _window.find_child("Hint", true, false) as HBoxContainer
	if hint != null:
		DotMenuKit.clear(hint)
		if help_action != &"" and bindings != null:
			hint.add_child(kit.keycap(bindings.key_for(help_action)))
			hint.add_child(kit.label("or", kit.size_small, p.dim))
		hint.add_child(kit.keycap("Esc"))
		hint.add_child(kit.label("to close", kit.size_small, p.dim))

	DotMenuKit.clear(_keys_column)
	DotMenuKit.clear(_side_column)

	# Keys, by group, as the player has them bound right now.
	var groups := bindings.groups() if bindings != null else PackedStringArray()
	for group in groups:
		var card := _card(_keys_column, group)
		for row in bindings.rows_in(group):
			_key_line(card, DotMenuBindings.shown(row), str(row["label"]))
		for line in (extra_keys.get(group, []) as Array):
			_key_line(card, str(line[0]), str(line[1]))
	for group in extra_keys:
		if not groups.has(str(group)):
			var card := _card(_keys_column, str(group))
			for line in (extra_keys[group] as Array):
				_key_line(card, str(line[0]), str(line[1]))

	for s in _sections:
		var card := _card(_side_column, str(s["title"]))
		for line in (s["lines"] as Array):
			match StringName(s["style"]):
				&"keys":
					_key_line(card, str(line[0]), str(line[1]))
				&"plain":
					_word_line(card, str(line[0]), str(line[1]), p.accent)
				_:
					_word_line(card, str(line[0]), str(line[1]), p.warn)

	if browser_tips_shown():
		var tips := _card(_side_column, "Playing in a browser")
		for tip in browser_tips(bindings):
			_word_line(tips, str(tip[0]), str(tip[1]), p.warn)

	_commands(_card(_side_column, "Chat commands"))


## What a browser does with keys, as `[[keys, sentence], ...]`. Static so a game can draw
## them somewhere else. Duck-aware: the Ctrl+W line warns specifically when Duck is on Ctrl,
## because then ducking while pressing forward IS that shortcut.
static func browser_tips(keys: DotMenuBindings) -> Array:
	var duck := keys.key_for(&"dot_fps_crouch") if keys != null else "—"
	var duck_row := keys.row_for_action(&"dot_fps_crouch") if keys != null else {}
	var duck_name := str(duck_row.get("label", "Duck"))
	return [
		["Esc", "Frees the mouse and opens the menu. Click the game, or Resume, to take the mouse back. The browser will not lock it again for about a second after Esc, so if a click does nothing, click once more."],
		["Ctrl + W", ("Closes the tab, and no web page can stop it. Careful: %s is on Ctrl, so pressing it while you press W is exactly that shortcut. Rebind it under Menu → Controls — Shift is free." % duck_name)
			if duck == "Ctrl" else "Closes the tab, and no web page can stop it. Mind it if you ever bind a key to Ctrl."],
		["Ctrl + T  ·  Ctrl + N", "Open a new tab or window and take the keyboard with them."],
		["Ctrl + Q  ·  Alt + F4", "Close the whole browser on some systems."],
		["Alt + ←", "Goes back a page in some browsers."],
		["F11", "The browser's own fullscreen. Fullscreen from Menu → Video instead also keeps Ctrl+W and the rest away from the game in browsers that support it; hold Esc to leave."],
		["Sound", "Starts after your first click. Browsers keep a page silent until you have touched it."],
		["Stutter", "Cap the frame rate or lower the render scale under Menu → Video."],
	]


func _commands(card: VBoxContainer) -> void:
	if not online:
		_note(card, "You are playing offline. Commands are the server's, so they work once you join one.")
		return
	if commands.is_empty():
		_note(card, "This server did not send its command list.")
		return
	var p := kit.palette
	for row in commands:
		var line := HBoxContainer.new()
		line.add_theme_constant_override(&"separation", 14)
		var name_label := kit.label(config.command_prefix + str(row[0]), kit.size_small + 1, p.accent, true)
		name_label.custom_minimum_size = Vector2(118, 0)
		line.add_child(name_label)
		line.add_child(kit.paragraph(str(row[1]) if row.size() > 1 else "", kit.size_small, p.muted))
		_line(card, line)


# --- Pieces -------------------------------------------------------------------

func _card(column: VBoxContainer, title: String) -> VBoxContainer:
	var head := MarginContainer.new()
	head.add_theme_constant_override(&"margin_left", 4)
	head.add_theme_constant_override(&"margin_top", 4)
	head.add_child(kit.section(title))
	column.add_child(head)

	var card := kit.card()
	column.add_child(card)

	var rows := VBoxContainer.new()
	rows.add_theme_constant_override(&"separation", 0)
	card.add_child(rows)
	return rows


func _key_line(card: VBoxContainer, key: String, what: String) -> void:
	var line := HBoxContainer.new()
	line.add_theme_constant_override(&"separation", 14)
	var cap_box := HBoxContainer.new()
	cap_box.custom_minimum_size = Vector2(72, 0)
	cap_box.add_child(kit.keycap(key))
	line.add_child(cap_box)
	var l := kit.label(what, kit.size_body - 1, kit.palette.text)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(l)
	_line(card, line)


func _word_line(card: VBoxContainer, key: String, text: String, colour: Color) -> void:
	var line := HBoxContainer.new()
	line.add_theme_constant_override(&"separation", 14)
	var k := kit.label(key, kit.size_small, colour, true)
	k.custom_minimum_size = Vector2(132, 0)
	line.add_child(k)
	line.add_child(kit.paragraph(text, kit.size_small, kit.palette.muted))
	_line(card, line)


func _note(card: VBoxContainer, text: String) -> void:
	_line(card, kit.paragraph(text))


func _line(card: VBoxContainer, content: Control) -> void:
	if card.get_child_count() > 0:
		card.add_child(HSeparator.new())
	var pad := MarginContainer.new()
	pad.add_theme_constant_override(&"margin_top", 7)
	pad.add_theme_constant_override(&"margin_bottom", 7)
	pad.add_child(content)
	card.add_child(pad)


func describe() -> Dictionary:
	return {
		"open": visible, "commands": commands.size(), "online": online,
		"sections": _sections.size(), "browser_tips": browser_tips_shown(),
	}
