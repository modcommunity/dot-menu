class_name DotMenuTeamScreen
extends Control

## The team menu: one card per team (a row or a grid, whatever the server lists), then Spectate. Free-for-all lists only Play and Spectate.
## Keys: 1-9 or click pick, arrows/D-pad move, Enter/Space/A choose, Esc/B or the toggle key closes. Cards are built from the server's data, see [method open].

signal closed()
## The player chose [param id]: a team id as text, `play` or `spectate`.
signal chosen(id: String)

const MAX_COLUMNS := 4

## Asks the server again, every [member refresh_sec] while open, so the counts stay live.
signal refresh_requested()

var kit: DotMenuKit = null
## The action that opened this, so the same key closes it.
var toggle_action: StringName = &""
var title_text: String = "Choose your team"

## `{id, name, colour, count, max, closed, current, kind}` per card, in order.
var entries: Array = []
var focus: int = 0
var last_data: Dictionary = {}
var last_result: String = ""
var refresh_sec: float = 0.0

var _since_refresh := 0.0

var _window: PanelContainer = null
var _title: Label = null
var _note: Label = null
var _grid: GridContainer = null
var _footer: Label = null
var _built := false


func _ready() -> void:
	if kit == null:
		kit = DotMenuKit.new()
	DotMenuKit.fill_parent(self)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_build()


func restyle(new_kit: DotMenuKit) -> void:
	kit = new_kit
	if not _built:
		return
	DotMenuKit.clear(self)
	_build()
	if visible:
		_rebuild()


func _build() -> void:
	var p := kit.palette
	theme = kit.theme()
	var back := ColorRect.new()
	back.color = Color(p.backdrop, 0.6)
	DotMenuKit.fill_parent(back)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(back)
	var centre := CenterContainer.new()
	DotMenuKit.fill_parent(centre)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(centre)
	_window = PanelContainer.new()
	var s := kit.surface_box()
	s.content_margin_left = 28
	s.content_margin_right = 28
	s.content_margin_top = 22
	s.content_margin_bottom = 18
	_window.add_theme_stylebox_override(&"panel", s)
	centre.add_child(_window)
	var col := VBoxContainer.new()
	col.add_theme_constant_override(&"separation", 10)
	_window.add_child(col)
	_title = kit.label(title_text, kit.size_title, p.text, true)
	col.add_child(_title)
	_note = kit.paragraph("")
	col.add_child(_note)
	_grid = GridContainer.new()
	_grid.name = "Cards"
	_grid.add_theme_constant_override(&"h_separation", 12)
	_grid.add_theme_constant_override(&"v_separation", 12)
	col.add_child(_grid)
	_footer = kit.label("", kit.size_small, p.dim)
	col.add_child(_footer)
	_built = true


## Opens on the server's answer: `{teams: [{id, name, colour, count, max, closed, current}], ffa, spectating, spectate_ok, enabled, wait}`.
func open(data: Dictionary) -> void:
	var fresh := not visible
	entries = entries_for(data)
	last_data = data.duplicate(true)
	if fresh:
		focus = 0
		for i in entries.size():
			if bool((entries[i] as Dictionary).get("current", false)):
				focus = i
	focus = clampi(focus, 0, maxi(entries.size() - 1, 0))
	_rebuild()
	visible = true


## The same data again while open (live counts): cards redraw, the focus stays.
func refresh(data: Dictionary) -> void:
	if visible:
		open(data)


func close() -> void:
	if not visible:
		return
	visible = false
	closed.emit()


func is_open() -> bool:
	return visible


## Cards for [param data]. Spectate is always last and always there unless the server turned it off.
static func entries_for(data: Dictionary) -> Array:
	var out: Array = []
	var spectating := bool(data.get("spectating", false))
	if bool(data.get("ffa", false)):
		out.append({"id": "play", "name": "Play", "kind": "play", "colour": "", "count": -1, "max": 0,
			"closed": "You are already playing." if not spectating else "", "current": not spectating})
	else:
		for t: Variant in data.get("teams", []):
			var row := t as Dictionary
			out.append({"id": str(int(row.get("id", 0))), "name": str(row.get("name", "Team")), "kind": "team",
				"colour": str(row.get("colour", "")), "count": int(row.get("count", 0)), "max": int(row.get("max", 0)),
				"closed": str(row.get("closed", "")), "current": bool(row.get("current", false))})
	if bool(data.get("spectate_ok", true)):
		out.append({"id": "spectate", "name": "Spectate", "kind": "spectate", "colour": "", "count": -1, "max": 0,
			"closed": "You are already spectating." if spectating else "", "current": spectating})
	return out


func columns_for(n: int) -> int:
	return clampi(n, 1, MAX_COLUMNS) if n <= MAX_COLUMNS else ceili(n / 2.0)


## Card [param index] (0-based) picked. A closed card says why instead of asking the server.
func pick(index: int) -> bool:
	if index < 0 or index >= entries.size():
		return false
	var e := entries[index] as Dictionary
	if str(e["closed"]) != "" and not bool(e["current"]):
		last_result = str(e["closed"])
		_rebuild()
		return true
	if bool(e["current"]):
		close()
		return true
	focus = index
	chosen.emit(str(e["id"]))
	return true


func move(by: int) -> void:
	if entries.is_empty():
		return
	focus = posmod(focus + by, entries.size())
	_rebuild()


