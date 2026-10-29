class_name DotMenu
extends CanvasLayer

## A game's menus, in one node: the Escape menu, help, a picker, the HUD layout editor, a frame-rate counter, the [DotMenuNetStat] overlay, and the theme they are drawn in. Example: docs/examples.md.
## It owns which overlay is open, what Escape does, who has the pointer and the theme, one list in one place. In a browser Escape exits pointer lock and may not arrive, so
## [member DotMenuConfig.open_on_pointer_release] opens the menu on a lost lock. Not a pause (see [DotMenuScreen]); [signal overlays_changed] is how a game stops its sampler.

const CHANNEL := "menu"

## The menu, or any overlay, opened or the last one closed.
signal overlays_changed(open: bool)

## A sidebar action: &"help" is handled here (it opens help); &"leave" is handled here too
## when [member leave_on_its_own] is set, and is the game's otherwise, as a game's own are.
signal action_requested(id: StringName)

## The theme changed. A HUD that draws in the palette recolours from this.
signal theme_changed(palette: DotMenuPalette)

## The pointer was not recaptured after the menu closed — in a browser, because the close
## was a key. The game says "Click to play".
signal click_to_play()

## A picker row was chosen.
signal picked(id: StringName)

var settings: DotSettingsManager = null
var bindings: DotMenuBindings = null
var config: DotMenuConfig = null

## The theme catalogue. Null at setup is the stock seven, plus the config's file.
var themes: DotMenuThemes = null

## The pages, in sidebar order. Null at setup is [method DotMenuStock.pages].
var pages: Array[DotMenuPage] = []

## The kit everything is drawn with now. Replaced, not changed, on a theme change.
var kit: DotMenuKit = null

## Actions that, pressed with nothing open, open help and cycle the theme. Empty is none.
## Help is on H in every game unless it says otherwise ([constant DotMenuBindings.HELP_ACTION]); a game with no table row still gets H,
## because [method setup] puts the action on the InputMap and the help screen lists it.
var help_action: StringName = DotMenuBindings.HELP_ACTION
var theme_action: StringName = &""

## The action held to show the scoreboard (Tab). Empty is no scoreboard key; the board is
## still built and can be opened in code.
var scoreboard_action: StringName = &""

## The action that opens the picker in this game (a taunt list), which also closes it.
## The menu does not open the picker on it — what the list holds is the game's to fetch.
var picker_action: StringName = &""

## The map menu's key (API 5): M, [constant DotMenuBindings.MAPS_ACTION], in every game with
## more than one map. Pressed with nothing open it opens [member maps]; pressed again it closes
## the picker. Nothing happens on it until the game calls [method use_maps].
var maps_action: StringName = DotMenuBindings.MAPS_ACTION

## The map menu. Null until [method use_maps]. See [DotMenuMaps].
var maps: DotMenuMaps = null

## The loadout menu's key (API 6): B, [constant DotMenuBindings.LOADOUT_ACTION], in every game where
## players choose what they carry. Pressed with nothing open it opens [member loadout]; pressed
## again it closes the screen, which saves. Nothing happens on it until [method use_loadout].
var loadout_action: StringName = DotMenuBindings.LOADOUT_ACTION

## The loadout menu, and its screen. Null until [method use_loadout]. See [DotMenuLoadout].
var loadout: DotMenuLoadout = null
var loadout_screen: DotMenuLoadoutScreen = null

## Handle Escape and the actions above from [method Node._unhandled_input]. Off for a host
## that routes input itself through [method handle_event].
var handle_keys: bool = true

## Whether Escape, with nothing open, opens the menu. Off for a game whose Escape is its own
## (a garage, a lobby) and that opens the menu some other way; Escape still closes the menu
## and everything over it.
var open_on_escape: bool = true

## Free the pointer while anything is open and capture it when the last thing closes.
var manage_pointer: bool = true

## `func() -> bool`: true when the game has the keyboard for something else — a chat line, a
## console — so Escape and the keys above are left to it, and a pointer it freed does not
## open the menu.
var busy: Callable = Callable()

## Leave does the stock thing itself: disconnects from the server when connected, and quits a
## solo game on the desktop. Off, Leave is only [signal action_requested] (a game that leaves
## its own way). [DotMenuSettings] turns it on.
var leave_on_its_own: bool = false

## What Leave disconnects: anything with `disconnect_from_server(reason)` and
## `is_connected_to_server()`. Null looks up [member leave_service] in [DotRegistry] when Leave
## is pressed, so a link made after the menu is still the one left.
var leave_link: Object = null
var leave_service: StringName = &"dot_client_link"

var screen: DotMenuScreen = null
var help: DotMenuHelp = null
var picker: DotMenuPicker = null
var layout_editor: DotMenuLayoutEditor = null

## The held scoreboard. Not one of the overlays: see [DotMenuScoreboard].
var scoreboard: DotMenuScoreboard = null

## The connection overlay, driven by the `net_stat*` settings. See [DotMenuNetStat].
var net_stat: DotMenuNetStat = null

var _fps_label: Label = null

## The HUD's "H  Help" hint ([member DotMenuConfig.help_hint]); null when off. Shown while
## nothing is open, with the key as it is bound now.
var help_hint: PanelContainer = null

