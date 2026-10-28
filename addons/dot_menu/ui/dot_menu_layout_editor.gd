class_name DotMenuLayoutEditor
extends Control

## Moving the HUD: every piece a player can place is drawn with a frame round it and dragged where they want it. Right-click puts one back. Example: docs/examples.md.
## What is stored is each piece's CENTRE as a fraction of the window ([method encode]), so a layout lands in the same place on a 4K screen.
## The target is duck-typed: `element_rect(id) -> Rect2`, `move_element(id, centre)`, `reset_element(id)`, and a `positions` dictionary of `id -> Vector2`.

signal closed()

## The layout as a setting stores it, after a drag or a reset. See [method encode].
signal saved(text: String)

var kit: DotMenuKit = null

## The HUD being arranged. See the class note.
var target: Control = null

## `{id: label}`, the pieces that can be moved, in drawing order.
var pieces: Dictionary = {}

var title_text: String = "Move the HUD"
var instructions: String = "Drag a piece to move it. Right-click one to put it back."

var _dragging: StringName = &""
var _grab_offset := Vector2.ZERO
var _hover: StringName = &""
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


func _build() -> void:
	var p := kit.palette
	theme = kit.theme()

	var bar := PanelContainer.new()
	bar.name = "Bar"
	bar.add_theme_stylebox_override(&"panel", kit.surface_box())
	bar.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	bar.offset_top = 90.0
	bar.grow_horizontal = Control.GROW_DIRECTION_BOTH
	add_child(bar)

	var pad := MarginContainer.new()
	for side in [&"margin_left", &"margin_right"]:
		pad.add_theme_constant_override(side, 18)
	for side in [&"margin_top", &"margin_bottom"]:
		pad.add_theme_constant_override(side, 12)
	bar.add_child(pad)

	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 14)
	pad.add_child(row)

	var words := VBoxContainer.new()
	words.add_theme_constant_override(&"separation", 2)
	words.add_child(kit.label(title_text, kit.size_heading, p.text, true))
	words.add_child(kit.label(instructions, kit.size_small, p.muted))
	row.add_child(words)

	var reset := Button.new()
	reset.name = "ResetAll"
	reset.text = "Reset all"
	reset.pressed.connect(reset_all)
	row.add_child(reset)

	var done := Button.new()
	done.name = "Done"
	done.text = "Done"
	done.pressed.connect(close)
	row.add_child(done)
	_built = true


func open() -> void:
	visible = true
	_dragging = &""
	queue_redraw()


func close() -> void:
	if not visible:
		return
	visible = false
	_dragging = &""
	closed.emit()


func is_open() -> bool:
	return visible


## Every piece back where the layout puts it.
func reset_all() -> void:
	if target == null:
		return
	for id in pieces:
		target.call("reset_element", id)
	_save()


## The piece under [param at] (target coordinates), or empty. The smallest wins, so a small
## piece sitting just under a big one can still be picked up.
func piece_at(at: Vector2) -> StringName:
	if target == null:
		return &""
	var best := &""
	var best_area := INF
	for id in pieces:
		var rect: Rect2 = (target.call("element_rect", id) as Rect2).grow(6.0)
		if rect.has_point(at) and rect.get_area() < best_area:
			best = id
			best_area = rect.get_area()
	return best


## Drags [param id] so the point grabbed at [param from] ends under [param to]. Public so a
## suite can drive a drag without a mouse.
func drag(id: StringName, from: Vector2, to: Vector2) -> void:
	if target == null or id == &"":
		return
	var rect: Rect2 = target.call("element_rect", id)
	var offset := rect.get_center() - from
	target.call("move_element", id, to + offset)
	_save()
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if target == null:
		return

	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.button_index == MOUSE_BUTTON_LEFT:
			if button.pressed:
				_dragging = piece_at(button.position)
				if _dragging != &"":
					var rect: Rect2 = target.call("element_rect", _dragging)
					_grab_offset = rect.get_center() - button.position
			elif _dragging != &"":
				_dragging = &""
				_save()
			accept_event()
		elif button.button_index == MOUSE_BUTTON_RIGHT and button.pressed:
			var id := piece_at(button.position)
			if id != &"":
				target.call("reset_element", id)
				_save()
			accept_event()
		queue_redraw()
	elif event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		if _dragging != &"":
			target.call("move_element", _dragging, motion.position + _grab_offset)
			accept_event()
		_hover = piece_at(motion.position)
		queue_redraw()


func _process(_delta: float) -> void:
	if visible:
		# The pieces change size as they draw (a clock's block, a list), so the frames follow
		# them every frame rather than only on a drag.
		queue_redraw()


func _draw() -> void:
	if target == null:
		return
	# A wash over the game, lighter than the menu's: the point is to see the HUD on it.
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.18))
	var font := get_theme_default_font()
	var moved_ids: Dictionary = target.get("positions") if "positions" in target else {}
	for id in pieces:
		var rect: Rect2 = target.call("element_rect", id)
		if rect.size == Vector2.ZERO:
			continue
		var live: bool = id == _dragging or id == _hover
		var edge := kit.palette.accent if live else Color(1, 1, 1, 0.75)
		draw_rect(rect.grow(4.0), Color(edge, 0.12 if live else 0.06), true)
		draw_rect(rect.grow(4.0), edge, false, 2.0)
		if font != null:
			var tag := "%s%s" % [str(pieces[id]), "  (moved)" if moved_ids.has(id) else ""]
			# Beside the frame rather than over it: pieces sit close, and a tag above one is
			# drawn on the other.
			var width := font.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
			var at := Vector2(rect.end.x + 12.0, rect.position.y + 16.0)
			if at.x + width > size.x - 4.0:
				at.x = rect.position.x - width - 12.0
			draw_string_outline(font, at, tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, 4, Color(0, 0, 0, 0.8))
			draw_string(font, at, tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, edge)


func _save() -> void:
	if target == null:
		return
	var moved: Dictionary = target.get("positions") if "positions" in target else {}
	saved.emit(encode(moved))


## Positions as a setting stores them: JSON of `{"timer": [0.5, 0.82], ...}`. Empty for none.
static func encode(value: Dictionary) -> String:
	if value.is_empty():
		return ""
	var out := {}
	for id: Variant in value:
		var at := value[id] as Vector2
		out[String(id)] = [snappedf(at.x, 0.0001), snappedf(at.y, 0.0001)]
	return JSON.stringify(out)


## [method encode]'s text back into `{id: Vector2}`, keeping only ids in [param known].
## Anything that is not a known piece with two finite numbers is dropped and each number is held to 0..1:
## the setting is hand-editable, and an off-screen piece cannot be found to drag back.
static func decode(text: String, known: Array = []) -> Dictionary:
	var out := {}
	if text.strip_edges() == "":
		return out
	var json := JSON.new()
	if json.parse(text) != OK or not (json.data is Dictionary):
		return out
	for key: Variant in (json.data as Dictionary):
		var id := StringName(str(key))
		var at: Variant = (json.data as Dictionary)[key]
		if (not known.is_empty() and not known.has(id)) or not (at is Array) or (at as Array).size() != 2:
			continue
		var x := float((at as Array)[0])
		var y := float((at as Array)[1])
		if is_finite(x) and is_finite(y):
			out[id] = Vector2(clampf(x, 0.0, 1.0), clampf(y, 0.0, 1.0))
	return out


func describe() -> Dictionary:
	return {"open": visible, "pieces": pieces.size(), "target": target != null}
