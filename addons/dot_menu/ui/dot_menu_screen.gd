class_name DotMenuScreen
extends Control

## The Escape menu: a sidebar of pages and actions, and the page on the right as cards of rows.
##
## Built by [DotMenu], which is what a game usually talks to; usable alone by a host that
## manages its own overlays:
## [codeblock]
## var screen := DotMenuScreen.new()
## screen.kit = DotMenuKit.new(themes.named(&"midnight"))
## screen.settings = settings
## screen.bindings = keys
## screen.pages = DotMenuStock.pages()
## add_child(screen)
## screen.open()
## [/codeblock]
##
## [b]Every control is a view of a setting, never a second copy of one.[/b] See [DotMenuRow].
## A page is drawn from its data each time it is shown and thrown away when another is, so
## nothing here can hold a stale value.
##
## [b]It does not pause.[/b] dot-ui's `allow_pause` reason: pausing the tree pauses only the
## local simulation, which drifts from a server that carried on. A game suspends its input
## sampler while the menu is open instead, so a player who opens it stands still rather than
## walking off a ledge with the key they were holding.
##
## [b]A setting a server has clamped says so.[/b] dot-settings keeps the player's own value
## and applies the server's bound over it; the row shows the player's value (what they
## chose, and what they get back on leaving) and a line underneath saying what this server
## caps it at. Showing the clamped value instead would quietly replace what they chose.

const CHANNEL := "menu.screen"

signal closed()

## A sidebar action was pressed: &"help", &"leave", or a game's own.
signal action_requested(id: StringName)

## A setting row wrote a value. After the write, so a handler reads the new one.
signal setting_written(key: StringName, value: Variant)

## A page was drawn. For a game that decorates a page after it is built.
signal page_shown(id: StringName)

var kit: DotMenuKit = null
var settings: DotSettingsManager = null
var bindings: DotMenuBindings = null
var config: DotMenuConfig = null

var pages: Array[DotMenuPage] = []

## Sidebar actions under the pages: `{id, text, danger}`, top to bottom. An empty text hides
## one. [DotMenu] fills Help and Leave from its config.
var actions: Array[Dictionary] = []

## Under the brand: where the player is ("Online · surf_g2g_intro").
var subtitle: String = "":
	set(value):
		subtitle = value
		if _subtitle != null:
			_subtitle.text = value
			_subtitle.visible = value != ""

## Row and page ids hidden on top of the config's — what a server asked for.
var extra_hidden_rows: PackedStringArray = PackedStringArray()
var extra_hidden_pages: PackedStringArray = PackedStringArray()

var _page: StringName = &""
var _nav: Dictionary = {}
var _action_buttons: Dictionary = {}
var _window: PanelContainer = null
var _body: VBoxContainer = null
var _scroll: ScrollContainer = null
var _title: Label = null
var _blurb: Label = null
var _subtitle: Label = null
var _toast: Label = null
var _toast_until: float = 0.0
var _resume: Button = null
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


## Rebuilds this screen in [param new_kit]. What a theme change calls.
##
## [b]Rebuilt, not recoloured.[/b] Every box and colour here is set once, as an override,
## when the screen is built; walking the tree to find each one again is a second copy of the
## build that drifts from the first. Building again is the one that cannot.
func restyle(new_kit: DotMenuKit) -> void:
	kit = new_kit
	if not _built:
		return
	DotMenuKit.clear(self)
	_nav.clear()
	_action_buttons.clear()
	_build()
	_fit()
	# The tabs are not part of _build — [method open] fills them, because pages change while
	# the menu is shut. A rebuild that skipped this left an open menu with no tabs down the
	# left until the player closed and reopened it, which is how a theme change looked.
	_rebuild_sidebar()
	if visible:
		_show_page(_page)


func _build() -> void:
	theme = kit.theme()
	add_child(kit.backdrop())

	var centre := CenterContainer.new()
	DotMenuKit.fill_parent(centre)
	add_child(centre)

	_window = PanelContainer.new()
	_window.add_theme_stylebox_override(&"panel", kit.surface_box())
	centre.add_child(_window)

	var columns := HBoxContainer.new()
	columns.add_theme_constant_override(&"separation", 0)
	_window.add_child(columns)

	columns.add_child(_sidebar())
	columns.add_child(_content())
	_built = true


## Opens on [param page], or on the page it was last left on, or the first.
func open(page: StringName = &"") -> void:
	if page != &"":
		_page = page
	_rebuild_sidebar()
	_show_page(_page)
	visible = true
	if _resume != null:
		_resume.grab_focus()


func close() -> void:
	if not visible:
		return
	visible = false
	closed.emit()