## The short line [method toast] shows; null until the first one.
var toast_plate: PanelContainer = null
## Where the toast's top edge sits, in pixels from the top. A game whose HUD draws a strip
## there (scores, clock, mode label) sets this below it; read each time a toast is shown.
var toast_top := 64.0
var _toast_serial := 0
## The action that closes the picker that is open now, and who gets its choice: the map menu
## opens the same picker a game's own list does, and its choice must not reach the game's
## [signal picked] handler (a taunt list taking a map id as a taunt).
var _picker_close: StringName = &""
var _picker_chosen: Callable = Callable()
## Other overlays a game registered: Controls with is_open() and close().
var _extra: Array[Control] = []

## The player's addon cfg editor, once [method use_mods] gave one.
var mods_screen: DotAddonConfigEditorScreen = null
var mods_label := "Mods"
var _theme_id: StringName = &""
var _was_open := false
var _lock_seen := false
var _opened_msec := 0
var _recapture_frames := 0
var _server_rules: Dictionary = {}
## reason -> rows hidden for it ([method hide_rows]).
var _hidden_by: Dictionary = {}
var _ready_done := false
## The HUDs [method follow_hud] keeps in the theme and at the player's size:
## `{"root": WeakRef, "accent": Theme, "scaled": bool, "fitted": bool}`.
var _huds: Array[Dictionary] = []


func _init() -> void:
	name = "Menu"


## Builds everything. Settings must be set up first: the theme and the frame-rate counter
## read them now.
func setup() -> DotResult:
	if config == null:
		config = DotMenuConfig.new()
	layer = config.layer

	themes = config.make_themes(themes)
	_check_theme_setting()

	if pages.is_empty():
		pages = DotMenuStock.pages(config)
	_wire_stock_rows()
	_ensure_help_action()

	_theme_id = _stored_theme()
	kit = DotMenuKit.new(themes.named(_theme_id)) if kit == null else kit.with_palette(themes.named(_theme_id))

	_build()

	if settings != null and not settings.changed.is_connected(_on_setting_changed):
		settings.changed.connect(_on_setting_changed)
	_apply_net_stat()
	scoreboard.read_settings(settings)
	# A HUD followed before setup was drawn in the default palette; now the player's.
	_style_huds()
	_scale_huds()
	_ready_done = true
	return DotResult.success(self)


func _build() -> void:
	if screen != null:
		return

	_fps_label = kit.label("", kit.size_small, kit.palette.muted, true)
	_fps_label.name = "Fps"
	_fps_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_fps_label.offset_left = -110.0
	_fps_label.offset_right = -14.0
	_fps_label.offset_top = 10.0
	_fps_label.offset_bottom = 30.0
	_fps_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_fps_label.add_theme_constant_override(&"outline_size", 4)
	_fps_label.add_theme_color_override(&"font_outline_color", Color(0, 0, 0, 0.7))
	_fps_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fps_label.visible = false
	add_child(_fps_label)

	net_stat = DotMenuNetStat.new()
	net_stat.kit = kit
	add_child(net_stat)

	_build_help_hint()

	# Under everything else on this layer: the menu opened over a held board is on top.
	scoreboard = DotMenuScoreboard.new()
	scoreboard.name = "Scoreboard"
	scoreboard.kit = kit
	add_child(scoreboard)

	screen = DotMenuScreen.new()
	screen.name = "Screen"
	screen.kit = kit
	screen.settings = settings
	screen.bindings = bindings
	screen.config = config
	screen.pages = pages
	screen.actions = _actions()
	screen.closed.connect(_on_closed)
	screen.action_requested.connect(_on_action)
	add_child(screen)

	layout_editor = DotMenuLayoutEditor.new()
	layout_editor.name = "LayoutEditor"
	layout_editor.kit = kit
	layout_editor.closed.connect(_on_closed)
	add_child(layout_editor)

	picker = DotMenuPicker.new()
	picker.name = "Picker"
	picker.kit = kit
	picker.closed.connect(_on_closed)
	picker.chosen.connect(_on_picker_chosen)
	add_child(picker)

	help = DotMenuHelp.new()
	help.name = "Help"
	help.kit = kit
	help.bindings = bindings
	help.config = config
	help.help_action = help_action
	var extra: Array = [["Esc", "Menu and settings"]]
	if _help_off_the_table():
		extra.push_front([DotInputBinding.describe_action(help_action), "Help and controls"])
	help.extra_keys = {_last_group(): extra}
	help.closed.connect(_on_closed)
	add_child(help)
	_refresh_help_hint()


func _actions() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if config.show_help:
		out.append({"id": &"help", "text": "Help & commands"})
	if mods_screen != null:
		out.append({"id": &"mods", "text": mods_label})
	if config.show_leave:
		out.append({"id": &"leave", "text": leave_label(), "danger": true})
	return out


## The help action on the InputMap, on H, when nothing else put it there: a game with no key
## table, or a table with no row for it. Never over a binding the table applied.
func _ensure_help_action() -> void:
	if help_action == &"" or InputMap.has_action(help_action):
		return
	InputMap.add_action(help_action)
	var _bound := DotInputBinding.apply(help_action, DotMenuBindings.HELP_KEY)


