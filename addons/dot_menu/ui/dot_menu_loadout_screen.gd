class_name DotMenuLoadoutScreen
extends Control

## The loadout screen: slots down the left, the slot's choices as cards with a picture, and the highlighted card's statistics against what is equipped. Example: docs/examples.md.
## A draft sent once when the screen closes (B, Escape, Done): per-click sends would hit a rate-limited server. It shows only what the server will take: fixed slots are locked, over-budget cards are dimmed.
## Mouse, keyboard (arrows, Enter, 1-9, Q/E, Tab, Backspace resets) and controller (`ui_*`); keys are read in [method _input]. Drawn at a design size and scaled down whole.

signal closed()

## The player closed the screen with changes: slot id to item id, the changed slots only.
signal committed(picks: Dictionary)

## The player pressed Random (the screen closes without its draft; the server rolls).
signal random_requested()
## The "random every spawn" toggle was switched to [param on]; the screen stays open.
signal random_spawn_requested(on: bool)

## A saved-loadout action (`save NAME`, `use N`, `rename N NAME`, `delete N`) for the server's /loadout.
signal manage_requested(args: String)

## Design size of the window. Scaled down, never up.
const DESIGN := Vector2(1160, 660)

## Cards a row.
const COLUMNS := 4

var kit: DotMenuKit = null
var _random_button: Button = null
var _spawn_toggle: Button = null

## The action that opened this (B), which also closes it.
var toggle_action: StringName = &""

## The offer it was opened with.
var offer: Dictionary = {}

## Slot id to item id: what closing will send.
var draft: Dictionary = {}
var _saved: DotMenuLoadoutSaved

## The slot shown (index into the offer's slots) and the card the keys are on.
var slot_index: int = 0
var card_index: int = 0

## The heading.
var title_text: String = "Loadout"

## A line under the heading; "" is the offer's note, else "Changes apply when you next spawn."
var subtitle: String = ""

var _frame: Control = null
var _window: PanelContainer = null
var _tabs: VBoxContainer = null
var _grid: GridContainer = null
var _detail: HBoxContainer = null
var _title: Label = null
var _sub: Label = null
var _points: Label = null
var _status: Label = null
var _keys: HBoxContainer = null
var _scroll: ScrollContainer = null
var _built := false
var _original: Dictionary = {}
var _hover := -1
var _status_text := ""


func _ready() -> void:
	if kit == null:
		kit = DotMenuKit.new()
	DotMenuKit.fill_parent(self)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_build()
	get_viewport().size_changed.connect(_fit)


func restyle(new_kit: DotMenuKit) -> void:
	kit = new_kit
	if not _built:
		return
	DotMenuKit.clear(self)
	_build()
	if visible:
		_rebuild()


## Random (when the server offers it) and Done, under the slot tabs.
func _side_buttons(side_col: VBoxContainer) -> void:
	_random_button = kit.secondary_button("Random")
	_random_button.name = "Random"
	_random_button.focus_mode = Control.FOCUS_NONE
	_random_button.pressed.connect(request_random)
	_random_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var row := HBoxContainer.new()
	row.name = "RandomRow"
	row.add_theme_constant_override(&"separation", 6)
	side_col.add_child(row)
	row.add_child(_random_button)
	_spawn_toggle = kit.secondary_button("Every spawn")
	_spawn_toggle.name = "RandomSpawn"
	_spawn_toggle.toggle_mode = true
	_spawn_toggle.focus_mode = Control.FOCUS_ALL
	_spawn_toggle.tooltip_text = "Roll a new random loadout every time you spawn"
	_spawn_toggle.toggled.connect(_on_spawn_toggled)
	row.add_child(_spawn_toggle)
	var done := kit.primary_button("Done")
	done.name = "Done"
	done.focus_mode = Control.FOCUS_NONE
	done.pressed.connect(close)
	side_col.add_child(done)