func is_open() -> bool:
	return visible


func current_page() -> StringName:
	return _page


## Draws [param id] now, if the menu is open; otherwise it is where the next open starts.
func show_page(id: StringName) -> void:
	_page = id
	if visible:
		_show_page(id)


## Draws the current page again: after something it shows changed underneath it.
func refresh() -> void:
	if visible:
		_rebuild_sidebar()
		_show_page(_page)


func _process(_delta: float) -> void:
	if _toast != null and _toast.text != "" and Time.get_ticks_msec() / 1000.0 > _toast_until:
		_toast.text = ""


## Says something small under the page title for a few seconds.
func toast(text: String, seconds: float = 4.0) -> void:
	if _toast == null:
		return
	_toast.text = text
	_toast_until = Time.get_ticks_msec() / 1000.0 + seconds


## The words on an action's button. Empty hides it ("Leave" offline, where there is nothing
## to leave).
func set_action_text(id: StringName, text: String) -> void:
	for a in actions:
		if a.get("id") == id:
			a["text"] = text
	var b: Button = _action_buttons.get(id)
	if b != null:
		b.text = text
		b.visible = text != ""


# --- Layout -----------------------------------------------------------------

## Sized to the window, within limits, so a laptop and a 4K screen both get a menu that fits
## rather than one that is either cramped or lost in the middle.
func _fit() -> void:
	if _window == null:
		return
	var view := get_viewport_rect().size
	var m := float(config.window_margin) * 2.0
	_window.custom_minimum_size = Vector2(
		clampf(view.x - m, 320.0, float(config.window_max_width)),
		clampf(view.y - m, 300.0, float(config.window_max_height))
	)


func _sidebar() -> Control:
	var p := kit.palette
	var side := PanelContainer.new()
	var s := kit.box(p.sidebar, kit.radius + 4, Color(0, 0, 0, 0), 0, Vector4(18, 22, 18, 18))
	s.corner_radius_top_right = 0
	s.corner_radius_bottom_right = 0
	side.add_theme_stylebox_override(&"panel", s)
	side.custom_minimum_size = Vector2(config.sidebar_width, 0)

	var col := VBoxContainer.new()
	col.name = "Sidebar"
	col.add_theme_constant_override(&"separation", 6)
	side.add_child(col)

	if config.brand_mark != "" or config.brand_name != "":
		var brand := HBoxContainer.new()
		brand.add_theme_constant_override(&"separation", 10)
		if config.brand_mark != "":
			var mark := PanelContainer.new()
			mark.add_theme_stylebox_override(&"panel", kit.box(p.accent, 8, Color(0, 0, 0, 0), 0, Vector4(8, 2, 8, 3)))
			mark.add_child(kit.label(config.brand_mark, kit.size_small + 1, DotMenuPalette.ink_on(p.accent), true))
			brand.add_child(mark)
		if config.brand_name != "":
			brand.add_child(kit.label(config.brand_name, kit.size_title - 4, p.text, true))
		col.add_child(brand)

	_subtitle = kit.paragraph(subtitle, kit.size_small, p.dim)
	_subtitle.visible = subtitle != ""
	col.add_child(_subtitle)
	col.add_child(DotMenuKit.gap(14))

	_resume = kit.primary_button("Resume")
	_resume.name = "Resume"
	_resume.pressed.connect(close)
	col.add_child(_resume)
	col.add_child(DotMenuKit.gap(10))

	var tabs := VBoxContainer.new()
	tabs.name = "Pages"
	tabs.add_theme_constant_override(&"separation", 6)
	col.add_child(tabs)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(spacer)

	for a in actions:
		var id: StringName = a.get("id", &"")
		var b := kit.nav_button(str(a.get("text", "")), null)
		b.name = "Action_%s" % id
		if bool(a.get("danger", false)):
			b.add_theme_color_override(&"font_color", p.danger)
			b.add_theme_color_override(&"font_hover_color", p.danger)
		b.visible = str(a.get("text", "")) != ""
		b.pressed.connect(func() -> void: action_requested.emit(id))
		_action_buttons[id] = b
		col.add_child(b)
	return side


## The page tabs, from [member pages] as they are now. Rebuilt on every open, because a page
## can be added, hidden or reordered while the menu is shut.
func _rebuild_sidebar() -> void:
	if not _built:
		return
	var tabs := _window.find_child("Pages", true, false) as VBoxContainer
	if tabs == null:
		return
	DotMenuKit.clear(tabs)
	_nav.clear()

	var group := ButtonGroup.new()
	for page in visible_pages():
		var b := kit.nav_button(page.title, group)
		b.name = "Page_%s" % page.id
		var id := page.id
		b.pressed.connect(func() -> void: _show_page(id))
		_nav[id] = b
		tabs.add_child(b)

	if not _nav.has(_page):
		var shown := visible_pages()
		_page = shown[0].id if not shown.is_empty() else &""


