class_name DotAddonConfigEditorScreen
extends PanelContainer

## Edits the player's own override of addon cfg files (`user://cfg/user/addons/`) in a [DotUiForm]. Example: docs/examples.md.
## Only a solo or listen-host process has the tier ([method DotAddonConfig.set_user_tier]); elsewhere Apply
## reports why and writes nothing.

signal file_opened(addon: String, file: String)
signal saved(addon: String, file: String, changes: Dictionary)
signal reset_done(addon: String, file: String)
## An overlay use ([method DotMenu.use_mods]) was closed.
signal closed

## Where Apply writes, shown under the title.
var target_label := "Your mods on this device"
var compact_below := 720.0
var tokens: DotFormTokens = DotFormTokens.dark()

var form: DotUiForm = null

var _files: Array[Dictionary] = []
var _addon := ""
var _file := ""
var _pane: VBoxContainer = null
var _list: HFlowContainer = null
var _reset_btn: Button = null
var _note: Label = null
var _buttons := {}
var _history: Array[Dictionary] = []
var _undoing := false
var _before := {}
var _undo_btn: Button = null
var _close_btn: Button = null
var _as_overlay := false



## Adds an editable file: [param schema] is the [method DotProfileSet.field] array describing its top-level keys.
func add_file(addon: String, file: String, schema: Array, label: String = "") -> void:
	_files.append({"addon": addon, "file": file, "schema": schema, "label": label if label != "" else file.get_basename().capitalize()})
	_build()


## Shows the screen as an overlay; hidden until then when used through [method DotMenu.use_mods].
func open_screen() -> void:
	visible = true
	_as_overlay = true
	if _close_btn != null:
		_close_btn.visible = true


func close() -> void:
	if visible:
		visible = false
		closed.emit()


func is_open() -> bool:
	return visible


## Takes back the last edit in the open form (before Apply). Fails when there is none.
func undo() -> DotResult:
	if form == null or _history.is_empty():
		return DotResult.fail(DotError.CODE_STATE, "nothing to undo")
	var last: Dictionary = _history.pop_back()
	_before[last["key"]] = last["old"]
	_undoing = true
	var res := form.set_value(last["key"], last["old"])
	_undoing = false
	_refresh_undo()
	return res


## How many edits [method undo] can take back.
func undo_depth() -> int:
	return _history.size()


func current_addon() -> String:
	return _addon


func current_file() -> String:
	return _file


## Opens one added file in the form. Fails when it was never added.
func open(addon: String, file: String) -> DotResult:
	var entry := _entry(addon, file)
	if entry.is_empty():
		return DotResult.fail(DotError.CODE_INVALID, "no editable file %s/%s" % [addon, file])
	_addon = addon
	_file = file
	_history.clear()
	_show_form(entry)
	for key in _buttons:
		(_buttons[key] as Button).set_pressed_no_signal(key == "%s/%s" % [addon, file])
	file_opened.emit(addon, file)
	return DotResult.success(null)


## Saves the form's changes to the user tier. Value: the changes written.
func apply() -> DotResult:
	if form == null:
		return DotResult.fail(DotError.CODE_STATE, "no file is open")
	return form.apply()


## Deletes the user copy of the open file and shows the values below it.
func reset_file() -> DotResult:
	if form == null:
		return DotResult.fail(DotError.CODE_STATE, "no file is open")
	var res := DotAddonConfig.reset_user(_addon, _file)
	if not res.ok:
		_say(res.error.message, true)
		return res
	form.set_values(_values(_entry(_addon, _file)))
	_before = form.values()
	_history.clear()
	_refresh_undo()
	_say("Back to the defaults", false)
	_refresh_reset()
	reset_done.emit(_addon, _file)
	return DotResult.success(null)


func restyle(t: DotFormTokens) -> void:
	tokens = t
	_build()
	if _file != "":
		var _o := open(_addon, _file)


func describe() -> String:
	return "DotAddonConfigEditorScreen: %d files, open %s/%s, user tier %s" % [_files.size(), _addon, _file, "on" if DotAddonConfig.user_tier_enabled else "off"]


func _entry(addon: String, file: String) -> Dictionary:
	for e in _files:
		if e["addon"] == addon and e["file"] == file:
			return e
	return {}


func _values(entry: Dictionary) -> Dictionary:
	var out := {}
	for f in entry["schema"]:
		out[f["name"]] = f["default"]
	for path in DotAddonConfig.file_layers(entry["addon"], entry["file"]):
		var parsed := DotYaml.parse_file(path)
		if parsed.ok and parsed.value is Dictionary:
			DotAddonConfig.merge(out, parsed.value)
	return out


