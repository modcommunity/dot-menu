class_name DotMenuPicker
extends Control

## A numbered list to pick one thing from, a page at a time: maps, a team, a class, a vote.
##
## [codeblock]
## picker.title_text = "Change map — this server"
## picker.open([{"id": "surf_intro", "name": "Surf Intro", "tags": ["tier 1"], "current": true}])
## picker.chosen.connect(func(id): change_map(id))
## # in the host's input handler, while it is open:
## if picker.key(event.keycode): get_viewport().set_input_as_handled()
## [/codeblock]
##
## [b]The number keys are the community-server menu keys[/b], because that is what the
## players these games are for already have in their fingers: 1-7 pick a row, 8 is the
## previous page, 9 the next, 0 closes. The mouse works as well, and a row says its number,
## so the two never disagree. Seven rows a page is what keeps 8 and 9 free for turning.
##
## An item is `{id, name, tags, current, warn}`: `tags` is a list of short words drawn on the
## right, `current` lights the row in the accent (and opens on its page, so "what is on now"
## is the first thing seen), `warn` draws the tags in the warning colour.

signal closed()

## The player picked [param id].
signal chosen(id: StringName)

## Rows per page. Seven, so 8 and 9 stay the page keys.
const PAGE_SIZE := 7

var kit: DotMenuKit = null

var items: Array = []
var page: int = 0

var title_text: String = "Choose"
var instructions: String = "1–7 or click to choose. 8 and 9 turn the page. 0 or Esc closes."

## Shown when there is nothing to pick.
var empty_text: String = "Nothing to choose from."

## `func(items: Array) -> String`, added to the footer after the page count ("3 not in
## rotation").
var footer_extra: Callable = Callable()

## The word for one item in the footer ("maps").
var noun: String = "items"

var _window: PanelContainer = null
var _rows: VBoxContainer = null
var _title: Label = null
var _instructions: Label = null
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
	back.color = Color(p.backdrop, 0.55)
	DotMenuKit.fill_parent(back)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(back)

	var centre := CenterContainer.new()
	DotMenuKit.fill_parent(centre)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(centre)

	_window = PanelContainer.new()
	var s := kit.surface_box()
	s.content_margin_left = 26
	s.content_margin_right = 26
	s.content_margin_top = 20
	s.content_margin_bottom = 18
	_window.add_theme_stylebox_override(&"panel", s)
	_window.custom_minimum_size = Vector2(560, 0)
	centre.add_child(_window)

	var col := VBoxContainer.new()
	col.add_theme_constant_override(&"separation", 6)
	_window.add_child(col)

	_title = kit.label(title_text, kit.size_title, p.text, true)
	col.add_child(_title)
	# Kept, and set again on every draw: a game sets its own words after the picker is built.
	_instructions = kit.paragraph(instructions)
	col.add_child(_instructions)

	_rows = VBoxContainer.new()
	_rows.name = "Rows"
	_rows.add_theme_constant_override(&"separation", 4)
	col.add_child(_rows)

	_footer = kit.label("", kit.size_small, p.dim)
	col.add_child(_footer)
	_built = true


func open(list: Array, title: String = "") -> void:
	items = list
	if title != "":
		title_text = title
	page = 0
	for i in items.size():
		if items[i] is Dictionary and bool((items[i] as Dictionary).get("current", false)):
			page = i / PAGE_SIZE
			break
	_rebuild()
	visible = true


func close() -> void:
	if not visible:
		return
	visible = false
	closed.emit()


func is_open() -> bool:
	return visible


func pages() -> int:
	return maxi(1, ceili(float(items.size()) / float(PAGE_SIZE)))


func turn(by: int) -> void:
	page = clampi(page + by, 0, pages() - 1)
	_rebuild()


## The item on row [param row] (1-based) of this page, or null.
func at_row(row: int) -> Variant:
	var i := page * PAGE_SIZE + row - 1
	if row < 1 or row > PAGE_SIZE or i < 0 or i >= items.size():
		return null
	return items[i]


func pick(row: int) -> bool:
	var it: Variant = at_row(row)
	if it == null:
		return false
	chosen.emit(StringName(str((it as Dictionary).get("id", ""))))
	close()
	return true


## A number key, from the host's input handler. True when the key was the picker's.
func key(keycode: Key) -> bool:
	var digit := -1
	if keycode >= KEY_0 and keycode <= KEY_9:
		digit = keycode - KEY_0
	elif keycode >= KEY_KP_0 and keycode <= KEY_KP_9:
		digit = keycode - KEY_KP_0
	match digit:
		-1:
			return false
		0:
			close()
		8:
			turn(-1)
		9:
			turn(1)
		_:
			var _picked := pick(digit)
	return true


func _rebuild() -> void:
	if _rows == null:
		return
	DotMenuKit.clear(_rows)

	_title.text = title_text
	_instructions.text = instructions
	if items.is_empty():
		_rows.add_child(kit.paragraph(empty_text))

	for row in range(1, PAGE_SIZE + 1):
		var it: Variant = at_row(row)
		if it == null:
			break
		_rows.add_child(_row(row, it as Dictionary))

	var foot := "Page %d of %d  ·  %d %s" % [page + 1, pages(), items.size(), noun]
	if footer_extra.is_valid():
		var more := str(footer_extra.call(items))
		if more != "":
			foot += "  ·  " + more
	_footer.text = foot + "  ·  8 previous  9 next"


func _row(row: int, it: Dictionary) -> Control:
	var p := kit.palette
	var button := Button.new()
	button.name = "Row%d" % row
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(0, 38)
	button.pressed.connect(func() -> void: var _p := pick(row))

	var line := HBoxContainer.new()
	line.add_theme_constant_override(&"separation", 10)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	DotMenuKit.fill_parent(line)
	line.offset_left = 10
	line.offset_right = -10
	button.add_child(line)

	var cap := kit.keycap(str(row))
	cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_child(cap)

	var current := bool(it.get("current", false))
	var name := kit.label(str(it.get("name", it.get("id", "?"))), kit.size_body, p.accent if current else p.text, true)
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_child(name)

	var tags := PackedStringArray()
	for t in (it.get("tags", []) as Array):
		tags.append(str(t))
	var tag := kit.label("  ·  ".join(tags), kit.size_small, p.warn if bool(it.get("warn", false)) else p.muted)
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_child(tag)
	return button


func describe() -> Dictionary:
	return {"open": visible, "items": items.size(), "page": page, "pages": pages()}
