class_name DotMenuLoadoutDetail
extends RefCounted
## The loadout screen's picture frames, tags and the detail panel for the highlighted card.


## The tags worth showing: not the slot's own name or the kind, which the card already says.
static func shown_tags(slot: Dictionary, item: Dictionary, limit: int) -> PackedStringArray:
	var said := [str(slot.get("id", "")).to_lower(), str(slot.get("name", "")).to_lower(), str(item.get("kind", "")).to_lower()]
	var out := PackedStringArray()
	for t: Variant in item.get("tags", []):
		var tag := str(t)
		if out.size() < limit and not said.has(tag.to_lower()):
			out.append(tag)
	return out


## A picture frame: the item's icon, or its initials when it has none (an empty box reads as
## broken art).
static func icon_box(kit: DotMenuKit, item: Dictionary, min_size: Vector2, framed: bool) -> Control:
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
static func draw(screen: DotMenuLoadoutScreen, _detail: HBoxContainer) -> void:
	var kit := screen.kit
	DotMenuKit.clear(_detail)
	var p := kit.palette
	var list := screen.choices()
	if list.is_empty():
		return
	var item := list[clampi(screen.card_index, 0, list.size() - 1)] as Dictionary
	var slot := screen.current_slot()
	var held := DotMenuLoadoutScreen._choice(slot, str(screen.draft.get(str(slot.get("id", "")), "")))

	var pic := icon_box(kit, item, Vector2(250, 140), true)
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
	var tags := shown_tags(slot, item, 8)
	if not tags.is_empty():
		words.add_child(kit.label("  ·  ".join(tags), kit.size_small - 1, p.dim))
	if bool(item.get("locked", false)):
		words.add_child(kit.label("Not unlocked", kit.size_small, p.danger, true))
		var get_it := kit.primary_button("Get in store")
		get_it.name = "GetInStore"
		get_it.focus_mode = Control.FOCUS_NONE
		get_it.pressed.connect(func() -> void: screen.store_requested.emit(StringName(str(item.get("id", ""))), str(item.get("store", ""))))
		words.add_child(get_it)

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