func _content() -> Control:
	var p := kit.palette
	var wrap := MarginContainer.new()
	wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wrap.add_theme_constant_override(&"margin_left", 30)
	wrap.add_theme_constant_override(&"margin_right", 18)
	wrap.add_theme_constant_override(&"margin_top", 24)
	wrap.add_theme_constant_override(&"margin_bottom", 18)

	var col := VBoxContainer.new()
	col.add_theme_constant_override(&"separation", 4)
	wrap.add_child(col)

	var head := HBoxContainer.new()
	_title = kit.label("", kit.size_title, p.text, true)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_title)
	var esc := HBoxContainer.new()
	esc.add_theme_constant_override(&"separation", 6)
	esc.add_child(kit.keycap("Esc"))
	esc.add_child(kit.label("to resume", kit.size_small, p.dim))
	head.add_child(esc)
	col.add_child(head)

	_blurb = kit.paragraph("", kit.size_small, p.muted)
	col.add_child(_blurb)
	_toast = kit.label("", kit.size_small, p.accent)
	col.add_child(_toast)

	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(_scroll)

	var pad := MarginContainer.new()
	pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pad.add_theme_constant_override(&"margin_right", 12)
	pad.add_theme_constant_override(&"margin_top", 6)
	pad.add_theme_constant_override(&"margin_bottom", 8)
	_scroll.add_child(pad)

	_body = VBoxContainer.new()
	_body.name = "Body"
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override(&"separation", 10)
	pad.add_child(_body)
	return wrap


# --- Pages ------------------------------------------------------------------

## The pages the sidebar shows, in the config's order, without the hidden ones.
func visible_pages() -> Array[DotMenuPage]:
	var shown: Array[DotMenuPage] = []
	for page in pages:
		if config.pages_hidden.has(String(page.id)) or extra_hidden_pages.has(String(page.id)):
			continue
		if not page.is_shown():
			continue
		shown.append(page)
	if config.page_order.is_empty():
		return shown

	var ordered: Array[DotMenuPage] = []
	for id in config.page_order:
		for page in shown:
			if String(page.id) == id:
				ordered.append(page)
	for page in shown:
		if not ordered.has(page):
			ordered.append(page)
	return ordered


func find_page(id: StringName) -> DotMenuPage:
	for page in pages:
		if page.id == id:
			return page
	return null


func _show_page(id: StringName) -> void:
	if not _built:
		return
	_page = id
	var page := find_page(id)

	_title.text = page.title if page != null else ""
	_blurb.text = page.blurb if page != null else ""
	_blurb.visible = _blurb.text != ""

	# Every button set by hand: `set_pressed_no_signal` goes round the ButtonGroup, so
	# pressing one this way leaves the last page's button lit as well.
	for key in _nav:
		(_nav[key] as Button).set_pressed_no_signal(key == id)

	DotMenuKit.clear(_body)
	if page == null:
		return

	for section in page.sections:
		_draw_section(section)
	if page.show_bindings:
		_draw_bindings()
	if page.build.is_valid():
		page.build.call(kit, _body)

	_scroll.scroll_vertical = 0
	page_shown.emit(id)


func _draw_section(section: DotMenuSection) -> void:
	var drawable: Array[DotMenuRow] = []
	for row in section.rows:
		if _row_shown(row):
			drawable.append(row)
	if section.rows_from.is_valid():
		for row in (section.rows_from.call() as Array):
			if row is DotMenuRow and _row_shown(row):
				drawable.append(row)
	var group_rows: Array[Dictionary] = []
	if section.binding_group != "" and bindings != null:
		group_rows = bindings.rows_in(section.binding_group)

	# No bare heading over an empty card.
	if drawable.is_empty() and group_rows.is_empty():
		return

	var card := _card(section.title)
	for row in drawable:
		_draw_row(card, row)
	for b in group_rows:
		_draw_row(card, DotMenuRow.binding(b))


func _row_shown(row: DotMenuRow) -> bool:
	var rid := String(row.row_id())
	if rid != "" and (config.rows_hidden.has(rid) or extra_hidden_rows.has(rid)):
		return false
	return row.is_shown(settings)


