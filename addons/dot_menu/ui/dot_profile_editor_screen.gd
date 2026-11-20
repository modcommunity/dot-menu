class_name DotProfileEditorScreen
extends PanelContainer

## Lists profile kinds and ids and edits one in a [DotUiForm] with Apply, Revert and Reset. Example: docs/examples.md.
## The save and reset targets are callables, so the same screen can edit the runtime layer for an admin.

signal profile_opened(kind: String, id: String)
## The edit of [param kind]/[param id] was saved by [member save_target].
signal saved(kind: String, id: String, changes: Dictionary)
signal reset_done(kind: String, id: String)

## `func(set: DotProfileSet, id: String, changes: Dictionary) -> DotResult`. Default: the user tier.
var save_target: Callable = Callable()
## `func(set: DotProfileSet, id: String) -> DotResult` drops the saved edits. Default: the user tier.
var reset_target: Callable = Callable()
## `func(set: DotProfileSet, id: String) -> bool`: is there a saved edit to reset? Default: a user file.
var has_override: Callable = Callable()
## Where Apply writes, shown under the title.
var target_label := "Your mods on this device"
## Below this width the lists collapse into two dropdowns above the form.
var compact_below := 720.0
var tokens: DotFormTokens = DotFormTokens.dark()

var form: DotUiForm = null

var _sets := {}
var _labels := {}
var _kind := ""
var _id := ""
var _compact := false
var _body: Control = null
var _sidebar_box: VBoxContainer = null
var _kind_pick: OptionButton = null
var _id_pick: OptionButton = null
var _reset_btn: Button = null
var _note: Label = null
var _target: Label = null
var _empty: Control = null
var _pane: VBoxContainer = null
var _built_width := -1.0
var _list_buttons := {}


func _init() -> void:
	resized.connect(_on_resized)


## Adds a kind (a [DotProfileSet]) under [param label]; the set's rel_path is the kind's name.
func add_set(set: DotProfileSet, label: String = "") -> void:
	var kind := set.rel_path
	_sets[kind] = set
	_labels[kind] = label if label != "" else kind.capitalize()
	_build()


## Kind names in the order they were added.
func kinds() -> PackedStringArray:
	return PackedStringArray(_sets.keys())


## Ids the list shows for [param kind].
func ids(kind: String) -> PackedStringArray:
	return (_sets[kind] as DotProfileSet).list_ids() if _sets.has(kind) else PackedStringArray()


func current_kind() -> String:
	return _kind


func current_id() -> String:
	return _id


## Opens one profile in the form. Fails when the kind is unknown or the profile does not load.
func open(kind: String, id: String) -> DotResult:
	if not _sets.has(kind):
		return DotResult.fail(DotError.CODE_INVALID, "no profile kind '%s'" % kind)
	var set: DotProfileSet = _sets[kind]
	var loaded := set.load_profile(id)
	if not loaded.ok:
		_say(loaded.error.message, true)
		return loaded
	_kind = kind
	_id = id
	_show_form(set, loaded.value)
	_mark_selection()
	profile_opened.emit(kind, id)
	return DotResult.success(null)


## Saves the form's changes through [member save_target]. Value: the changes written.
func apply() -> DotResult:
	if form == null:
		return DotResult.fail(DotError.CODE_STATE, "no profile is open")
	return form.apply()


## Drops the saved edits of the open profile through [member reset_target] and reloads it.
func reset_profile() -> DotResult:
	if form == null:
		return DotResult.fail(DotError.CODE_STATE, "no profile is open")
	var set: DotProfileSet = _sets[_kind]
	var res: DotResult = reset_target.call(set, _id) if reset_target.is_valid() else set.reset_user(_id)
	if not res.ok:
		_say(res.error.message, true)
		return res
	set.clear_cache()
	var loaded := set.load_profile(_id)
	if not loaded.ok:
		_say(loaded.error.message, true)
		return loaded
	form.set_values(loaded.value.values)
	_say("\u2713  Back to the defaults", false)
	_refresh_reset()
	reset_done.emit(_kind, _id)
	return DotResult.success(null)