## One input event while open. True when it was the screen's. Public so a suite drives it.
func handle_key(event: InputEvent) -> bool:
	if event is InputEventMouse:
		return false
	if not event.is_pressed() or (event.is_echo()):
		return event is InputEventKey or event is InputEventJoypadButton
	if toggle_action != &"" and InputMap.has_action(toggle_action) and event.is_action_pressed(toggle_action):
		close()
		return true
	if event is InputEventJoypadButton:
		match (event as InputEventJoypadButton).button_index:
			JOY_BUTTON_DPAD_LEFT:
				move(-1)
			JOY_BUTTON_DPAD_RIGHT:
				move(1)
			JOY_BUTTON_DPAD_UP:
				move(-columns_for(entries.size()))
			JOY_BUTTON_DPAD_DOWN:
				move(columns_for(entries.size()))
			JOY_BUTTON_A:
				var _a := pick(focus)
			JOY_BUTTON_B:
				close()
		return true
	if event is InputEventKey:
		var key := event as InputEventKey
		var code := key.physical_keycode if key.physical_keycode != KEY_NONE else key.keycode
		match code:
			KEY_ESCAPE:
				close()
			KEY_LEFT, KEY_A:
				move(-1)
			KEY_RIGHT, KEY_D:
				move(1)
			KEY_UP, KEY_W:
				move(-columns_for(entries.size()))
			KEY_DOWN, KEY_S:
				move(columns_for(entries.size()))
			KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
				var _e := pick(focus)
			_:
				var digit := -1
				if code >= KEY_1 and code <= KEY_9:
					digit = code - KEY_1
				elif code >= KEY_KP_1 and code <= KEY_KP_9:
					digit = code - KEY_KP_1
				if digit >= 0:
					var _d := pick(digit)
		return true
	return true


func _process(delta: float) -> void:
	if not visible or refresh_sec <= 0.0:
		return
	_since_refresh += delta
	if _since_refresh >= refresh_sec:
		_since_refresh = 0.0
		refresh_requested.emit()


func _input(event: InputEvent) -> void:
	if visible and is_visible_in_tree() and handle_key(event):
		get_viewport().set_input_as_handled()


func _rebuild() -> void:
	if _grid == null:
		return
	DotMenuKit.clear(_grid)
	_title.text = title_text
	var ffa := bool(last_data.get("ffa", false))
	var wait := float(last_data.get("wait", 0.0))
	var note := "Free for all: play, or watch." if ffa else "Pick a side. The numbers are live."
	if not bool(last_data.get("enabled", true)):
		note = "Team switching is off on this server."
	elif wait > 0.0:
		note = "You can switch again in %d s." % ceili(wait)
	_note.text = note
	_grid.columns = columns_for(entries.size())
	for i in entries.size():
		_grid.add_child(_card(i, entries[i] as Dictionary))
	var keys := "1-%d or click  ·  arrows and Enter  ·  " % mini(entries.size(), 9)
	var toggle := DotInputBinding.describe_action(toggle_action) if toggle_action != &"" and InputMap.has_action(toggle_action) else ""
	_footer.text = keys + ((toggle + " or Esc closes") if toggle != "" else "Esc closes") + \
		(("   " + last_result) if last_result != "" else "")


func _card(index: int, e: Dictionary) -> Control:
	var p := kit.palette
	var shade := Color(str(e["colour"])) if str(e["colour"]) != "" else (p.accent if e["kind"] == "play" else p.muted)
	var closed_reason := str(e["closed"])
	var dead := closed_reason != "" and not bool(e["current"])
	var focused := index == focus
	var button := Button.new()
	button.name = "Card%d" % (index + 1)
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(190, 150)
	var edge := shade if focused or bool(e["current"]) else p.line
	var width := 3 if focused else (2 if bool(e["current"]) else 1)
	var fill := Color(shade, 0.16 if not dead else 0.05) if bool(e["current"]) or focused else p.card
	for state in [&"normal", &"hover", &"pressed", &"focus"]:
		var f := fill.lightened(0.06) if state == &"hover" else fill
		button.add_theme_stylebox_override(state, kit.box(f, kit.radius, edge, width, Vector4(0, 0, 0, 0)))
	button.pressed.connect(func() -> void: var _p := pick(index))
	button.mouse_entered.connect(func() -> void:
		if focus != index:
			focus = index
			_rebuild())

	var col := VBoxContainer.new()
	col.add_theme_constant_override(&"separation", 4)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	DotMenuKit.fill_parent(col)
	col.offset_left = 14
	col.offset_right = -14
	col.offset_top = 12
	col.offset_bottom = -12
	button.add_child(col)

	var top := HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(top)
	var cap := kit.keycap(str(index + 1))
	cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(cap)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(spacer)
	var swatch := ColorRect.new()
	swatch.name = "Swatch"
	swatch.color = shade
	swatch.custom_minimum_size = Vector2(26, 26)
	swatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(swatch)

	var name := kit.label(str(e["name"]), kit.size_title, p.dim if dead else p.text, true)
	name.name = "Name"
	name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	col.add_child(name)

	var count_text := ""
	if int(e["count"]) >= 0:
		count_text = "%d / %d players" % [e["count"], e["max"]] if int(e["max"]) > 0 else "%d player%s" % [e["count"], "" if int(e["count"]) == 1 else "s"]
	elif e["kind"] == "spectate":
		count_text = "Watch the match"
	else:
		count_text = "Join the match"
	var count := kit.label(count_text, kit.size_body, p.muted)
	count.name = "Count"
	count.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(count)

	var status := ""
	if bool(e["current"]):
		status = "You are here"
	elif dead:
		status = closed_reason
	var tag := kit.label(status, kit.size_small, p.accent if bool(e["current"]) else p.warn)
	tag.name = "Status"
	tag.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(tag)
	return button


func describe() -> Dictionary:
	return {"open": visible, "cards": entries.size(), "focus": focus, "columns": columns_for(entries.size()),
		"ffa": bool(last_data.get("ffa", false)), "last_result": last_result}