## The HUD's help hint: a keycap and "Help" on a quiet plate, in the corner the config names.
## A plate rather than bare text because a HUD hint is read over whatever the map is, and
## the light maps are where a bare label disappears (the first play test's complaint).
func _build_help_hint() -> void:
	var where := config.help_hint
	if where == &"off" or where == &"" or help_action == &"":
		return
	var p := kit.palette
	help_hint = PanelContainer.new()
	help_hint.name = "HelpHint"
	help_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	help_hint.add_theme_stylebox_override(&"panel", kit.box(Color(p.surface, 0.72), 8, p.line, 1, Vector4(6, 4, 10, 4)))
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	help_hint.add_child(row)
	var cap := kit.keycap("H")
	cap.name = "Key"
	row.add_child(cap)
	var l := kit.label("Help", kit.size_small, p.text, true)
	l.name = "Text"
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(l)
	var top := where == &"top_right" or where == &"top_left"
	var right := where == &"top_right" or where == &"bottom_right"
	help_hint.set_anchors_preset(
		(Control.PRESET_TOP_RIGHT if right else Control.PRESET_TOP_LEFT) if top
		else (Control.PRESET_BOTTOM_RIGHT if right else Control.PRESET_BOTTOM_LEFT))
	help_hint.grow_horizontal = Control.GROW_DIRECTION_BEGIN if right else Control.GROW_DIRECTION_END
	help_hint.grow_vertical = Control.GROW_DIRECTION_END if top else Control.GROW_DIRECTION_BEGIN
	var x := -14.0 if right else 14.0
	# Under the frame counter in the top corner, which is where that sits.
	var y := 36.0 if top else -14.0
	help_hint.offset_left = x
	help_hint.offset_right = x
	help_hint.offset_top = y
	help_hint.offset_bottom = y
	add_child(help_hint)
	_refresh_help_hint()


## The hint's key as bound now, and whether it shows: not while anything is open, not when
## the help key is on nothing.
func _refresh_help_hint() -> void:
	if help_hint == null or help == null:
		return
	var k := help.help_key_shown()
	var label := help_hint.find_child("Key", true, false)
	if label != null and k != "":
		((label as PanelContainer).get_child(0) as Label).text = k
	help_hint.visible = k != "" and not any_open()


## Whether the help key is in no table row, so the help screen has to list it by hand.
func _help_off_the_table() -> bool:
	return help_action != &"" and InputMap.has_action(help_action) \
		and (bindings == null or bindings.row_for_action(help_action).is_empty())


## The group Escape's help line goes in: the last one, which in the stock order is the
## interface keys.
func _last_group() -> String:
	var groups := bindings.groups() if bindings != null else PackedStringArray()
	return groups[groups.size() - 1] if not groups.is_empty() else "Interface"


## The stock theme row offers the themes as they are named, not as ids, and only those the
## catalogue still has — the config may have narrowed it after the schema was declared.
func _wire_stock_rows() -> void:
	for p in pages:
		var board_section := p.find_section(&"scoreboard")
		if board_section != null and not board_section.rows_from.is_valid():
			board_section.rows_from = scoreboard_column_rows
		var theme_row := p.find_row(&"ui_theme")
		if theme_row != null and theme_row.options.is_empty():
			theme_row.options = themes.options()
			if theme_action != &"" and bindings != null:
				var key_action := theme_action
				theme_row.described_by(func() -> String:
					return "The menus and the HUD. %s cycles through them." % bindings.key_for(key_action))


## Says so when the `ui_theme` setting cannot hold a theme the menu offers: a player who
## picked it would be refused. The fix is passing the catalogue to
## [method DotMenuConfig.apply_to_schema] before the settings load.
func _check_theme_setting() -> void:
	if settings == null or settings.schema == null:
		return
	var def := settings.schema.find(&"ui_theme")
	if def == null:
		return
	var missing := PackedStringArray()
	for id in themes.ids():
		if not def.options.has(id):
			missing.append(String(id))
	if not missing.is_empty():
		DotLog.warn(CHANNEL, "the ui_theme setting cannot hold every theme; pass the catalogue to DotMenuConfig.apply_to_schema", {
			"missing": ", ".join(missing),
		})


## The page called [param id], or null.
func page(id: StringName) -> DotMenuPage:
	for p in pages:
		if p.id == id:
			return p
	return null


## Adds [param p] before the page called [param before], or at the end. A page with the same
## id is replaced in place.
func add_page(p: DotMenuPage, before: StringName = &"") -> DotMenuPage:
	for i in range(pages.size()):
		if pages[i].id == p.id:
			pages[i] = p
			return p
	for i in range(pages.size()):
		if pages[i].id == before:
			pages.insert(i, p)
			return p
	pages.append(p)
	return p


func remove_page(id: StringName) -> bool:
	for i in range(pages.size()):
		if pages[i].id == id:
			pages.remove_at(i)
			return true
	return false


## The row called [param row_id] on whichever page has it, or null.
func find_row(row_id: StringName) -> DotMenuRow:
	for p in pages:
		var r := p.find_row(row_id)
		if r != null:
			return r
	return null


func open(page_id: StringName = &"") -> void:
	if screen == null:
		return
	_refresh_leave()
	for o in [help, picker, layout_editor]:
		if o != null and o.is_open():
			o.visible = false
	if scoreboard != null:
		scoreboard.close()
	screen.open(page_id)
	_on_opened()


func close() -> void:
	if screen != null:
		screen.close()


func is_open() -> bool:
	return screen != null and screen.is_open()


## Opens help, over the menu if the menu is open — closing it goes back there.
func open_help(commands: Variant = null, online: Variant = null) -> void:
	if help == null:
		return
	if commands != null:
		help.commands = commands
	if online != null:
		help.online = bool(online)
	help.open()
	_on_opened()


## A list to pick from. See [DotMenuPicker]. [signal picked] says what was chosen, unless
## [param on_chosen] is given, which then gets it instead. [param close_action] is the key that
## closes this list (the key that opened it); empty is [member picker_action].
func open_picker(items: Array, title: String = "", close_action: StringName = &"", on_chosen: Callable = Callable()) -> void:
	if picker == null:
		return
	if screen.is_open():
		screen.visible = false
	_picker_close = close_action if close_action != &"" else picker_action
	_picker_chosen = on_chosen
	picker.open(items, title)
	_on_opened()