func _build() -> void:
	var p := kit.palette
	theme = kit.theme()
	add_child(kit.backdrop(1.1))

	_frame = Control.new()
	_frame.name = "Frame"
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.size = DESIGN
	add_child(_frame)

	_window = PanelContainer.new()
	_window.name = "Window"
	var s := kit.surface_box()
	s.content_margin_left = 0
	s.content_margin_right = 0
	s.content_margin_top = 0
	s.content_margin_bottom = 0
	_window.add_theme_stylebox_override(&"panel", s)
	_window.size = DESIGN
	_window.custom_minimum_size = DESIGN
	_frame.add_child(_window)

	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 0)
	_window.add_child(row)

	# The slots, on the sidebar colour, as the Escape menu's pages are.
	var side := PanelContainer.new()
	var ss := kit.box(p.sidebar, kit.radius + 4, Color(0, 0, 0, 0), 0, Vector4(18, 22, 18, 18))
	ss.corner_radius_top_right = 0
	ss.corner_radius_bottom_right = 0
	side.add_theme_stylebox_override(&"panel", ss)
	side.custom_minimum_size = Vector2(286, 0)
	row.add_child(side)
	var side_col := VBoxContainer.new()
	side_col.add_theme_constant_override(&"separation", 8)
	side.add_child(side_col)
	_title = kit.label(title_text, kit.size_title, p.text, true)
	side_col.add_child(_title)
	_points = kit.label("", kit.size_small, p.muted, true)
	_points.name = "Points"
	side_col.add_child(_points)
	side_col.add_child(DotMenuKit.gap(4))
	_tabs = VBoxContainer.new()
	_tabs.name = "Slots"
	_tabs.add_theme_constant_override(&"separation", 6)
	_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side_col.add_child(_tabs)
	_side_buttons(side_col)

	# The cards, the detail and the key line.
	var main := MarginContainer.new()
	main.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side_name in ["left", "right"]:
		main.add_theme_constant_override("margin_" + side_name, 24)
	main.add_theme_constant_override(&"margin_top", 22)
	main.add_theme_constant_override(&"margin_bottom", 16)
	row.add_child(main)
	var col := VBoxContainer.new()
	col.add_theme_constant_override(&"separation", 12)
	main.add_child(col)
	_sub = kit.paragraph("", kit.size_small, p.muted)
	_sub.name = "Subtitle"
	col.add_child(_sub)
	_saved = DotMenuLoadoutSaved.new()
	_saved.setup(kit)
	_saved.requested.connect(manage)
	col.add_child(_saved)

	var scroll := ScrollContainer.new()
	scroll.name = "Scroll"
	_scroll = scroll
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	_grid = GridContainer.new()
	_grid.name = "Cards"
	_grid.columns = COLUMNS
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.add_theme_constant_override(&"h_separation", 12)
	_grid.add_theme_constant_override(&"v_separation", 12)
	scroll.add_child(_grid)

	_build_foot(col)
	_built = true
	_fit()


## The detail card and the status and key line, under the cards.
func _build_foot(col: VBoxContainer) -> void:
	var p := kit.palette
	var detail_card := PanelContainer.new()
	detail_card.add_theme_stylebox_override(&"panel", kit.box(p.card, kit.radius, p.line, 1, Vector4(18, 14, 18, 14)))
	detail_card.custom_minimum_size = Vector2(0, 172)
	col.add_child(detail_card)
	_detail = HBoxContainer.new()
	_detail.name = "Detail"
	_detail.add_theme_constant_override(&"separation", 22)
	detail_card.add_child(_detail)

	var foot := HBoxContainer.new()
	foot.add_theme_constant_override(&"separation", 14)
	col.add_child(foot)
	_status = kit.label("", kit.size_small, p.warn, true)
	_status.name = "Status"
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Trimmed, never widening: a long refusal pushed the window past its design width and the
	# right-hand column off screen (rendered in game-arena).
	_status.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_status.custom_minimum_size = Vector2(1, 0)
	foot.add_child(_status)
	_keys = HBoxContainer.new()
	_keys.name = "Keys"
	foot.add_child(_keys)


## The key line, with the close key as it is bound now.
func _fill_keys(line: HBoxContainer) -> void:
	DotMenuKit.clear(line)
	line.add_theme_constant_override(&"separation", 6)
	var close_key := DotInputBinding.describe_action(toggle_action) if toggle_action != &"" and InputMap.has_action(toggle_action) else ""
	for pair: Array in [["↑↓←→", "choose"], ["Enter", "equip"], ["Q E", "slot"], ["Backspace", "undo"],
			["R", "random"], ["T", "every spawn"],
			[("%s / Esc" % close_key) if close_key != "" else "Esc", "done"]]:
		line.add_child(kit.keycap(str(pair[0]), kit.size_small - 2))
		line.add_child(kit.label(str(pair[1]), kit.size_small - 1, kit.palette.dim))