func _draw_bindings() -> void:
	if bindings == null:
		return
	for group in bindings.groups():
		var rows: Array[DotMenuRow] = []
		for b in bindings.rows_in(group):
			var row := DotMenuRow.binding(b)
			if _row_shown(row):
				rows.append(row)
		if rows.is_empty():
			continue
		var card := _card(group)
		for row in rows:
			_draw_row(card, row)

	var footer := HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_END
	var reset := Button.new()
	reset.name = "ResetKeys"
	reset.text = "Reset keys to defaults"
	reset.pressed.connect(_reset_bindings)
	footer.add_child(reset)
	_body.add_child(footer)


# --- Rows -------------------------------------------------------------------

func _draw_row(card: VBoxContainer, row: DotMenuRow) -> void:
	var rid := row.row_id()
	var title := config.row_title(rid, row.title)
	var words := config.row_description(rid, row.text_under())
	var control: Control = null

	match row.kind:
		DotMenuRow.Kind.TOGGLE:
			control = _toggle(row)
		DotMenuRow.Kind.SLIDER:
			control = _slider(row)
		DotMenuRow.Kind.SELECT:
			control = _select(row)
		DotMenuRow.Kind.BINDING:
			control = _key_button(row)
		DotMenuRow.Kind.BUTTON:
			var b := Button.new()
			b.text = row.button_text
			b.disabled = not row.is_enabled()
			if row.danger:
				b.add_theme_color_override(&"font_color", kit.palette.danger)
			if row.on_press.is_valid():
				b.pressed.connect(func() -> void: row.on_press.call())
			control = b
		DotMenuRow.Kind.NOTE:
			_note(card, words)
			return
		DotMenuRow.Kind.CUSTOM:
			if row.build.is_valid():
				control = row.build.call(kit) as Control

	if control == null:
		return
	if rid != &"":
		control.name = "Row_%s" % rid

	var clamp_note := _clamp_note(row)
	if clamp_note != "":
		words = (words + "\n" if words != "" else "") + clamp_note
	_row(card, title, words, control)


## "Capped at 90 on this server." for a setting a server has clamped; empty otherwise.
func _clamp_note(row: DotMenuRow) -> String:
	if not row.is_setting() or settings == null or not settings.is_clamped(row.key):
		return ""
	var bound: Variant = settings.clamp_bound(row.key)
	var def := settings.schema.find(row.key)
	var shown := str(bound)
	if row.kind == DotMenuRow.Kind.SLIDER:
		shown = row.show_value(float(bound))
	elif row.kind == DotMenuRow.Kind.TOGGLE:
		shown = "on" if bool(bound) else "off"
	elif def != null and def.kind == DotSettingsDef.Kind.ENUM:
		shown = _option_label(row, bound)
	var numeric := def != null and (def.kind == DotSettingsDef.Kind.INT or def.kind == DotSettingsDef.Kind.FLOAT)
	return ("This server caps it at %s." if numeric else "This server sets it to %s.") % shown


func _option_label(row: DotMenuRow, value: Variant) -> String:
	var def := settings.schema.find(row.key) if settings != null else null
	for o in row.option_list(def):
		if str(o[0]) == str(value):
			return str(o[1])
	return DotMenuRow.label_for_option(value)


func _row(card: VBoxContainer, title: String, description: String, control: Control) -> void:
	if card.get_child_count() > 0:
		card.add_child(HSeparator.new())

	var line := HBoxContainer.new()
	line.add_theme_constant_override(&"separation", 18)
	line.custom_minimum_size = Vector2(0, 52)

	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	words.add_theme_constant_override(&"separation", 1)
	words.add_child(kit.label(title, kit.size_body, kit.palette.text))
	if description != "":
		words.add_child(kit.paragraph(description, kit.size_small, kit.palette.dim))
	line.add_child(words)

	control.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(control)

	var pad := MarginContainer.new()
	pad.add_theme_constant_override(&"margin_top", 6)
	pad.add_theme_constant_override(&"margin_bottom", 6)
	pad.add_child(line)
	card.add_child(pad)


func _note(card: VBoxContainer, text: String) -> void:
	if card.get_child_count() > 0:
		card.add_child(HSeparator.new())
	var pad := MarginContainer.new()
	pad.add_theme_constant_override(&"margin_top", 12)
	pad.add_theme_constant_override(&"margin_bottom", 12)
	pad.add_child(kit.paragraph(text))
	card.add_child(pad)


func _card(title: String) -> VBoxContainer:
	var wrap := VBoxContainer.new()
	wrap.add_theme_constant_override(&"separation", 8)
	_body.add_child(wrap)

	if title != "":
		var head := MarginContainer.new()
		head.add_theme_constant_override(&"margin_top", 6)
		head.add_theme_constant_override(&"margin_left", 4)
		head.add_child(kit.section(title))
		wrap.add_child(head)

	var card := kit.card()
	wrap.add_child(card)

	var rows := VBoxContainer.new()
	rows.add_theme_constant_override(&"separation", 0)
	card.add_child(rows)
	return rows


