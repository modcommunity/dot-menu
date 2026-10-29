class_name DotMenuLoadoutSaved
extends VBoxContainer
## The saved-loadout switcher of the loadout screen: a chip per saved loadout and a name field
## with Save new, Rename and Delete. It only emits the words of the server's /loadout command.

## `save NAME`, `use N`, `rename N NAME` or `delete N`, without the command itself.
signal requested(args: String)

var kit: DotMenuKit
var _chips: HBoxContainer
var _name: LineEdit
var _rename: Button
var _delete: Button
var _held: Array = []


func setup(p_kit: DotMenuKit) -> void:
	kit = p_kit
	var p := kit.palette
	name = "Saved"
	add_theme_constant_override(&"separation", 8)
	add_child(kit.label("Saved loadouts", kit.size_small, p.muted, true))
	_chips = HBoxContainer.new()
	_chips.name = "Chips"
	_chips.add_theme_constant_override(&"separation", 6)
	add_child(_chips)
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 6)
	add_child(row)
	_name = LineEdit.new()
	_name.name = "SavedName"
	_name.placeholder_text = "Name"
	_name.max_length = 32
	_name.custom_minimum_size = Vector2(180, 36)
	_name.add_theme_stylebox_override(&"normal", kit.box(p.card, kit.radius_small, p.line, 1, Vector4(12, 6, 12, 6)))
	_name.add_theme_stylebox_override(&"focus", kit.box(p.card, kit.radius_small, p.accent, 1, Vector4(12, 6, 12, 6)))
	row.add_child(_name)
	var save := _small("Save new", "SaveNew")
	save.pressed.connect(func() -> void: _send("save"))
	row.add_child(save)
	_rename = _small("Rename", "Rename")
	_rename.pressed.connect(func() -> void: _send("rename"))
	row.add_child(_rename)
	_delete = _small("Delete", "Delete")
	_delete.pressed.connect(func() -> void: requested.emit("delete %d" % (selected_index() + 1)))
	row.add_child(_delete)


## Draws the server's `saved` list: `{index, name, selected, saved}` per loadout.
func show_list(saved: Array) -> void:
	_held = saved
	DotMenuKit.clear(_chips)
	var p := kit.palette
	for e: Variant in saved:
		var d := e as Dictionary
		var on := bool(d.get("selected", false))
		var b := kit.secondary_button(str(d.get("name", "")))
		b.name = "Chip%d" % (int(d.get("index", 0)) + 1)
		b.custom_minimum_size = Vector2(0, 36)
		b.focus_mode = Control.FOCUS_NONE
		if on:
			b.add_theme_stylebox_override(&"normal", kit.box(p.accent_wash(), kit.radius_small, p.accent, 1, Vector4(14, 6, 14, 6)))
		var at := int(d.get("index", 0)) + 1
		b.pressed.connect(func() -> void:
			if not on:
				requested.emit("use %d" % at))
		_chips.add_child(b)
	var real := _held.size() > 0 and bool((_held[0] as Dictionary).get("saved", false))
	_rename.disabled = not real
	_delete.disabled = _held.size() < 2 or not real


func selected_index() -> int:
	for e: Variant in _held:
		if bool((e as Dictionary).get("selected", false)):
			return int((e as Dictionary).get("index", 0))
	return 0


## The text in the name field, or "" (the server then refuses with its own words).
func typed() -> String:
	return _name.text.strip_edges()


func _send(verb: String) -> void:
	var text := typed()
	if verb == "save":
		requested.emit("save %s" % text if text != "" else "save")
	elif text != "":
		requested.emit("rename %d %s" % [selected_index() + 1, text])


func _small(text: String, node_name: String) -> Button:
	var b := kit.secondary_button(text)
	b.name = node_name
	b.custom_minimum_size = Vector2(0, 36)
	b.focus_mode = Control.FOCUS_NONE
	return b