## Sized to the window: the design size, scaled down whole when the window is smaller.
func _fit() -> void:
	if _frame == null or not is_inside_tree():
		return
	var view := get_viewport_rect().size
	var room := view - Vector2(32, 32)
	var k := minf(1.0, minf(room.x / DESIGN.x, room.y / DESIGN.y))
	_frame.scale = Vector2(k, k)
	_frame.position = ((view - DESIGN * k) * 0.5).floor()


func open(p_offer: Dictionary) -> void:
	offer = p_offer
	draft.clear()
	for s: Variant in slots():
		var slot := s as Dictionary
		if str(slot.get("current", "")) != "":
			draft[str(slot["id"])] = str(slot["current"])
	_original = draft.duplicate()
	slot_index = clampi(slot_index, 0, maxi(0, slots().size() - 1))
	_focus_equipped()
	_status_text = ""
	_hover = -1
	visible = true
	_fit()
	_rebuild()


## Closes, and sends the changed slots if there are any and the player may choose.
func close() -> void:
	if not visible:
		return
	visible = false
	var changed := changes()
	if not changed.is_empty() and may_choose():
		committed.emit(changed)
	closed.emit()


## Whether the server offers Random to this player.
func random_offered() -> bool:
	var r: Variant = offer.get("random", {})
	return r is Dictionary and bool((r as Dictionary).get("enabled", false)) and may_choose()


## Whether the server lets this player roll a random loadout at every spawn (its rule is 1 or 2).
func random_spawn_offered() -> bool:
	return random_offered() and random_spawn_rule() > 0


## The server's `mp_loadout_random_on_spawn` for this player's class: 0 off, 1 their choice, 2 forced.
func random_spawn_rule() -> int:
	var r: Variant = offer.get("random", {})
	return int((r as Dictionary).get("spawn", 0)) if r is Dictionary else 0


## Whether random-every-spawn applies to this player now: forced by the server, or their toggle.
func random_spawn_on() -> bool:
	var r: Variant = offer.get("random", {})
	return random_spawn_rule() == 2 or (r is Dictionary and bool((r as Dictionary).get("spawn_on", false)))


## Flips the toggle (the T key, the right stick click, a click); a forced rule cannot be flipped.
func toggle_random_spawn() -> void:
	if visible and random_spawn_offered() and random_spawn_rule() == 1:
		_spawn_toggle.button_pressed = not _spawn_toggle.button_pressed


func _on_spawn_toggled(on: bool) -> void:
	var r: Variant = offer.get("random", {})
	if not (r is Dictionary) or random_spawn_rule() != 1 or on == bool((r as Dictionary).get("spawn_on", false)):
		return
	(r as Dictionary)["spawn_on"] = on
	_rebuild()
	random_spawn_requested.emit(on)


## Asks for a random loadout: closes without the draft and says so. Does nothing when not offered.
func request_random() -> void:
	if not visible or not random_offered():
		return
	random_requested.emit()
	cancel()


## Closes without sending anything.
## Sends a saved-loadout action and closes without the draft: the menu reopens on the answer.
## A save carries the draft, so the picks made so far are kept in the new loadout.
func manage(args: String) -> void:
	if not visible:
		return
	var line := args
	if args.begins_with("save"):
		for k: Variant in changes().keys():
			line += " %s=%s" % [k, changes()[k]]
	manage_requested.emit(line)
	cancel()


func cancel() -> void:
	draft = _original.duplicate()
	close()


func is_open() -> bool:
	return visible


## The slots that differ from what the screen opened with: slot id to item id.
func changes() -> Dictionary:
	var out: Dictionary = {}
	for k: Variant in draft.keys():
		if str(_original.get(k, "")) != str(draft[k]):
			out[k] = draft[k]
	return out


func slots() -> Array:
	return offer.get("slots", []) if offer.get("slots") is Array else []


func may_choose() -> bool:
	return bool(offer.get("choose", true))


func current_slot() -> Dictionary:
	var all := slots()
	return all[slot_index] if slot_index >= 0 and slot_index < all.size() else {}


func choices() -> Array:
	var s := current_slot()
	return s.get("choices", []) if s.get("choices") is Array else []


func slot_locked(slot: Dictionary) -> bool:
	return not may_choose() or bool(slot.get("fixed", false))


## Shows slot [param index] (wrapping), with the keys on its equipped card.
func show_slot(index: int) -> void:
	var n := slots().size()
	if n == 0:
		return
	slot_index = posmod(index, n)
	_focus_equipped()
	_hover = -1
	_status_text = ""
	_rebuild()