func _on_picker_chosen(id: StringName) -> void:
	var to := _picker_chosen
	_picker_chosen = Callable()
	if to.is_valid():
		to.call(id)
	else:
		picked.emit(id)


## Turns the map menu on: M opens a picker of what [param rows_fn] returns (`func() -> Array` of `{id, name, mode, detail, thumbnail, current, tags}`),
## and solo a choice goes to [param change_fn] (`func(id) -> DotResult`). Connected, the server is asked instead (see [DotMenuMaps]).
## Puts [member maps_action] on M when no table row did, and lists it on the help screen by hand.
func use_maps(rows_fn: Callable, change_fn: Callable) -> DotMenuMaps:
	if maps == null:
		maps = DotMenuMaps.new()
	maps.menu = self
	maps.rows_fn = rows_fn
	maps.change_fn = change_fn
	maps.enabled = true
	if maps_action != &"" and not InputMap.has_action(maps_action):
		InputMap.add_action(maps_action)
		var _bound := DotInputBinding.apply(maps_action, DotMenuBindings.MAPS_KEY)
	if help != null and maps_action != &"" and (bindings == null or bindings.row_for_action(maps_action).is_empty()):
		var extra: Dictionary = help.extra_keys
		var group := _last_group()
		var lines: Array = extra.get(group, [])
		var shown := DotInputBinding.describe_action(maps_action)
		if not lines.any(func(l: Variant) -> bool: return l is Array and (l as Array).size() > 1 and str((l as Array)[1]) == "Change map"):
			lines.push_front([shown, "Change map"])
		extra[group] = lines
		help.extra_keys = extra
	return maps


## Opens the map menu, as M does. Nothing without [method use_maps].
func open_maps() -> void:
	if maps != null and maps.enabled:
		maps.open()


## Turns the loadout menu on: B opens [DotMenuLoadoutScreen] on what [param offer_fn] returns (`func() -> Dictionary or DotResult`, may await);
## solo a choice goes to [param choose_fn] (`func(picks: Dictionary) -> DotResult or {ok, text, now}`), and [param decorate_fn] (`func(slot_id, choice) -> Dictionary`) adds icon and stats.
## Connected, the server is asked instead (see [DotMenuLoadout]). Puts [member loadout_action] on B when no table row did.
func use_loadout(offer_fn: Callable, choose_fn: Callable, decorate_fn: Callable = Callable()) -> DotMenuLoadout:
	if loadout == null:
		loadout = DotMenuLoadout.new()
	loadout.menu = self
	loadout.offer_fn = offer_fn
	loadout.choose_fn = choose_fn
	loadout.decorate_fn = decorate_fn
	loadout.enabled = true
	if loadout_screen == null:
		loadout_screen = DotMenuLoadoutScreen.new()
		loadout_screen.name = "Loadout"
		loadout_screen.kit = kit if kit != null else DotMenuKit.new()
		loadout_screen.closed.connect(_on_closed)
		loadout_screen.committed.connect(func(picks: Dictionary) -> void: loadout.commit(picks))
		loadout_screen.random_requested.connect(func() -> void: loadout.request_random())
		add_child(loadout_screen)
	if loadout_action != &"" and not InputMap.has_action(loadout_action):
		InputMap.add_action(loadout_action)
		var _bound := DotInputBinding.apply(loadout_action, DotMenuBindings.LOADOUT_KEY)
	if help != null and loadout_action != &"" and (bindings == null or bindings.row_for_action(loadout_action).is_empty()):
		var extra: Dictionary = help.extra_keys
		var group := _last_group()
		var lines: Array = extra.get(group, [])
		var shown := DotInputBinding.describe_action(loadout_action)
		if not lines.any(func(l: Variant) -> bool: return l is Array and (l as Array).size() > 1 and str((l as Array)[1]) == "Loadout"):
			lines.push_front([shown, "Loadout"])
		extra[group] = lines
		help.extra_keys = extra
	return loadout


## Opens the loadout menu, as B does. Nothing without [method use_loadout].
func open_loadout() -> void:
	if loadout != null and loadout.enabled:
		loadout.open()


## Shows the loadout screen on [param offer], over anything else this owns.
func open_loadout_screen(offer: Dictionary) -> void:
	if loadout_screen == null:
		return
	for o in [picker, help, layout_editor]:
		if o != null and o.is_open():
			o.close()
	if screen != null and screen.is_open():
		screen.close()
	loadout_screen.toggle_action = loadout_action
	move_child(loadout_screen, get_child_count() - 1)
	loadout_screen.open(offer)
	_on_opened()