func restyle(t: DotFormTokens) -> void:
	tokens = t
	_build()
	if _kind != "" and _id != "":
		open(_kind, _id)


func describe() -> String:
	return "DotProfileEditorScreen: %d kinds, open %s/%s, %s" % [_sets.size(), _kind, _id, "compact" if _compact else "wide"]


func _build() -> void:
	for c in get_children():
		remove_child(c)
		c.queue_free()
	form = null
	_list_buttons.clear()
	if size.x > 0.0:
		_compact = size.x < compact_below
	_built_width = size.x
	tokens.touch = _compact or DisplayServer.is_touchscreen_available()
	theme = tokens.build_theme()
	add_theme_stylebox_override("panel", tokens.box(tokens.bg, 0))
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, tokens.sp(4))
	add_child(margin)
	var layout: BoxContainer = VBoxContainer.new() if _compact else HBoxContainer.new()
	layout.add_theme_constant_override("separation", tokens.sp(4))
	margin.add_child(layout)
	_body = layout
	if _compact:
		layout.add_child(_build_dropdowns())
	else:
		layout.add_child(_build_sidebar())
	_pane = VBoxContainer.new()
	_pane.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_pane.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_pane.add_theme_constant_override("separation", tokens.sp(3))
	layout.add_child(_pane)
	_empty = _build_empty()
	_pane.add_child(_empty)


## The empty state: a centred title and one line of what to do, never a bare caption.
func _build_empty() -> Control:
	var box := VBoxContainer.new()
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", tokens.sp(1))
	var head := Label.new()
	head.text = "Choose a profile" if not _sets.is_empty() else "Nothing to edit"
	head.add_theme_font_override("font", tokens.bold())
	head.add_theme_font_size_override("font_size", tokens.px(tokens.font_section))
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(head)
	var hint := Label.new()
	hint.theme_type_variation = &"FormCaption"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.text = "No profile kinds are registered yet."
	if not _sets.is_empty():
		hint.text = "Pick one %s to edit its values." % ("above" if _compact else "in the list")
	box.add_child(hint)
	return box


func _build_sidebar() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = tokens.px(220)
	panel.add_theme_stylebox_override("panel", tokens._pad(tokens.box(tokens.card, -1, tokens.border, 1, 1), tokens.sp(3), tokens.sp(3)))
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	_sidebar_box = VBoxContainer.new()
	_sidebar_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sidebar_box.add_theme_constant_override("separation", tokens.sp(1))
	scroll.add_child(_sidebar_box)
	for kind in _sets:
		var head := Label.new()
		head.text = String(_labels[kind]).to_upper()
		head.theme_type_variation = &"FormCaption"
		head.add_theme_color_override("font_color", tokens.text_faint)
		head.add_theme_constant_override("line_spacing", 0)
		var head_pad := MarginContainer.new()
		head_pad.add_theme_constant_override("margin_left", tokens.sp(2))
		head_pad.add_theme_constant_override("margin_top", tokens.sp(1))
		head_pad.add_theme_constant_override("margin_bottom", tokens.sp(1))
		head_pad.add_child(head)
		_sidebar_box.add_child(head_pad)
		var list: PackedStringArray = ids(kind)
		if list.is_empty():
			var none := Label.new()
			none.text = "none yet"
			none.theme_type_variation = &"FormCaption"
			var none_pad := MarginContainer.new()
			none_pad.add_theme_constant_override("margin_left", tokens.sp(3))
			none_pad.add_child(none)
			_sidebar_box.add_child(none_pad)
		for id in list:
			var b := Button.new()
			b.text = id
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			b.toggle_mode = true
			b.focus_mode = Control.FOCUS_ALL
			b.custom_minimum_size.y = tokens.target()
			b.clip_text = true
			b.pressed.connect(_on_list_pressed.bind(kind, id))
			_style_list_button(b)
			_sidebar_box.add_child(b)
			_list_buttons["%s/%s" % [kind, id]] = b
		var gap := Control.new()
		gap.custom_minimum_size.y = tokens.sp(2)
		_sidebar_box.add_child(gap)
	return panel