## Puts card [param index] of this slot in the draft. False, with a line saying why, when it
## cannot go there (a locked slot, over the budget).
func pick(index: int) -> bool:
	var list := choices()
	if index < 0 or index >= list.size():
		return false
	var slot := current_slot()
	var item := list[index] as Dictionary
	card_index = index
	if slot_locked(slot):
		_status_text = "The server sets this slot." if bool(slot.get("fixed", false)) else "The server sets every loadout here."
		_rebuild()
		return false
	var over := over_budget_by(str(slot["id"]), item)
	if over > 0:
		_status_text = "%s is %d point%s over the budget." % [
			item.get("name", item.get("id", "")), over, "" if over == 1 else "s"]
		_rebuild()
		return false
	draft[str(slot["id"])] = str(item["id"])
	_status_text = ""
	_rebuild()
	return true


## Whether cards show their cost: only when the server prices something (a budget, or a weapon with a cost).
func costs_shown() -> bool:
	return int(offer.get("budget", 0)) > 0 or bool(offer.get("priced", false))


## Points the draft would be over the budget with [param item] in [param slot_id]; 0 within it.
func over_budget_by(slot_id: String, item: Dictionary) -> int:
	var budget := int(offer.get("budget", 0))
	if budget <= 0:
		return 0
	return maxi(0, points_with(slot_id, item) - budget)


## The draft's points with [param item] in [param slot_id] (or as it is, with an empty item).
func points_with(slot_id: String = "", item: Dictionary = {}) -> int:
	var total := 0
	for s: Variant in slots():
		var slot := s as Dictionary
		var id := str(slot["id"])
		var held := str(item.get("id", "")) if id == slot_id and not item.is_empty() else str(draft.get(id, ""))
		total += _cost_of(slot, held)
	return total


static func _cost_of(slot: Dictionary, item_id: String) -> int:
	for c: Variant in slot.get("choices", []):
		if str((c as Dictionary).get("id", "")) == item_id:
			return int((c as Dictionary).get("cost", 0))
	return 0


func _focus_equipped() -> void:
	card_index = 0
	var held := str(draft.get(str(current_slot().get("id", "")), ""))
	var list := choices()
	for i in list.size():
		if str((list[i] as Dictionary).get("id", "")) == held:
			card_index = i
			return


func move(by: Vector2i) -> void:
	var n := choices().size()
	if n == 0:
		return
	var i := card_index + by.x + by.y * COLUMNS
	if by.y != 0 and (i < 0 or i >= n):
		return
	card_index = clampi(i, 0, n - 1)
	_hover = -1
	_rebuild()


func _input(event: InputEvent) -> void:
	if not visible or not is_visible_in_tree():
		return
	if handle_key(event):
		get_viewport().set_input_as_handled()


## One input event while open. True when it was the screen's. Public so a suite drives it.
func handle_key(event: InputEvent) -> bool:
	if event is InputEventMouse:
		return false
	if not event.is_pressed() or event.is_echo() and not _repeats(event):
		return event is InputEventKey or event is InputEventJoypadButton
	if toggle_action != &"" and InputMap.has_action(toggle_action) and event.is_action_pressed(toggle_action):
		close()
		return true
	if event is InputEventJoypadButton:
		match (event as InputEventJoypadButton).button_index:
			JOY_BUTTON_LEFT_SHOULDER:
				show_slot(slot_index - 1)
				return true
			JOY_BUTTON_RIGHT_SHOULDER:
				show_slot(slot_index + 1)
				return true
			JOY_BUTTON_Y:
				revert()
				return true
			JOY_BUTTON_X:
				request_random()
				return true
			JOY_BUTTON_RIGHT_STICK:
				toggle_random_spawn()
				return true
	if event is InputEventKey:
		var key := event as InputEventKey
		var code := key.physical_keycode if key.physical_keycode != KEY_NONE else key.keycode
		match code:
			KEY_ESCAPE:
				close()
				return true
			KEY_Q, KEY_PAGEUP:
				show_slot(slot_index - 1)
				return true
			KEY_E, KEY_PAGEDOWN:
				show_slot(slot_index + 1)
				return true
			KEY_TAB:
				show_slot(slot_index + (-1 if key.shift_pressed else 1))
				return true
			KEY_BACKSPACE:
				revert()
				return true
			KEY_R:
				request_random()
				return true
			KEY_T:
				toggle_random_spawn()
				return true
		if code >= KEY_1 and code <= KEY_9:
			var n := code - KEY_1
			if n < slots().size():
				show_slot(n)
			return true
	if event.is_action_pressed(&"ui_left"):
		move(Vector2i(-1, 0))
	elif event.is_action_pressed(&"ui_right"):
		move(Vector2i(1, 0))
	elif event.is_action_pressed(&"ui_up"):
		move(Vector2i(0, -1))
	elif event.is_action_pressed(&"ui_down"):
		move(Vector2i(0, 1))
	elif event.is_action_pressed(&"ui_accept"):
		var _picked := pick(card_index)
	elif event.is_action_pressed(&"ui_cancel"):
		close()
	return event is InputEventKey or event is InputEventJoypadButton