## A short line at the top of the screen for [param seconds]: the map menu's "Changing the map
## here needs …", "Nominated Atrium. Rocked: 1 of 3." A plate rather than chat, because the
## player pressed a key and is looking at the screen, not at the chat box.
func toast(text: String, seconds: float = 3.5) -> void:
	if text == "" or kit == null:
		return
	if toast_plate == null:
		toast_plate = PanelContainer.new()
		toast_plate.name = "Toast"
		toast_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
		toast_plate.set_anchors_preset(Control.PRESET_CENTER_TOP)
		toast_plate.grow_horizontal = Control.GROW_DIRECTION_BOTH
		var l := kit.label("", kit.size_body, kit.palette.text, true)
		l.name = "Text"
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		toast_plate.add_child(l)
		add_child(toast_plate)
	var p := kit.palette
	toast_plate.add_theme_stylebox_override(&"panel", kit.box(Color(p.surface, 0.92), 10, p.accent, 1, Vector4(16, 8, 16, 8)))
	var label := toast_plate.get_node("Text") as Label
	label.add_theme_color_override(&"font_color", p.text)
	label.text = text
	toast_plate.offset_top = toast_top
	toast_plate.offset_bottom = toast_top
	toast_plate.visible = true
	move_child(toast_plate, get_child_count() - 1)
	_toast_serial += 1
	var serial := _toast_serial
	if is_inside_tree() and seconds > 0.0:
		get_tree().create_timer(seconds).timeout.connect(_expire_toast.bind(serial))


func _expire_toast(serial: int) -> void:
	if serial == _toast_serial and toast_plate != null:
		toast_plate.visible = false


## What the toast says now; empty when none is up.
func toast_text() -> String:
	return (toast_plate.get_node("Text") as Label).text if toast_plate != null and toast_plate.visible else ""


## The HUD layout editor over [param target]. See [DotMenuLayoutEditor].
func open_layout_editor(target: Control, pieces: Dictionary = {}) -> void:
	if layout_editor == null:
		return
	if screen.is_open():
		screen.visible = false
	layout_editor.target = target
	if not pieces.is_empty():
		layout_editor.pieces = pieces
	layout_editor.open()
	_on_opened()


## Registers a game's own overlay — any Control with `is_open()` and `close()`, and a
## `closed` signal — so Escape closes it, it counts as open for the pointer and the sampler,
## and a theme change restyles it if it has `restyle(kit)`.
func add_overlay(overlay: Control) -> void:
	if overlay == null or _extra.has(overlay):
		return
	_extra.append(overlay)
	if overlay.has_signal(&"closed"):
		overlay.connect(&"closed", _on_closed)


## Adds a "Mods" action to Escape that opens [param editor] (files added by the caller) over the menu.
## Solo and listen-host only: the editor says why when the user tier is off.
func use_mods(editor: DotAddonConfigEditorScreen, label: String = "Mods") -> void:
	mods_screen = editor
	mods_label = label
	editor.visible = false
	editor.set_anchors_preset(Control.PRESET_FULL_RECT)
	if editor.get_parent() != self:
		if editor.get_parent() != null:
			editor.get_parent().remove_child(editor)
		add_child(editor)
	add_overlay(editor)
	if screen != null:
		screen.actions = _actions()
		screen.restyle(kit)


func open_mods() -> void:
	if mods_screen == null:
		return
	if screen != null and screen.is_open():
		screen.close()
	move_child(mods_screen, get_child_count() - 1)
	mods_screen.open_screen()
	_on_opened()


## Call after opening a registered overlay, so the pointer is freed and the grace starts.
func overlay_opened() -> void:
	_on_opened()


## Whether anything this owns, or a registered overlay, is open.
func any_open() -> bool:
	for o in _overlays():
		if o != null and o.visible and (not o.has_method(&"is_open") or bool(o.call(&"is_open"))):
			return true
	return false


func close_all() -> void:
	for o in _overlays():
		if o != null and o.has_method(&"is_open") and bool(o.call(&"is_open")):
			o.call(&"close")


func _overlays() -> Array[Control]:
	var out: Array[Control] = [layout_editor, picker, help, screen]
	if loadout_screen != null:
		out.push_front(loadout_screen)
	out.append_array(_extra)
	return out


func _on_opened() -> void:
	_opened_msec = Time.get_ticks_msec()
	_lock_seen = false
	if manage_pointer:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_notify()


## The last overlay closed: give the pointer back to the view. On the desktop that is
## immediate; in a browser it works when the close was a click and is refused when it was a
## key — see the class note.
func _on_closed() -> void:
	if any_open():
		return
	if manage_pointer:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		if DotPlatform.is_web():
			_recapture_frames = 12
	_notify()


func _notify() -> void:
	_refresh_help_hint()
	var now := any_open()
	if now != _was_open:
		_was_open = now
		overlays_changed.emit(now)


func _on_action(id: StringName) -> void:
	if id == &"help":
		open_help()
	elif id == &"mods":
		open_mods()
	action_requested.emit(id)
	if id == &"leave" and leave_on_its_own:
		leave()


## The stock Leave: off the server when connected, the whole program in a solo desktop game.
## A page cannot close a browser tab, and a quit there is a frozen canvas, so offline in a
## browser it only closes the menu ([method leave_label] hides the button).
func leave() -> void:
	close_all()
	var link := _leave_link()
	if link != null and _connected(link):
		link.call(&"disconnect_from_server", "Left the server")
		return
	if not DotPlatform.is_web():
		get_tree().quit()


## What the Leave button says right now. With [member leave_on_its_own]: "Leave server"
## connected, "Quit game" solo on a desktop, nothing (hidden) solo in a browser. Otherwise the
## config's text, which a game that leaves its own way words itself.
func leave_label() -> String:
	if not leave_on_its_own:
		return config.leave_text
	if _connected(_leave_link()):
		return "Leave server"
	return "" if DotPlatform.is_web() else "Quit game"


func _refresh_leave() -> void:
	if screen == null or not leave_on_its_own or _server_rules.has("leave_text"):
		return
	screen.set_action_text(&"leave", leave_label())