func _style_list_button(b: Button) -> void:
	var pad := tokens.sp(3)
	b.add_theme_stylebox_override("normal", tokens._pad(tokens.box(Color.TRANSPARENT, 8), pad, tokens.sp(1)))
	b.add_theme_stylebox_override("hover", tokens._pad(tokens.box(tokens.field_hover, 8), pad, tokens.sp(1)))
	b.add_theme_stylebox_override("focus", tokens._pad(tokens.box(Color.TRANSPARENT, 8, tokens.accent, 2), pad, tokens.sp(1)))
	var on := tokens._pad(tokens.box(tokens.accent, 8), pad, tokens.sp(1))
	for s in ["pressed", "hover_pressed"]:
		b.add_theme_stylebox_override(s, on)
	b.add_theme_color_override("font_color", tokens.text)
	b.add_theme_color_override("font_pressed_color", tokens.accent_ink)
	b.add_theme_color_override("font_hover_pressed_color", tokens.accent_ink)


func _build_dropdowns() -> Control:
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", tokens.sp(2))
	_kind_pick = OptionButton.new()
	_id_pick = OptionButton.new()
	for p in [_kind_pick, _id_pick]:
		p.custom_minimum_size.y = tokens.target()
		p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(p)
	for kind in _sets:
		_kind_pick.add_item(_labels[kind])
		_kind_pick.set_item_metadata(_kind_pick.item_count - 1, kind)
	_kind_pick.item_selected.connect(_on_kind_picked)
	_id_pick.item_selected.connect(_on_id_picked)
	var first: String = _kind if _kind != "" else (_sets.keys()[0] if not _sets.is_empty() else "")
	_fill_ids(first)
	return row


func _fill_ids(kind: String) -> void:
	if _id_pick == null or kind == "":
		return
	_id_pick.clear()
	for id in ids(kind):
		_id_pick.add_item(id)
	for i in _kind_pick.item_count:
		if _kind_pick.get_item_metadata(i) == kind:
			_kind_pick.select(i)
	_id_pick.select(-1)
	if _kind == kind and _id != "":
		for i in _id_pick.item_count:
			if _id_pick.get_item_text(i) == _id:
				_id_pick.select(i)


func _on_kind_picked(index: int) -> void:
	_fill_ids(_kind_pick.get_item_metadata(index))


func _on_id_picked(index: int) -> void:
	open(_kind_pick.get_item_metadata(_kind_pick.selected), _id_pick.get_item_text(index))


func _on_list_pressed(kind: String, id: String) -> void:
	open(kind, id)


func _mark_selection() -> void:
	for key in _list_buttons:
		(_list_buttons[key] as Button).set_pressed_no_signal(key == "%s/%s" % [_kind, _id])
	if _id_pick != null:
		_fill_ids(_kind)


func _show_form(set: DotProfileSet, profile: DotProfile) -> void:
	for c in _pane.get_children():
		_pane.remove_child(c)
		c.queue_free()
	_empty = null
	_pane.add_child(_build_header())
	form = DotUiForm.new()
	form.tokens = tokens
	form.title = _id.capitalize()
	form.compact_below = compact_below
	form.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_pane.add_child(form)
	var built := form.build(set.schema, profile.values)
	if not built.ok:
		_say(built.error.message, true)
	form.applied.connect(_on_applied)
	_polish_form()
	form.child_entered_tree.connect(_on_form_rebuilt.unbind(1))
	_refresh_reset()