static func _repeats(event: InputEvent) -> bool:
	return event.is_action(&"ui_left") or event.is_action(&"ui_right") or event.is_action(&"ui_up") or event.is_action(&"ui_down")


## Puts the draft back as the screen opened.
func revert() -> void:
	draft = _original.duplicate()
	_status_text = "Back to what you had."
	_focus_equipped()
	_rebuild()


func _rebuild() -> void:
	if not _built:
		return
	var p := kit.palette
	_title.text = title_text
	if _random_button != null:
		_random_button.visible = random_offered()
		var price := str((offer.get("random", {}) as Dictionary).get("price", "")) if offer.get("random") is Dictionary else ""
		_random_button.text = "Random" if price == "" else "Random (%s)" % price
		_spawn_toggle.visible = random_spawn_offered()
		var forced := random_spawn_rule() == 2
		_spawn_toggle.set_pressed_no_signal(random_spawn_on())
		_spawn_toggle.disabled = forced
		_spawn_toggle.text = ("%s Every spawn" % ("☑" if random_spawn_on() else "☐")) if not forced else "Every spawn (server)"
	var note := subtitle if subtitle != "" else str(offer.get("note", ""))
	if note == "":
		note = "Pick a card for each slot. Changes are sent when you close this, and apply when you next spawn."
	_sub.text = note
	var budget := int(offer.get("budget", 0))
	_points.text = ("%d / %d points" % [points_with(), budget]) if budget > 0 else ""
	_points.visible = budget > 0
	_saved.visible = offer.get("saved") is Array and not (offer["saved"] as Array).is_empty() and may_choose()
	if _saved.visible:
		_saved.show_list(offer["saved"] as Array)
	_points.add_theme_color_override(&"font_color", p.danger if budget > 0 and points_with() > budget else p.muted)
	_status.text = _status_text
	_fill_keys(_keys)
	_status.add_theme_color_override(&"font_color", p.warn)

	DotMenuKit.clear(_tabs)
	var all := slots()
	for i in all.size():
		_tabs.add_child(_tab(i, all[i] as Dictionary))

	DotMenuKit.clear(_grid)
	var list := choices()
	if list.is_empty():
		_grid.add_child(kit.paragraph("Nothing can go in this slot here."))
	for i in list.size():
		_grid.add_child(_card(i, list[i] as Dictionary))
	# The card the keys are on stays in view (a pick by arrow keys on the third row was
	# described below while the card itself was scrolled away).
	if _hover < 0 and card_index >= 0 and card_index < _grid.get_child_count():
		_scroll_to.call_deferred(_grid.get_child(card_index))

	_draw_detail()


