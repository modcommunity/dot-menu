class_name DotMenu
extends CanvasLayer

## A game's menus, in one node: the Escape menu, the help screen, a picker, the HUD layout
## editor, a frame-rate counter, and the theme they are all drawn in.
##
## [codeblock]
## var menu := DotMenu.new()
## menu.settings = settings                       # a DotSettingsManager, set up
## menu.bindings = keys                           # a DotMenuBindings
## menu.config = config                           # a DotMenuConfig; null is the stock one
## menu.help_action = &"mygame_help"              # H, as the player has it bound
## menu.theme_action = &"mygame_theme_next"       # optional: a key that cycles themes
## add_child(menu)
## menu.setup()                                   # the stock pages, the themes, the screens
## menu.page(&"general").section("HUD").add(DotMenuRow.toggle(&"show_speed", "Speed"))
## menu.action_requested.connect(func(id): if id == &"leave": leave())
## menu.overlays_changed.connect(func(open): sampler.suspended = open)
## [/codeblock]
##
## [b]What it owns, and why those together.[/b] Which overlay is open, what Escape does, who
## has the pointer, and what colour everything is are four questions that are easy alone and
## are where menu bugs live together: a help screen that opens under the menu, an Escape that
## closes two screens, a menu that closes and leaves the pointer free, a theme change that
## restyles the menu and not the help. dot-ui answers the first three from one stack for its
## screens; this answers them for these, the same way — from one list, in one place.
##
## [b]The pointer, in a browser.[/b] A browser exits pointer lock on Escape and may not
## deliver the key at all, so a menu that opens only on the key does not open. With
## [member DotMenuConfig.open_on_pointer_release] this watches the pointer instead: a lock it
## had seen that is gone opens the menu. An Escape arriving within
## [member DotMenuConfig.escape_grace_ms] of that is swallowed, or the menu would flash and
## close. Closing by Resume (a click) recaptures; closing by Escape cannot (Escape grants no
## user activation), so twelve frames later an uncaptured pointer emits [signal
## click_to_play] for the game to say so.
##
## [b]Not a pause.[/b] See [DotMenuScreen]. [signal overlays_changed] is how a game stops its
## input sampler instead.

const CHANNEL := "menu"

## The menu, or any overlay, opened or the last one closed.
signal overlays_changed(open: bool)

## A sidebar action: &"help" is handled here (it opens help); &"leave" and a game's own are
## the game's.
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

## The theme catalogue. Null at setup is the stock six, plus the config's file.
var themes: DotMenuThemes = null

## The pages, in sidebar order. Null at setup is [method DotMenuStock.pages].
var pages: Array[DotMenuPage] = []

## The kit everything is drawn with now. Replaced, not changed, on a theme change.
var kit: DotMenuKit = null

## Actions that, pressed with nothing open, open help and cycle the theme. Empty is none.
var help_action: StringName = &""
var theme_action: StringName = &""

## The action held to show the scoreboard (Tab). Empty is no scoreboard key; the board is
## still built and can be opened in code.
var scoreboard_action: StringName = &""

## The action that opens the picker in this game (a map list's M), which also closes it.
## The menu does not open the picker on it — what the list holds is the game's to fetch.
var picker_action: StringName = &""

## Handle Escape and the actions above from [method Node._unhandled_input]. Off for a host
## that routes input itself through [method handle_event].
var handle_keys: bool = true

## Free the pointer while anything is open and capture it when the last thing closes.
var manage_pointer: bool = true

## `func() -> bool`: true when the game has the keyboard for something else — a chat line, a
## console — so Escape and the keys above are left to it, and a pointer it freed does not
## open the menu.
var busy: Callable = Callable()

var screen: DotMenuScreen = null
var help: DotMenuHelp = null
var picker: DotMenuPicker = null
var layout_editor: DotMenuLayoutEditor = null

## The held scoreboard. Not one of the overlays: see [DotMenuScoreboard].
var scoreboard: DotMenuScoreboard = null

var _fps_label: Label = null
## Other overlays a game registered: Controls with is_open() and close().
var _extra: Array[Control] = []
var _theme_id: StringName = &""
var _was_open := false
var _lock_seen := false
var _opened_msec := 0
var _recapture_frames := 0
var _server_rules: Dictionary = {}
var _ready_done := false


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

	_theme_id = _stored_theme()
	kit = DotMenuKit.new(themes.named(_theme_id)) if kit == null else kit.with_palette(themes.named(_theme_id))

	_build()

	if settings != null and not settings.changed.is_connected(_on_setting_changed):
		settings.changed.connect(_on_setting_changed)
	_apply_fps_counter()
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
	picker.chosen.connect(func(id: StringName) -> void: picked.emit(id))
	add_child(picker)

	help = DotMenuHelp.new()
	help.name = "Help"
	help.kit = kit
	help.bindings = bindings
	help.config = config
	help.help_action = help_action
	help.extra_keys = {_last_group(): [["Esc", "Menu and settings"]]}
	help.closed.connect(_on_closed)
	add_child(help)