func _build() -> void:
	for c in get_children():
		remove_child(c)
		c.queue_free()
	form = null
	_buttons.clear()
	tokens.touch = size.x > 0.0 and size.x < compact_below or DisplayServer.is_touchscreen_available()
	theme = tokens.build_theme()
	add_theme_stylebox_override("panel", tokens.box(tokens.bg, 0))
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, tokens.sp(4))
	add_child(margin)
	_pane = VBoxContainer.new()
	_pane.add_theme_constant_override("separation", tokens.sp(2))
	margin.add_child(_pane)
	_list = HFlowContainer.new()
	_list.add_theme_constant_override("h_separation", tokens.sp(2))
	_pane.add_child(_list)
	for e in _files:
		var b := Button.new()
		b.text = e["label"]
		b.toggle_mode = true
		b.custom_minimum_size.y = tokens.target()
		b.pressed.connect(_on_file_pressed.bind(e["addon"], e["file"]))
		var pad := tokens.sp(3)
		b.add_theme_stylebox_override("normal", tokens._pad(tokens.box(tokens.card, 8), pad, tokens.sp(1)))
		b.add_theme_stylebox_override("hover", tokens._pad(tokens.box(tokens.field_hover, 8), pad, tokens.sp(1)))
		var on := tokens._pad(tokens.box(tokens.accent, 8), pad, tokens.sp(1))
		b.add_theme_stylebox_override("pressed", on)
		b.add_theme_stylebox_override("hover_pressed", on)
		b.add_theme_color_override("font_color", tokens.text)
		b.add_theme_color_override("font_pressed_color", tokens.accent_ink)
		b.add_theme_color_override("font_hover_pressed_color", tokens.accent_ink)
		_list.add_child(b)
		_buttons["%s/%s" % [e["addon"], e["file"]]] = b
	var empty := Label.new()
	empty.name = "Empty"
	empty.theme_type_variation = &"FormCaption"
	empty.text = "Choose a file to edit." if not _files.is_empty() else "Nothing to edit."
	_pane.add_child(empty)


func _show_form(entry: Dictionary) -> void:
	for i in range(_pane.get_child_count() - 1, 0, -1):
		var c := _pane.get_child(i)
		_pane.remove_child(c)
		c.queue_free()
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", tokens.sp(3))
	_pane.add_child(bar)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 0)
	bar.add_child(col)
	var target := Label.new()
	target.theme_type_variation = &"FormCaption"
	target.text = "%s    Saves to: %s" % [entry["label"], target_label]
	target.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(target)
	_note = Label.new()
	_note.theme_type_variation = &"FormCaption"
	_note.visible = false
	if not DotAddonConfig.user_tier_enabled:
		_say("Mods are off in this session (a server or an online game owns these values)", true)
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_note)
	_undo_btn = Button.new()
	_undo_btn.theme_type_variation = &"FormGhost"
	_undo_btn.text = "Undo last edit"
	_undo_btn.custom_minimum_size.y = tokens.target()
	_undo_btn.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_undo_btn.pressed.connect(_on_undo_pressed)
	col.add_child(_undo_btn)
	_reset_btn = Button.new()
	_reset_btn.theme_type_variation = &"FormGhost"
	_reset_btn.text = "Reset to defaults"
	_reset_btn.custom_minimum_size.y = tokens.target()
	_reset_btn.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_reset_btn.pressed.connect(_on_reset_pressed)
	col.add_child(_reset_btn)
	var back := Button.new()
	back.name = "Close"
	back.theme_type_variation = &"FormGhost"
	back.text = "Close"
	back.custom_minimum_size.y = tokens.target()
	back.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	back.visible = _as_overlay
	back.pressed.connect(close)
	bar.add_child(back)
	_close_btn = back
	form = DotUiForm.new()
	form.tokens = tokens
	form.title = entry["label"]
	form.compact_below = compact_below
	form.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_pane.add_child(form)
	var built := form.build(entry["schema"], _values(entry))
	if not built.ok:
		_say(built.error.message, true)
	_before = form.values()
	form.applied.connect(_on_applied)
	form.value_changed.connect(_on_value_changed)
	_refresh_undo()
	_refresh_reset()


func _on_value_changed(key: String, _value: Variant) -> void:
	if _undoing:
		return
	_history.append({"key": key, "old": _before.get(key)})
	_before[key] = _value
	_refresh_undo()


func _on_undo_pressed() -> void:
	var _r := undo()


func _refresh_undo() -> void:
	if _undo_btn != null:
		_undo_btn.disabled = _history.is_empty()


func _on_applied(changes: Dictionary) -> void:
	var entry := _entry(_addon, _file)
	var res := DotAddonConfig.save_user(_addon, _file, changes, entry["schema"])
	if not res.ok:
		_say(res.error.message, true)
		return
	_say("Saved", false)
	_refresh_reset()
	saved.emit(_addon, _file, changes)


func _on_reset_pressed() -> void:
	var _r := reset_file()


func _on_file_pressed(addon: String, file: String) -> void:
	var _r := open(addon, file)


func _refresh_reset() -> void:
	if _reset_btn != null:
		_reset_btn.disabled = not FileAccess.file_exists(DotAddonConfig.user_file(_addon, _file))


func _say(text: String, bad: bool) -> void:
	if _note == null:
		return
	_note.text = text
	_note.visible = true
	_note.add_theme_color_override("font_color", tokens.danger if bad else tokens.good)