func _tab(index: int, slot: Dictionary) -> Control:
	var p := kit.palette
	var on := index == slot_index
	var b := Button.new()
	b.name = "Slot%d" % (index + 1)
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 64)
	var none := Color(0, 0, 0, 0)
	var normal := kit.box(p.accent_wash() if on else p.card, kit.radius_small, p.accent if on else p.line, 1)
	if on:
		normal.border_width_left = 4
	b.add_theme_stylebox_override(&"normal", normal)
	b.add_theme_stylebox_override(&"hover", kit.box(p.card_hover if not on else p.accent_wash(), kit.radius_small, p.accent if on else Color(p.text, 0.14), 1))
	b.add_theme_stylebox_override(&"pressed", normal)
	b.add_theme_stylebox_override(&"focus", kit.box(none, kit.radius_small, none, 0))
	b.pressed.connect(func() -> void: show_slot(index))

	var line := HBoxContainer.new()
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_theme_constant_override(&"separation", 10)
	DotMenuKit.fill_parent(line)
	line.offset_left = 10
	line.offset_right = -10
	b.add_child(line)
	var cap := kit.keycap(str(index + 1), kit.size_small - 2)
	cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(cap)
	var held_id := str(draft.get(str(slot.get("id", "")), ""))
	var held := _choice(slot, held_id)
	line.add_child(_icon_box(held, Vector2(64, 40), false))
	var words := VBoxContainer.new()
	words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.add_theme_constant_override(&"separation", 0)
	line.add_child(words)
	var head := str(slot.get("name", slot.get("id", ""))).to_upper()
	if bool(slot.get("fixed", false)):
		head += "  ·  SERVER"
	var h := kit.label(head, kit.size_small - 2, p.accent if on else p.dim, true)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	words.add_child(h)
	var name := kit.label(str(held.get("name", "Empty")) if not held.is_empty() else "Empty", kit.size_body, p.text if not held.is_empty() else p.dim, true)
	name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name.custom_minimum_size = Vector2(1, 0)
	words.add_child(name)
	if held_id != str(_original.get(str(slot.get("id", "")), "")):
		var dot := kit.label("●", kit.size_small, p.warn)
		dot.tooltip_text = "Changed: sent when you close"
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		line.add_child(dot)
	return b


static func _choice(slot: Dictionary, item_id: String) -> Dictionary:
	for c: Variant in slot.get("choices", []):
		if str((c as Dictionary).get("id", "")) == item_id:
			return c as Dictionary
	return {} if item_id == "" else {"id": item_id, "name": item_id.capitalize()}


func _card(index: int, item: Dictionary) -> Control:
	var p := kit.palette
	var slot := current_slot()
	var slot_id := str(slot.get("id", ""))
	var equipped := str(draft.get(slot_id, "")) == str(item.get("id", ""))
	var focused := index == card_index or index == _hover
	var locked := slot_locked(slot)
	var over := over_budget_by(slot_id, item) if not equipped else 0

	var b := Button.new()
	b.name = "Card%d" % (index + 1)
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(196, 150)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var border := p.accent if equipped else (Color(p.text, 0.35) if focused else p.line)
	var fill := p.accent_wash() if equipped else (p.card_hover if focused else p.card)
	var st := kit.box(fill, kit.radius, border, 2 if (equipped or focused) else 1)
	b.add_theme_stylebox_override(&"normal", st)
	b.add_theme_stylebox_override(&"hover", st)
	b.add_theme_stylebox_override(&"pressed", st)
	b.add_theme_stylebox_override(&"focus", kit.box(Color(0, 0, 0, 0), kit.radius))
	b.mouse_entered.connect(func() -> void:
		if _hover != index:
			_hover = index
			card_index = index
			_rebuild())
	b.pressed.connect(func() -> void: var _p := pick(index))
	b.modulate = Color(1, 1, 1, 0.45) if (over > 0 or (locked and not equipped)) else Color.WHITE

	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override(&"separation", 4)
	DotMenuKit.fill_parent(col)
	col.offset_left = 12
	col.offset_right = -12
	col.offset_top = 10
	col.offset_bottom = -10
	b.add_child(col)
	var pic := _icon_box(item, Vector2(0, 82), true)
	pic.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(pic)
	var line := HBoxContainer.new()
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(line)
	var name := kit.label(str(item.get("name", item.get("id", ""))), kit.size_body, p.text, true)
	name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name.custom_minimum_size = Vector2(1, 0)
	line.add_child(name)
	if costs_shown() and int(item.get("cost", 0)) > 0:
		var cost := kit.label("%d pt" % int(item.get("cost", 0)), kit.size_small - 1, p.muted, true)
		cost.mouse_filter = Control.MOUSE_FILTER_IGNORE
		line.add_child(cost)
	var under := ""
	var under_colour := p.dim
	if equipped:
		under = "EQUIPPED"
		under_colour = p.accent
	elif over > 0:
		under = "%d over budget" % over
		under_colour = p.danger
	elif locked:
		under = "set by the server"
	else:
		under = "  ·  ".join(_shown_tags(item, 3))
	var u := kit.label(under, kit.size_small - 2, under_colour, equipped)
	u.mouse_filter = Control.MOUSE_FILTER_IGNORE
	u.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	u.custom_minimum_size = Vector2(1, 0)
	col.add_child(u)
	return b