func _leave_link() -> Object:
	if leave_link != null and is_instance_valid(leave_link):
		return leave_link
	if leave_service == &"":
		return null
	return DotRegistry.get_node_service(leave_service)


static func _connected(link: Object) -> bool:
	if link == null or not is_instance_valid(link) or not link.has_method(&"disconnect_from_server"):
		return false
	return not link.has_method(&"is_connected_to_server") or bool(link.call(&"is_connected_to_server"))


func _unhandled_input(event: InputEvent) -> void:
	if handle_keys and handle_event(event):
		get_viewport().set_input_as_handled()


## Escape, help and the theme key, and the picker's number keys while it is open. True when the event was the menu's.
## For a host that routes input itself; [member handle_keys] does this otherwise.
## An open overlay owns the keyboard: no key may fall through to the game (R behind a menu is a restart nobody asked for).
func handle_event(event: InputEvent) -> bool:
	# The scoreboard is HELD: it goes away on the release, whatever else is going on — a
	# board left up because the release arrived while the chat line had the keyboard is a
	# board the player cannot get rid of.
	if scoreboard != null and scoreboard.is_open() and _is_scoreboard_key(event) and not event.is_pressed():
		scoreboard.close()
		return true

	if not (event is InputEventKey) or not event.is_pressed() or event.is_echo():
		return any_open() and event is InputEventKey
	var key := event as InputEventKey
	var escape := key.physical_keycode == KEY_ESCAPE

	if not any_open():
		if busy.is_valid() and bool(busy.call()):
			return false
		if _is_scoreboard_key(event):
			if scoreboard != null:
				scoreboard.open()
			return true
		if escape and open_on_escape:
			if scoreboard != null:
				scoreboard.close()
			open()
			return true
		if help_action != &"" and InputMap.has_action(help_action) and event.is_action_pressed(help_action):
			open_help()
			return true
		if theme_action != &"" and InputMap.has_action(theme_action) and event.is_action_pressed(theme_action):
			var _next := cycle_theme()
			return true
		if maps != null and maps.enabled and maps_action != &"" and InputMap.has_action(maps_action) \
				and event.is_action_pressed(maps_action):
			maps.open()
			return true
		if loadout != null and loadout.enabled and loadout_action != &"" and InputMap.has_action(loadout_action) \
				and event.is_action_pressed(loadout_action):
			loadout.open()
			return true
		return false

	# The same Escape that took the pointer away in a browser can arrive a moment after the
	# menu it opened; closing on it would make the menu flash and vanish.
	if escape and Time.get_ticks_msec() - _opened_msec < config.escape_grace_ms:
		return true

	if loadout_screen != null and loadout_screen.is_open():
		# Its own keys were read in its _input; what is left is the menu's to swallow.
		if escape:
			loadout_screen.close()
		return true

	if layout_editor.is_open():
		if escape:
			layout_editor.close()
		return true

	if picker.is_open():
		if escape or (_picker_close != &"" and InputMap.has_action(_picker_close) and event.is_action_pressed(_picker_close)):
			picker.close()
		else:
			var _mine := picker.key(key.keycode)
		return true

	if help.is_open():
		if escape or (help_action != &"" and InputMap.has_action(help_action) and event.is_action_pressed(help_action)):
			help.close()
		return true

	for o in _extra:
		if o.visible and o.has_method(&"is_open") and bool(o.call(&"is_open")):
			if escape:
				o.call(&"close")
			return true

	if screen.is_open() and escape:
		screen.close()
	return true


func _is_scoreboard_key(event: InputEvent) -> bool:
	return scoreboard_action != &"" and InputMap.has_action(scoreboard_action) \
		and event.is_action(scoreboard_action)


func _process(_delta: float) -> void:
	if _fps_label != null and _fps_label.visible:
		_fps_label.text = "%d fps" % Engine.get_frames_per_second()
	if manage_pointer and _ready_done:
		_watch_pointer()


## See the class note on the pointer in a browser.
func _watch_pointer() -> void:
	var captured := Input.mouse_mode == Input.MOUSE_MODE_CAPTURED

	if _recapture_frames > 0:
		_recapture_frames -= 1
		if _recapture_frames == 0 and not captured and not any_open():
			click_to_play.emit()

	if captured:
		_lock_seen = true
		return

	if _lock_seen and config.open_on_pointer_release and not any_open() \
			and not (busy.is_valid() and bool(busy.call())):
		_lock_seen = false
		open()


## Forget a lock seen: the game freed the pointer on purpose (a chat line, a loading screen)
## and the menu should not open for it.
func pointer_released_on_purpose() -> void:
	_lock_seen = false


## The theme in use.
func palette() -> DotMenuPalette:
	return kit.palette if kit != null else themes.named(&"")


## Moves to the next theme, stores it, and returns its id.
func cycle_theme() -> StringName:
	var next := themes.next(_theme_id)
	if settings != null and settings.schema != null and settings.schema.has(&"ui_theme"):
		var res := settings.set_value(&"ui_theme", next)
		if not res.ok:
			DotLog.warn(CHANNEL, "the theme was refused", {"theme": String(next), "why": res.error.message})
	else:
		use_theme(next)
	return next