func _actions() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if config.show_help:
		out.append({"id": &"help", "text": "Help & commands"})
	if config.show_leave:
		out.append({"id": &"leave", "text": config.leave_text, "danger": true})
	return out


## The group Escape's help line goes in: the last one, which in the stock order is the
## interface keys.
func _last_group() -> String:
	var groups := bindings.groups() if bindings != null else PackedStringArray()
	return groups[groups.size() - 1] if not groups.is_empty() else "Interface"


## The stock theme row offers the themes as they are named, not as ids, and only those the
## catalogue still has — the config may have narrowed it after the schema was declared.
func _wire_stock_rows() -> void:
	for p in pages:
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


# --- Pages --------------------------------------------------------------------

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


# --- Opening and closing ------------------------------------------------------

func open(page_id: StringName = &"") -> void:
	if screen == null:
		return
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


## A list to pick from. See [DotMenuPicker]. [signal picked] says what was chosen.
func open_picker(items: Array, title: String = "") -> void:
	if picker == null:
		return
	if screen.is_open():
		screen.visible = false
	picker.open(items, title)
	_on_opened()


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
	var now := any_open()
	if now != _was_open:
		_was_open = now
		overlays_changed.emit(now)


func _on_action(id: StringName) -> void:
	if id == &"help":
		open_help()
	action_requested.emit(id)


# --- Input --------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if handle_keys and handle_event(event):
		get_viewport().set_input_as_handled()


## Escape, help and the theme key, and the picker's number keys while it is open. True when
## the event was the menu's. For a host that routes input itself; [member handle_keys] does
## this on its own otherwise.
##
## [b]An open overlay owns the keyboard.[/b] Its own controls have already had the event;
## what reaches here is a key to close it or a key that must not fall through to the game —
## R behind a menu is a restart nobody asked for — so every key is the menu's while one is
## open.
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
		if escape:
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
		return false

	# The same Escape that took the pointer away in a browser can arrive a moment after the
	# menu it opened; closing on it would make the menu flash and vanish.
	if escape and Time.get_ticks_msec() - _opened_msec < config.escape_grace_ms:
		return true

	if layout_editor.is_open():
		if escape:
			layout_editor.close()
		return true

	if picker.is_open():
		if escape or (picker_action != &"" and InputMap.has_action(picker_action) and event.is_action_pressed(picker_action)):
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


# --- Themes -------------------------------------------------------------------

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
		if o != null and o.has_method(&"restyle"):
			o.call(&"restyle", kit)
	if scoreboard != null:
		scoreboard.restyle(kit)
	if _fps_label != null:
		_fps_label.add_theme_color_override(&"font_color", p.muted)
	theme_changed.emit(p)
	return true


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
		&"show_fps":
			_apply_fps_counter()
		_:
			if bindings != null:
				var _bound := bindings.apply_setting(key, value)


func _apply_fps_counter() -> void:
	if _fps_label == null:
		return
	var on := settings != null and settings.schema != null and settings.schema.has(&"show_fps") \
		and settings.get_bool(&"show_fps", false)
	_fps_label.visible = config.fps_counter and on


# --- What a server may say ----------------------------------------------------

## What a server may change about this client's menu, while it is connected:
## [codeblock]
## {
##   "rows_hidden":  ["field_of_view"],        # left off every page
##   "pages_hidden": ["audio"],
##   "themes":       ["midnight", "contrast"], # offered; the player's own stays if allowed
##   "clamps":       {"field_of_view": 100},   # through dot-settings' policy
##   "leave_text":   "Disconnect"
## }
## [/codeblock]
## [b]Narrower than the config, on purpose.[/b] A server may hide and clamp; it can never
## set a player's stored value or read one (dot-settings' rule — a server that can read
## settings can fingerprint a player). A clamp is a bound the player's own value stays
## under, and every one of these is dropped by [method release_server_rules] on leaving.
## Returns the clamps that were applied.
func apply_server_rules(rules: Dictionary) -> PackedStringArray:
	_server_rules = rules.duplicate(true)
	var applied := PackedStringArray()

	if screen != null:
		screen.extra_hidden_rows = _strings(rules.get("rows_hidden", []))
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
		screen.extra_hidden_rows = PackedStringArray()
		screen.extra_hidden_pages = PackedStringArray()
		screen.set_action_text(&"leave", config.leave_text)
	if settings != null and settings.policy != null:
		settings.release_clamps()
	_offer_themes(PackedStringArray())
	if screen != null:
		screen.refresh()


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
	}


func describe_lines() -> PackedStringArray:
	var d := describe()
	var out := PackedStringArray()
	out.append("menu: %s, theme %s of %d, %d pages" % ["open" if d["open"] else "closed", d["theme"], d["themes"], d["pages"]])
	if not _server_rules.is_empty():
		out.append("  server rules: %s" % ", ".join(PackedStringArray(_server_rules.keys().map(func(k: Variant) -> String: return str(k)))))
	return out