func _scroll_to(card: Control) -> void:
	if _scroll != null and is_instance_valid(card) and card.is_inside_tree():
		_scroll.ensure_control_visible(card)


## The tags worth showing: not the slot's own name or the kind, which the card already says.
func _shown_tags(item: Dictionary, limit: int) -> PackedStringArray:
	var slot := current_slot()
	var said := [str(slot.get("id", "")).to_lower(), str(slot.get("name", "")).to_lower(), str(item.get("kind", "")).to_lower()]
	var out := PackedStringArray()
	for t: Variant in item.get("tags", []):
		var tag := str(t)
		if out.size() < limit and not said.has(tag.to_lower()):
			out.append(tag)
	return out


## A picture frame: the item's icon, or its initials when it has none (an empty box reads as
## broken art).
func _icon_box(item: Dictionary, min_size: Vector2, framed: bool) -> Control:
	var p := kit.palette
	var frame := PanelContainer.new()
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.custom_minimum_size = min_size
	frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	# A dark display case in every theme: a game's weapon art is usually light on transparent,
	# and on the paper theme's light card it disappears (rendered).
	var case := Color(0.07, 0.08, 0.11, 0.92 if p.is_light() else 0.45)
	frame.add_theme_stylebox_override(&"panel", kit.box(case if framed or p.is_light() else Color(0, 0, 0, 0), kit.radius_small, Color(0, 0, 0, 0), 0, Vector4(6, 4, 6, 4)))
	var tex := DotMenuPicker.thumbnail_texture(item.get("icon"))
	if tex != null:
		var pic := TextureRect.new()
		pic.texture = tex
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		frame.add_child(pic)
	elif not item.is_empty():
		var words := str(item.get("name", item.get("id", "?"))).split(" ", false)
		var initials := ""
		for w in words:
			if initials.length() < 2:
				initials += w.substr(0, 1).to_upper()
		var l := kit.label(initials, kit.size_heading if framed else kit.size_small, p.dim, true)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		frame.add_child(l)
	return frame


## The highlighted card: a big picture, its name and line, and each statistic as a bar with what
## is equipped now drawn behind it, so "better or worse than what I have" is one glance.
func _draw_detail() -> void:
	DotMenuKit.clear(_detail)
	var p := kit.palette
	var list := choices()
	if list.is_empty():
		return
	var item := list[clampi(card_index, 0, list.size() - 1)] as Dictionary
	var slot := current_slot()
	var held := _choice(slot, str(draft.get(str(slot.get("id", "")), "")))

	var pic := _icon_box(item, Vector2(250, 140), true)
	_detail.add_child(pic)

	var words := VBoxContainer.new()
	words.custom_minimum_size = Vector2(230, 0)
	words.add_theme_constant_override(&"separation", 4)
	_detail.add_child(words)
	words.add_child(kit.label(str(item.get("name", item.get("id", ""))), kit.size_heading + 2, p.text, true))
	var kind := str(item.get("kind", slot.get("name", "")))
	if kind != "":
		words.add_child(kit.section(kind))
	var detail := str(item.get("detail", ""))
	if detail != "":
		words.add_child(kit.paragraph(detail, kit.size_small, p.muted))
	var tags := _shown_tags(item, 8)
	if not tags.is_empty():
		words.add_child(kit.label("  ·  ".join(tags), kit.size_small - 1, p.dim))

	var bars := VBoxContainer.new()
	bars.name = "Stats"
	bars.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bars.alignment = BoxContainer.ALIGNMENT_CENTER
	bars.add_theme_constant_override(&"separation", 7)
	_detail.add_child(bars)
	var held_stats := {}
	for st: Variant in held.get("stats", []):
		held_stats[str((st as Dictionary).get("label", ""))] = float((st as Dictionary).get("value", 0.0))
	for st: Variant in item.get("stats", []):
		var stat := st as Dictionary
		var label := str(stat.get("label", ""))
		bars.add_child(DotMenuStatBar.build(kit, label, clampf(float(stat.get("value", 0.0)), 0.0, 1.0),
			str(stat.get("text", "")), float(held_stats.get(label, -1.0)), str(held.get("id", "")) == str(item.get("id", ""))))


func describe() -> Dictionary:
	return {"open": visible, "slot": str(current_slot().get("id", "")), "card": card_index,
		"draft": draft.duplicate(), "changes": changes(), "points": points_with(),
		"budget": int(offer.get("budget", 0)), "status": _status_text}