## Draws everything in [param id] now. Returns whether anything changed; the screens are
## rebuilt only when it did, because every settings change lands in the handler that calls
## this.
func use_theme(id: StringName) -> bool:
	var p := themes.named(id)
	if kit != null and kit.palette == p:
		return false
	_theme_id = p.id
	kit = kit.with_palette(p) if kit != null else DotMenuKit.new(p)
	for o in _overlays():
		# The mods editor restyles from DotFormTokens, not a kit.
		if o != null and o != mods_screen and o.has_method(&"restyle"):
			o.call(&"restyle", kit)
	if scoreboard != null:
		scoreboard.restyle(kit)
	if _fps_label != null:
		_fps_label.add_theme_color_override(&"font_color", p.muted)
	if help_hint != null:
		var where := help_hint.get_index()
		help_hint.queue_free()
		help_hint = null
		_build_help_hint()
		if help_hint != null:
			move_child(help_hint, mini(where, get_child_count() - 1))
	if net_stat != null:
		net_stat.restyle(kit)
	_style_huds()
	theme_changed.emit(p)
	return true


## Keeps [param root], a game's HUD layer, in the theme and at the player's `hud_scale`: its [Theme] is [method DotMenuPalette.hud_theme] with [param accent] laid over it,
## set now and on every theme change, so no game has to wire [signal theme_changed] itself. Nothing is rebuilt: a piece reads its colours when it draws.
## With [param scaled] the HUD is drawn at `hud_scale` ([DotHud] `user_scale`, or [method DotHud.fit_control]); a root laid out by hand passes false.
func follow_hud(root: Control, accent: Theme = null, scaled: bool = true) -> void:
	if root == null:
		return
	for entry in _huds:
		if (entry["root"] as WeakRef).get_ref() == root:
			entry["accent"] = accent
			entry["scaled"] = scaled
			_style_hud(entry)
			_scale_hud(entry)
			return
	var added := {"root": weakref(root), "accent": accent, "scaled": scaled, "fitted": false}
	_huds.append(added)
	_style_hud(added)
	_scale_hud(added)


## Stops following [param root]; what it was given stays.
func unfollow_hud(root: Control) -> void:
	for i in range(_huds.size() - 1, -1, -1):
		var held: Object = (_huds[i]["root"] as WeakRef).get_ref()
		if held == null or held == root:
			_huds.remove_at(i)


## Every HUD root still followed. What a check reads.
func followed_huds() -> Array[Control]:
	var out: Array[Control] = []
	for entry in _huds:
		var held := (entry["root"] as WeakRef).get_ref() as Control
		if held != null:
			out.append(held)
	return out


## The player's HUD size: `hud_scale`, 1 where it is not declared.
func hud_scale() -> float:
	if _declared(&"hud_scale"):
		return clampf(settings.get_float(&"hud_scale", 1.0), 0.25, 4.0)
	return 1.0


func _style_huds() -> void:
	for entry in _huds:
		_style_hud(entry)


func _style_hud(entry: Dictionary) -> void:
	var root := (entry["root"] as WeakRef).get_ref() as Control
	if root == null:
		return
	var p: DotMenuPalette = palette() if (kit != null or themes != null) else DotMenuPalette.new()
	root.theme = p.hud_theme(entry["accent"] as Theme)


func _scale_huds() -> void:
	for entry in _huds:
		_scale_hud(entry)


func _scale_hud(entry: Dictionary) -> void:
	var root := (entry["root"] as WeakRef).get_ref() as Control
	if root == null or not bool(entry["scaled"]):
		return
	var k := hud_scale()
	if &"user_scale" in root:
		root.set(&"user_scale", k)
		return
	# A plain root is left exactly as the game laid it out until a size other than 1 is
	# asked for, and put back on full-rect anchors when 1 is asked for again.
	if is_equal_approx(k, 1.0) and not bool(entry["fitted"]):
		return
	if not root.is_inside_tree():
		return
	var vp := root.get_viewport()
	if not bool(entry["fitted"]):
		entry["fitted"] = true
		if not vp.size_changed.is_connected(_scale_huds):
			vp.size_changed.connect(_scale_huds)
	if is_equal_approx(k, 1.0):
		root.scale = Vector2.ONE
		root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		entry["fitted"] = false
		return
	DotHud.fit_control(root, vp.get_visible_rect().size, k)


func _stored_theme() -> StringName:
	if settings != null and settings.schema != null and settings.schema.has(&"ui_theme"):
		return StringName(settings.get_string(&"ui_theme", String(themes.default_id())))
	return themes.default_id()


## The settings this node applies itself. Key bindings among them: the menu is where a key
## is rebound, and a game using it without a [DotMenuApplier] would otherwise store the new
## key and go on reading the old one. Applying a binding twice is harmless.
func _on_setting_changed(key: StringName, value: Variant, _why: StringName) -> void:
	match key:
		&"ui_theme":
			var _changed := use_theme(_stored_theme())
		&"hud_scale":
			_scale_huds()
		&"show_fps", &"net_stat", &"net_stat_height", &"net_stat_position":
			_apply_net_stat()
		DotMenuScoreboard.SETTING:
			if scoreboard != null:
				scoreboard.read_settings(settings)
		_:
			if bindings != null:
				var _bound := bindings.apply_setting(key, value)
				_refresh_help_hint()


## The frame counter and net_stat together, because they share a corner and a number:
## net_stat shows the frame rate itself, so the counter steps aside while it is up rather
## than printing the same figure twice, one over the other in the top-right corner.
func _apply_net_stat() -> void:
	var level := 0
	if net_stat != null and config.net_stat:
		level = net_stat.read_settings(settings)
	if _fps_label != null:
		_fps_label.visible = config.fps_counter and level == 0 and _declared(&"show_fps") \
			and settings.get_bool(&"show_fps", false)