## The value a row shows: the player's own for a setting (see the class note on clamps),
## the getter's for a live row.
func _value_of(row: DotMenuRow) -> Variant:
	if row.is_setting():
		return settings.chosen_value(row.key)
	return row.getter.call() if row.getter.is_valid() else null


func _write(row: DotMenuRow, value: Variant) -> void:
	if not row.is_setting():
		if row.setter.is_valid():
			row.setter.call(value)
		return
	if settings == null:
		return
	var res := settings.set_value(row.key, value)
	if not res.ok:
		toast(res.error.message)
		DotLog.warn(CHANNEL, "a setting was refused", {"key": String(row.key), "why": res.error.message})
		return
	setting_written.emit(row.key, value)


func _toggle(row: DotMenuRow) -> Control:
	var sw := DotMenuSwitch.new(kit)
	sw.show_value(bool(_value_of(row)))
	sw.disabled = not row.is_enabled()
	sw.toggled.connect(func(on: bool) -> void: _write(row, on))
	return sw


func _slider(row: DotMenuRow) -> Control:
	var def := settings.schema.find(row.key) if row.is_setting() and settings != null else null
	var r := row.slider_range(def)

	var box := HBoxContainer.new()
	box.add_theme_constant_override(&"separation", 12)

	var slider := HSlider.new()
	slider.name = "Slider"
	slider.min_value = r.x
	slider.max_value = r.y
	slider.step = r.z
	slider.custom_minimum_size = Vector2(190, 22)
	slider.focus_mode = Control.FOCUS_ALL
	slider.editable = row.is_enabled()
	var v: Variant = _value_of(row)
	slider.value = float(v) if v != null else r.x

	var readout := kit.label(row.show_value(slider.value), kit.size_small, kit.palette.muted)
	readout.name = "Readout"
	readout.custom_minimum_size = Vector2(52, 0)
	readout.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	var is_int := def != null and def.kind == DotSettingsDef.Kind.INT
	slider.value_changed.connect(func(value: float) -> void:
		readout.text = row.show_value(value)
		_write(row, roundi(value) if is_int else value)
	)

	box.add_child(slider)
	box.add_child(readout)
	return box


func _select(row: DotMenuRow) -> Control:
	var def := settings.schema.find(row.key) if row.is_setting() and settings != null else null
	var options := row.option_list(def)
	var current: Variant = _value_of(row)

	# A stored value the list does not offer — a cap typed at the console, an option from a
	# newer build — is added rather than shown as the first item, which would be a lie about
	# what is set.
	var listed := false
	for o in options:
		if str(o[0]) == str(current):
			listed = true
	if not listed and current != null and row.is_setting():
		options = options.duplicate()
		options.append([current, DotMenuRow.label_for_option(current)])

	var pick := OptionButton.new()
	pick.custom_minimum_size = Vector2(200, 36)
	pick.focus_mode = Control.FOCUS_ALL
	pick.fit_to_longest_item = true
	pick.disabled = not row.is_enabled()
	for i in range(options.size()):
		pick.add_item(str(options[i][1]), i)
		if str(options[i][0]) == str(current):
			pick.select(i)
	pick.item_selected.connect(func(index: int) -> void: _write(row, options[index][0]))
	return pick


func _key_button(row: DotMenuRow) -> Control:
	var button := DotMenuKeyButton.new(kit)
	button.binding = bindings.stored(row.binding_row, settings) if bindings != null else str(row.binding_row.get("default", ""))
	# An extra key may be on nothing, which the button draws as its dash.
	button.clearable = DotMenuBindings.is_extra(row.binding_row)
	if DotMenuBindings.is_none(button.binding):
		button.binding = ""
	button.captured.connect(func(text: String) -> void: _rebind(row.binding_row, text))
	return button


func _rebind(binding_row: Dictionary, text: String) -> void:
	if bindings == null:
		return
	var res := bindings.rebind(binding_row, text, settings)
	toast(str(res.value) if res.ok else res.error.message)
	_show_page(_page)


func _reset_bindings() -> void:
	if bindings == null:
		return
	bindings.reset_all(settings)
	toast("Every key is back on its default.")
	_show_page(_page)


func describe() -> Dictionary:
	return {
		"open": visible, "page": String(_page), "pages": visible_pages().size(),
		"hidden_rows": Array(extra_hidden_rows), "hidden_pages": Array(extra_hidden_pages),
	}