## Kind chip, destination and Reset in one rounded card level with the rail; the status note sits beside the chip.
func _build_header() -> Control:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", tokens._pad(tokens.box(tokens.card, -1, tokens.border, 1), tokens.sp(3), tokens.sp(2)))
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", tokens.px(2.0))
	card.add_child(col)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", tokens.sp(2))
	col.add_child(top)
	var chip := PanelContainer.new()
	chip.add_theme_stylebox_override("panel", tokens._pad(tokens.box(Color(tokens.accent, 0.18), 999, Color(tokens.accent, 0.5), 1), tokens.sp(2), tokens.px(2.0)))
	var chip_label := Label.new()
	chip_label.text = String(_labels[_kind])
	chip_label.add_theme_color_override("font_color", tokens.accent)
	chip_label.add_theme_font_size_override("font_size", tokens.px(tokens.font_small + 1))
	chip.add_child(chip_label)
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(chip)
	_note = Label.new()
	_note.theme_type_variation = &"FormCaption"
	_note.add_theme_color_override("font_color", tokens.good)
	_note.visible = false
	_note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_note.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_note.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	top.add_child(_note)
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gap.name = "NoteGap"
	top.add_child(gap)
	_reset_btn = Button.new()
	_reset_btn.theme_type_variation = &"FormGhost"
	_reset_btn.text = "\u21BA  Reset to defaults"
	_reset_btn.tooltip_text = "Drop your saved edits of this profile"
	_reset_btn.custom_minimum_size.y = tokens.target()
	_reset_btn.pressed.connect(_on_reset_pressed)
	top.add_child(_reset_btn)
	_target = Label.new()
	_target.theme_type_variation = &"FormCaption"
	_target.text = "Saves to  %s" % target_label
	_target.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_target)
	return card


## The form rebuilds itself when the width crosses its compact breakpoint; the polish goes on again.
func _on_form_rebuilt() -> void:
	_polish_form.call_deferred()


## Brings the form's own bar in line with the screen: no side margin of its own, a rounded footer without the hard shadow, icons on the actions. Uses only the form's node order, and leaves it as it is when that changes.
func _polish_form() -> void:
	if form == null or form.get_child_count() == 0:
		return
	var outer := form.get_child(0) as VBoxContainer
	if outer == null or outer.get_child_count() < 2:
		return
	var margin := outer.get_child(0) as MarginContainer
	if margin != null:
		for side in ["left", "right", "top"]:
			margin.add_theme_constant_override("margin_" + side, 0)
		margin.add_theme_constant_override("margin_bottom", tokens.sp(3))
	var footer := outer.get_child(outer.get_child_count() - 1) as PanelContainer
	if footer != null:
		footer.add_theme_stylebox_override("panel", tokens._pad(tokens.box(tokens.card, -1, tokens.border, 1), tokens.sp(3), tokens.sp(2)))
	var apply_btn := form.apply_button()
	var revert_btn := form.revert_button()
	if apply_btn != null:
		apply_btn.text = "\u2713  Apply"
		apply_btn.custom_minimum_size = Vector2(tokens.px(120), tokens.target())
		apply_btn.tooltip_text = "Save the unsaved changes"
	if revert_btn != null:
		revert_btn.text = "\u21B6  Revert"
		revert_btn.custom_minimum_size = Vector2(tokens.px(96), tokens.target())
		revert_btn.tooltip_text = "Drop the unsaved changes"


func _on_applied(changes: Dictionary) -> void:
	var set: DotProfileSet = _sets[_kind]
	var res: DotResult = save_target.call(set, _id, changes) if save_target.is_valid() else set.save_user(_id, changes)
	if not res.ok:
		_say(res.error.message, true)
		var keep: Dictionary = form.values()
		form.set_values(set.load_profile(_id).value.values if set.load_profile(_id).ok else {})
		for k in changes:
			var _r := form.set_value(k, keep[k])
		return
	set.clear_cache()
	_say("\u2713  Saved", false)
	_refresh_reset()
	saved.emit(_kind, _id, changes)


func _on_reset_pressed() -> void:
	var _r := reset_profile()


func _refresh_reset() -> void:
	if _reset_btn == null:
		return
	var set: DotProfileSet = _sets[_kind]
	var has: bool = has_override.call(set, _id) if has_override.is_valid() else FileAccess.file_exists(set.user_file(_id))
	_reset_btn.disabled = not has


func _say(text: String, bad: bool) -> void:
	if _note == null:
		return
	_note.text = text
	_note.visible = true
	var gap := _note.get_parent().get_node_or_null("NoteGap")
	if gap != null:
		gap.visible = false
	_note.add_theme_color_override("font_color", tokens.danger if bad else tokens.good)


func _on_resized() -> void:
	if _sets.is_empty() or absf(size.x - _built_width) < 1.0:
		return
	if (size.x < compact_below) != _compact and size.x > 0.0:
		_built_width = size.x
		call_deferred("restyle", tokens)