## One switch per column the live scoreboard has and a player may hide, titled as the board
## titles it. Built each time the page is drawn, since a game sets its columns after the menu
## exists. Writes `scoreboard_hidden`, and [method _on_setting_changed] redraws an open board.
func scoreboard_column_rows() -> Array[DotMenuRow]:
	var out: Array[DotMenuRow] = []
	if scoreboard == null or not _declared(DotMenuScoreboard.SETTING):
		return out
	for c in scoreboard.optional_columns():
		var key := StringName(str(c.get("key", "")))
		var shown_row := DotMenuRow.live_toggle(str(c.get("title", "")), "",
			func() -> bool: return not scoreboard.column_hidden(c),
			func(on: bool) -> void: _set_scoreboard_column(key, not on))
		out.append(shown_row.named(StringName("scoreboard_col_" + String(key))))
	return out


func _set_scoreboard_column(key: StringName, hide: bool) -> void:
	var choices := scoreboard.player_hidden.duplicate()
	choices[key] = hide
	var res := settings.set_value(DotMenuScoreboard.SETTING, DotMenuScoreboard.format_choices(choices))
	if not res.ok:
		DotLog.warn(CHANNEL, "the scoreboard columns were refused", {"why": res.error.message})


func _declared(key: StringName) -> bool:
	return settings != null and settings.schema != null and settings.schema.has(key)


## What a server may change about this client's menu while connected: `rows_hidden`, `pages_hidden`, `themes` (offered), `clamps` (`{setting: bound}` through dot-settings' policy) and `leave_text`.
## Narrower than the config on purpose: a server may hide and clamp but never set or read a stored value (that would fingerprint a player).
## Every rule is dropped by [method release_server_rules] on leaving. Returns the clamps applied.
func apply_server_rules(rules: Dictionary) -> PackedStringArray:
	_server_rules = rules.duplicate(true)
	var applied := PackedStringArray()

	if screen != null:
		screen.extra_hidden_rows = _hidden_rows()
		screen.extra_hidden_pages = _strings(rules.get("pages_hidden", []))
		if rules.has("leave_text"):
			screen.set_action_text(&"leave", str(rules["leave_text"]))

	var clamps: Variant = rules.get("clamps", {})
	if clamps is Dictionary and not (clamps as Dictionary).is_empty() and settings != null and settings.policy != null:
		applied = settings.apply_server_clamps(clamps as Dictionary)

	var allowed := _strings(rules.get("themes", []))
	if not allowed.is_empty():
		_offer_themes(allowed)

	if screen != null:
		screen.refresh()
	return applied


## Drops everything [method apply_server_rules] did. Called on leaving a server.
func release_server_rules() -> void:
	_server_rules.clear()
	if screen != null:
		screen.extra_hidden_rows = _hidden_rows()
		screen.extra_hidden_pages = PackedStringArray()
		screen.set_action_text(&"leave", leave_label())
	if settings != null and settings.policy != null:
		settings.release_clamps()
	_offer_themes(PackedStringArray())
	if screen != null:
		screen.refresh()


## Hides [param rows] for a reason of the game's own ([param reason]: `&"voice"` while the
## server has voice off), on top of a server's `rows_hidden`. An empty list shows them again.
## Kept apart from [method apply_server_rules] so neither undoes the other.
func hide_rows(reason: StringName, rows: PackedStringArray) -> void:
	if rows.is_empty():
		_hidden_by.erase(reason)
	else:
		_hidden_by[reason] = rows
	if screen != null:
		screen.extra_hidden_rows = _hidden_rows()
		screen.refresh()


func _hidden_rows() -> PackedStringArray:
	var out := _strings(_server_rules.get("rows_hidden", []))
	for reason in _hidden_by:
		for row in (_hidden_by[reason] as PackedStringArray):
			if not out.has(row):
				out.append(row)
	return out


## Narrows the theme row to [param allowed] (empty is every theme) and moves off a theme the
## server does not offer — for this connection only; the stored choice is untouched.
func _offer_themes(allowed: PackedStringArray) -> void:
	var row := find_row(&"ui_theme")
	var offered: Array = []
	for o in themes.options():
		if allowed.is_empty() or allowed.has(String(o[0])):
			offered.append(o)
	if row != null:
		row.options = offered
	var stored := _stored_theme()
	if not allowed.is_empty() and not allowed.has(String(stored)):
		var _changed := use_theme(StringName(allowed[0]))
	else:
		var _changed := use_theme(stored)


static func _strings(v: Variant) -> PackedStringArray:
	var out := PackedStringArray()
	if v is Array or v is PackedStringArray:
		for s in v:
			out.append(str(s))
	return out


func describe() -> Dictionary:
	return {
		"open": any_open(), "menu": screen.describe() if screen != null else {},
		"help": help.describe() if help != null else {},
		"theme": String(_theme_id), "themes": themes.size() if themes != null else 0,
		"pages": pages.size(), "server_rules": _server_rules.keys(),
		"pointer": manage_pointer, "overlays": _extra.size(),
		"maps": maps.describe() if maps != null else {},
		"loadout": loadout.describe() if loadout != null else {},
	}


func describe_lines() -> PackedStringArray:
	var d := describe()
	var out := PackedStringArray()
	out.append("menu: %s, theme %s of %d, %d pages" % ["open" if d["open"] else "closed", d["theme"], d["themes"], d["pages"]])
	if not _server_rules.is_empty():
		out.append("  server rules: %s" % ", ".join(PackedStringArray(_server_rules.keys().map(func(k: Variant) -> String: return str(k)))))
	return out
