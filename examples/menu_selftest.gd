extends Node

## Exercises dot-menu with no game: the data model, stock settings and what applies them, the bindings table, the screens, the facade's keys, and what a server may do.
## CHECKS is the guard the section counter cannot be: a script error aborts that test, not the run, and only the total notices checks that never ran.
const SECTIONS := 24
const CHECKS := 391

var _passed := 0
var _failed := 0
var _section_count := 0


func _ready() -> void:
	DotLog.set_level(DotLog.Level.ERROR)
	# Every section runs inside the tree: the screens need a viewport to be built in.
	_run.call_deferred()


func _run() -> void:
	_line("dot-menu self-test")
	_line("")

	_test_palette()
	_test_themes()
	_test_config()
	_test_stock()
	_test_bindings()
	_test_applier()
	await _test_screen()
	await _test_rows()
	await _test_facade()
	await _test_server_rules()
	await _test_help_and_picker()
	_test_layout()
	await _test_settings_node()
	await _test_scoreboard()
	await _test_net_stat()
	await _test_voice()
	await _test_help_key_and_leave()
	await _test_map_menu()
	await _test_loadout_menu()
	_test_avatar_action_keys()
	await _test_hud_follows()
	_test_moved_defaults()
	_test_wheel()
	await load("res://examples/scoreboard_scroll_checks.gd").run(self)
	_line("")
	_line("%d sections, %d passed, %d failed" % [_section_count, _passed, _failed])

	if _section_count != SECTIONS:
		_line("ERROR: %d of %d sections ran." % [_section_count, SECTIONS])
		get_tree().quit(1)
		return

	if CHECKS > 0 and _passed + _failed != CHECKS:
		_line("ERROR: %d checks ran, %d expected. A section aborted part-way." % [_passed + _failed, CHECKS])
		get_tree().quit(1)
		return

	get_tree().quit(1 if _failed > 0 else 0)


func _schema(groups: Array[StringName] = DotMenuStock.DEFAULT_GROUPS) -> DotSettingsSchema:
	var s := DotSettingsSchema.new()
	DotMenuStock.declare(s, groups)
	return s


func _keys() -> DotMenuBindings:
	var k := DotMenuBindings.new()
	k.add_movement()
	k.add(&"test_flashlight", &"bind_flashlight", "Flashlight", "F", "View")
	k.add(&"test_help", &"bind_help", "Help", "H", "Interface")
	k.add(&"test_theme", &"bind_theme", "Next theme", "P", "Interface")
	return k


func _manager(schema: DotSettingsSchema) -> DotSettingsManager:
	var m := DotMenuStock.manager(schema, "", &"menu_test", &"", DotSettingsStoreMemory.new())
	m.persist = false
	add_child(m)
	var res := m.setup()
	if not res.ok:
		_line("  (settings did not set up: %s)" % res.error.message)
	return m


func _menu(groups: Array[StringName] = DotMenuStock.DEFAULT_GROUPS, cfg: DotMenuConfig = null) -> DotMenu:
	var keys := _keys()
	var schema := _schema(groups)
	keys.add_to_schema(schema)
	var st := _manager(schema)
	keys.apply_all(st)
	var menu := DotMenu.new()
	menu.settings = st
	menu.bindings = keys
	menu.config = cfg if cfg != null else DotMenuConfig.new()
	menu.config.escape_grace_ms = 0
	menu.manage_pointer = false
	menu.help_action = &"test_help"
	menu.theme_action = &"test_theme"
	add_child(menu)
	var res := menu.setup()
	if not res.ok:
		_line("  (menu did not set up: %s)" % res.error.message)
	return menu


func _free_menu(menu: DotMenu) -> void:
	var st := menu.settings
	menu.queue_free()
	if st != null:
		st.queue_free()


func _key(code: Key) -> InputEventKey:
	var e := InputEventKey.new()
	e.physical_keycode = code
	e.keycode = code
	e.pressed = true
	return e


## Every descendant of [param root] of [param type] whose name starts with [param prefix].
func _find_all(root: Node, type: String, prefix: String = "") -> Array[Node]:
	var out: Array[Node] = []
	for n in root.find_children("*", type, true, false):
		if prefix == "" or String(n.name).begins_with(prefix):
			out.append(n)
	return out


func _row_control(menu: DotMenu, row_id: String) -> Node:
	return menu.screen.find_child("Row_%s" % row_id, true, false)


class FakeMixer extends RefCounted:
	var master := 1.0
	var sfx := 1.0
	var ui := 1.0
	var music := 1.0
	var voice := 1.0
	var ambience := 1.0
	var applied := 0

	func apply_to_buses() -> PackedStringArray:
		applied += 1
		return PackedStringArray()


class FakeFx extends RefCounted:
	var shake_scale := 1.0
	var allow_flashes := true
	var quality := 3


class FakeLook extends RefCounted:
	var mouse_sensitivity := 0.0
	var invert_look_y := false


class FakeHands extends Node:
	var horizontal := 0.0

	func _init() -> void:
		add_to_group(DotMenuApplier.VIEW_MODEL_GROUP)

	func set_hands_fov_at_4_3(v: float) -> void:
		horizontal = v


class FakeCamera extends RefCounted:
	var fov := 0.0
	var fov_desired := 0.0


## A HUD with two pieces the editor can move. Duck-typed, as the editor expects.
class FakeHud extends Control:
	var positions := {}
	var defaults := {&"timer": Vector2(400, 700), &"keys": Vector2(400, 760)}

	func element_rect(id: StringName) -> Rect2:
		var centre: Vector2 = defaults[id]
		if positions.has(id):
			centre = (positions[id] as Vector2) * size
		return Rect2(centre - Vector2(60, 20), Vector2(120, 40))

	func move_element(id: StringName, centre: Vector2) -> void:
		positions[id] = Vector2(clampf(centre.x / size.x, 0.0, 1.0), clampf(centre.y / size.y, 0.0, 1.0))

	func reset_element(id: StringName) -> void:
		positions.erase(id)


func _test_palette() -> void:
	_section("A theme is data")

	var res := DotMenuPalette.from_dictionary({
		"id": "sea", "name": "Sea", "accent": "#3080ff", "surface": [0.1, 0.2, 0.3],
		"danger": "red", "extra": {"team_red": "#ff0000"},
	})
	_check(res.ok, "a theme reads hex, arrays and named colours")
	var p: DotMenuPalette = res.value
	_check(p.accent.is_equal_approx(Color.html("#3080ff")), "a hex accent is the accent")
	_check(p.surface.is_equal_approx(Color(0.1, 0.2, 0.3)), "an array is a colour, alpha one")
	_check(p.danger.is_equal_approx(Color.RED), "and a colour's name is the colour")
	_check(p.color(&"team_red").is_equal_approx(Color.RED), "a game's own colour is read back by name")
	_check(p.color(&"nobody", Color.BLUE) == Color.BLUE, "and one the theme does not name falls back")
	_check(p.text.is_equal_approx(DotMenuPalette.new().text), "a key left out keeps the base's value")

	var bad := DotMenuPalette.from_dictionary({"id": "x", "accent": "not a colour"})
	_check(not bad.ok and bad.error.message.contains("accent"), "a colour nobody can read fails, naming the key")
	_check(not DotMenuPalette.from_dictionary({"accent": "#fff"}).ok, "and a theme without an id is refused")

	var again := DotMenuPalette.from_dictionary(p.to_dictionary())
	_check(again.ok and again.value.accent.is_equal_approx(p.accent) and again.value.color(&"team_red").is_equal_approx(Color.RED),
		"a theme survives a round trip through its own data")
	_check(DotMenuPalette.ink_on(Color(1, 0.9, 0)) == Color(0.04, 0.04, 0.05), "black ink on a bright accent")
	_check(DotMenuPalette.ink_on(Color(0.1, 0.2, 0.4)).r > 0.9, "and white ink on a dark one")
	_check(Color(p.accent, 0.13).is_equal_approx(p.accent_wash()), "the wash follows the accent rather than being stored")


func _test_themes() -> void:
	_section("The catalogue")

	var t := DotMenuThemes.stock()
	_check(t.size() == 7, "seven stock themes")
	_check(t.default_id() == &"midnight", "Midnight first, so it is the default")
	_check(t.named(&"paper").is_light(), "Paper is a light theme")
	_check(t.named(&"no such theme").id == &"midnight", "an unknown id draws the default, not nothing")
	_check(t.next(&"contrast") == &"midnight", "the theme key wraps round the end")

	var ember := t.named(&"ember").derive(&"ember", "Ember, but blue")
	ember.accent = Color.BLUE
	t.add(ember)
	_check(t.ids()[1] == &"ember" and t.named(&"ember").accent == Color.BLUE,
		"a theme with a stock theme's id replaces it in place")

	var made := t.add_dictionary({"id": "mint", "base": "midnight", "accent": "#7fffd4"})
	_check(made.ok and t.named(&"mint").surface == t.named(&"midnight").surface,
		"a theme can start from another and change only the accent")
	_check(not t.add_dictionary({"id": "oops", "base": "nope"}).ok, "but not from a theme that is not there")

	_check(t.keep_only(PackedStringArray(["paper", "contrast"])) == 2, "an operator can narrow the list")
	_check(t.keep_only(PackedStringArray(["typo"])) == 2, "and a list naming nothing there keeps what there was")
	_check(t.make_default(&"contrast") and t.default_id() == &"contrast", "and choose the default")

	var dir := "user://dot_menu_test"
	DirAccess.make_dir_recursive_absolute(dir)
	var path := dir + "/themes.json"
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify({"themes": [{"id": "dusk", "name": "Dusk", "accent": "#ff8040"}]}))
	f.close()
	var t2 := DotMenuThemes.stock()
	var loaded := t2.load_json(path)
	_check(loaded.ok and t2.find(&"dusk") != null and t2.size() == 8, "a file of themes adds them")
	_check(t2.load_json(dir + "/missing.json").ok, "and a missing file is the first launch, not an error")
	f = FileAccess.open(path, FileAccess.WRITE)
	f.store_string("{ not json")
	f.close()
	_check(not t2.load_json(path).ok, "while a file that does not parse is one")


func _test_config() -> void:
	_section("A developer changes values without code")

	var cfg := DotMenuConfig.new()
	var applied := cfg.apply_dictionary({
		"brand_mark": "g2g", "theme": "ember", "rows_hidden": ["render_scale"],
		"settings": {
			"field_of_view": {"default": 100, "min": 75, "max": 110},
			"shake_scale": {"default": 0.0},
			"window_mode": {"options": ["windowed", "fullscreen"]},
			"nonsense_key": {"default": 1},
			"vsync": {"colour": "blue"},
		},
		"fps_choices": [0, 60, 144],
	})
	_check(applied.size() == 5, "every known key of the file is applied")
	_check(cfg.validate().ok, "and the result is a valid config")
	_check(cfg.rows_hidden.has("render_scale"), "a list arrives as a list")

	var s := _schema()
	var problems := cfg.apply_to_schema(s)
	_check(int(s.find(&"field_of_view").default_value) == 100, "a default is changed")
	_check(s.find(&"field_of_view").max_value == 110.0, "and a range narrowed")
	_check(float(s.find(&"shake_scale").default_value) == 0.0, "a genre that wants no shake says so in data")
	_check(s.find(&"window_mode").options.size() == 2 and s.find(&"window_mode").default_value == &"windowed",
		"options narrowed, with the default still one of them")
	_check(problems.size() == 2, "a key no setting has and a field no setting has are both reported")
	_check(s.validate().ok, "and the schema is still one a document can be loaded against")

	var narrow := DotMenuConfig.new()
	narrow.settings = {"field_of_view": {"max": 80}}
	var s2 := _schema()
	var _p := narrow.apply_to_schema(s2)
	_check(int(s2.find(&"field_of_view").default_value) == 80, "a default outside a narrowed range is pulled inside it")

	_check(cfg.fps_list(90) == [0, 60, 90, 144], "a cap the list does not offer is kept in it, in order")
	cfg.rows = {"fx_quality": {"title": "Particles"}}
	_check(cfg.row_title(&"fx_quality", "Effects") == "Particles" and cfg.row_description(&"fx_quality", "x") == "x",
		"a row is reworded by id, and what is not reworded stays")

	var themed := DotMenuConfig.new()
	themed.theme = &"paper"
	themed.themes_allowed = PackedStringArray(["paper", "midnight", "mint"])
	var catalogue := DotMenuThemes.stock()
	var _mint := catalogue.add_dictionary({"id": "mint", "base": "midnight", "accent": "#7fffd4"})
	var s3 := _schema()
	var _q := themed.apply_to_schema(s3, themed.make_themes(catalogue))
	var theme_def := s3.find(&"ui_theme")
	_check(theme_def.default_value == &"paper", "the configured theme is a new player's theme")
	_check(Array(theme_def.options) == [&"paper", &"midnight", &"mint"],
		"and the setting can hold exactly the themes offered, a game's own among them")
	_check(theme_def.coerce(&"mint").ok and not theme_def.coerce(&"ember").ok,
		"so a game's theme is stored, and one no longer offered is refused at load")

	var broken := DotMenuConfig.new()
	broken.browser_tips = &"sometimes"
	_check(not broken.validate().ok, "and a value nobody can act on is refused")


func _test_stock() -> void:
	_section("The stock settings, and what applies each")

	var s := _schema()
	var declared := 0
	for group in DotMenuStock.DEFAULT_GROUPS:
		for key in DotMenuStock.KEYS[group]:
			if s.has(key):
				declared += 1
	var expected := 0
	for group in DotMenuStock.DEFAULT_GROUPS:
		expected += (DotMenuStock.KEYS[group] as Array).size()
	_check(declared == expected and s.keys().size() == expected, "the default groups declare exactly their keys")
	_check(not s.has(&"music_volume"), "music is asked for, not given: a slider for a silent bus does nothing")
	_check(s.find(&"sensitivity").scope == DotSettingsDef.Scope.ACCOUNT, "sensitivity is the player's, everywhere")
	_check(s.find(&"field_of_view").scope == DotSettingsDef.Scope.SERVER_CLAMPED, "the view may be capped by a server")
	_check(s.find(&"master_volume").scope == DotSettingsDef.Scope.DEVICE, "and a volume is this machine's")
	_check(s.validate().ok, "the stock schema validates")

	var own := DotSettingsSchema.new()
	own.add(DotSettingsDef.integer(&"field_of_view", 92, 70, 120, &"video"))
	DotMenuStock.declare(own)
	_check(int(own.find(&"field_of_view").default_value) == 92, "a game's own version of a stock key wins")

	# The family's most repeated bug, as a check: every stock key is applied by something.
	var orphans := PackedStringArray()
	for group in DotMenuStock.ALL_GROUPS:
		for key in DotMenuStock.KEYS[group]:
			if not (DotMenuApplier.APPLIES.has(key) or DotMenuApplier.APPLIED_BY_MENU.has(key)
					or DotMenuApplier.LEFT_TO_THE_GAME.has(key)):
				orphans.append(String(key))
	_check(orphans.is_empty(), "every stock key is applied by something (%s)" % ", ".join(orphans))

	var all := _schema(DotMenuStock.ALL_GROUPS)
	var sl := all.find(&"slide_volume")
	_check(sl != null and is_equal_approx(float(sl.default_value), 1.0) and sl.category == &"audio", "slide_volume is stock, default 1.0 in the audio group (dot-game's default)")
	_check(DotMenuStock.audio_page().sections.any(func(sec) -> bool: return sec.rows.any(func(r) -> bool: return r.key == &"slide_volume")), "the Audio page has the slide_volume slider")
	var rowless := PackedStringArray()
	var unknown := PackedStringArray()
	var seen := {}
	for p in DotMenuStock.pages():
		for sec in p.sections:
			for r in sec.rows:
				if r.is_setting():
					seen[r.key] = true
					if not all.has(r.key):
						unknown.append(String(r.key))
	# Its switches are the live board's columns, one per column, so no single row names it.
	seen[DotMenuScoreboard.SETTING] = true
	for key in all.keys():
		if not seen.has(key):
			rowless.append(String(key))
	_check(unknown.is_empty(), "every stock row names a stock setting (%s)" % ", ".join(unknown))
	_check(rowless.is_empty(), "and every stock setting has a row (%s)" % ", ".join(rowless))
	_check(DotMenuStock.pages().map(func(p: DotMenuPage) -> StringName: return p.id) == [&"general", &"video", &"audio", &"controls", &"advanced"],
		"General, Video, Audio, Controls, Advanced")


func _test_bindings() -> void:
	_section("Keys")

	var k := _keys()
	_check(k.rows.size() == 9 and k.groups() == PackedStringArray(["Movement", "View", "Interface"]), "rows in order, groups once each")
	k.add(&"dot_fps_crouch", &"bind_duck", "Crouch", "Shift", "Movement")
	_check(k.rows.size() == 9 and k.rows[5]["label"] == "Crouch", "a row for an action already there replaces it in place")

	var s := DotSettingsSchema.new()
	s.add(DotSettingsDef.binding(&"bind_help", "F1", &"controls").with_scope(DotSettingsDef.Scope.ACCOUNT))
	k.add(&"test_chat", &"bind_chat", "Chat", "Y", "Interface", DotSettingsDef.Scope.ACCOUNT)
	k.add_to_schema(s)
	_check(s.find(&"bind_forward").scope == DotSettingsDef.Scope.DEVICE, "a key is this keyboard's by default")
	_check(s.find(&"bind_chat").scope == DotSettingsDef.Scope.ACCOUNT, "unless its row says otherwise")
	_check(str(s.find(&"bind_help").default_value) == "F1", "and a binding the game declared itself is left alone")

	var st := _manager(s)
	k.apply_all(st)
	_check(DotMenuBindings.shown(k.row_for_action(&"dot_fps_forward")) == "W", "every row lands on the InputMap")
	_check(k.key_for(&"test_help") == "F1", "from the stored value, not the table's default")

	var _cleared := st.set_value(&"bind_flashlight", "")
	_check(k.apply_row(k.row_for_action(&"test_flashlight"), "") == "F", "a cleared binding falls back to the default rather than to nothing")
	_check(k.row_using("F", &"bind_jump", st) == k.row_for_action(&"test_flashlight"),
		"and is found on its default by the conflict check, or binding F elsewhere leaves F on two actions")

	var res := k.rebind(k.row_for_action(&"dot_fps_jump"), "F", st)
	_check(res.ok and str(res.value).contains("moved"), "binding a key that is taken says what moved")
	_check(st.get_string(&"bind_jump") == "F" and st.get_string(&"bind_flashlight") == "Space",
		"and swaps the two, so nothing is left unbound")
	_check(k.key_for(&"dot_fps_jump") == "F" and k.key_for(&"test_flashlight") == "Space", "both are on the InputMap at once")

	k.reset_all(st)
	_check(st.get_string(&"bind_jump") == "Space" and k.key_for(&"dot_fps_jump") == "Space", "a reset puts every key back")

	# A document from before dot-ui named the wheel stores "Mouse 4"; the Controls page
	# draws stored(), so it must come out as the wheel's name, and still be the wheel.
	var old_wheel := st.set_value(&"bind_flashlight", "Mouse 4")
	var drawn := k.stored(k.row_for_action(&"test_flashlight"), st)
	_check(old_wheel.ok and drawn == "Wheel up",
		"an old \"Mouse 4\" is drawn as the wheel it always meant (%s)" % drawn)
	k.reset_all(st)
	st.queue_free()


func _test_applier() -> void:
	_section("Every value reaches what it controls")

	var s := _schema(DotMenuStock.ALL_GROUPS)
	var st := _manager(s)
	var _a := st.set_value(&"master_volume", 0.5)
	var _b := st.set_value(&"sensitivity", 2.0)
	var _c := st.set_value(&"shake_scale", 0.0)

	var applier := DotMenuApplier.new()
	applier.settings = st
	add_child(applier)

	var mixer := FakeMixer.new()
	var fx := FakeFx.new()
	var look := FakeLook.new()
	var cam := FakeCamera.new()
	var heard: Array = []
	applier.bind_audio(mixer)
	applier.bind_fx(fx)
	applier.bind_look(look)
	applier.bind_camera(cam)
	var _o := applier.on(&"chat_window", func(v: Variant, why: StringName) -> void: heard.append([v, why]))
	var _set := applier.setup()

	_check(is_equal_approx(mixer.master, 0.5) and mixer.applied > 0, "a stored volume is applied at boot, without being touched")
	_check(is_equal_approx(look.mouse_sensitivity, 2.0 * DotMenuApplier.DEGREES_PER_COUNT), "the sensitivity is the family's degrees per count")
	_check(fx.shake_scale == 0.0, "the shake reaches the effects")
	_check(cam.fov == 90.0, "and the field of view the camera")
	_check(heard.size() == 1 and heard[0][1] == &"applied", "a game's handler hears the boot value once")

	var hands := FakeHands.new()
	add_child(hands)
	_check(hands.horizontal == 65.0, "a view model added after boot gets the viewmodel_fov default")
	var _vm := st.set_value(&"viewmodel_fov", 80)
	_check(hands.horizontal == 80.0, "and follows the setting live")
	_check(DotMenuStock.video_page().sections.any(func(sec) -> bool: return sec.rows.any(func(r) -> bool: return r.key == &"viewmodel_fov")), "the Video page has its slider")
	hands.queue_free()

	var _d := st.set_value(&"sfx_volume", 0.25)
	var _e := st.set_value(&"invert_mouse", true)
	var _f := st.set_value(&"chat_window", &"off")
	_check(is_equal_approx(mixer.sfx, 0.25) and look.invert_look_y, "a change is applied when it is made")
	_check(heard.size() == 2 and heard[1][0] == &"off", "and the handler hears it")
	var _amb := st.set_value(&"ambience_volume", 0.3)
	_check(is_equal_approx(mixer.ambience, 0.3), "the ambience slider reaches the mixer's ambience level")

	applier.fov_transform = func(v: float) -> float: return v + 10.0
	var cam2 := FakeCamera.new()
	applier.bind_camera(cam2, &"fov_desired")
	_check(cam2.fov_desired == 100.0, "a camera with its own property, through the game's own measure")
	_check(absf(DotMenuApplier.vertical_from_horizontal_4_3(90.0) - 73.74) < 0.05 and absf(DotMenuApplier.vertical_from_horizontal_4_3(100.0) - 83.6) < 0.1, "4:3 horizontal degrees become the vertical ones a camera takes")

	var _g := st.set_value(&"fps_max", 144)
	_check(Engine.max_fps == 144, "the frame-rate cap is the engine's")
	var _h := st.set_value(&"fps_max", 0)

	var bare := DotMenuApplier.new()
	bare.settings = st
	add_child(bare)
	var _s2 := bare.setup()
	_check(is_equal_approx(db_to_linear(AudioServer.get_bus_volume_db(0)), 0.5),
		"with no mixer, the volume goes straight onto the bus of its name")
	AudioServer.set_bus_volume_db(0, 0.0)
	applier.queue_free()
	bare.queue_free()
	st.queue_free()


func _test_screen() -> void:
	_section("The menu is a view of the settings")

	var menu := _menu()
	menu.open()
	await get_tree().process_frame

	_check(menu.is_open() and menu.screen.current_page() == &"general", "it opens on the first page")
	var tabs := _find_all(menu.screen, "Button", "Page_")
	_check(tabs.size() == 5, "a tab per page")
	var _themed := menu.cycle_theme()
	await get_tree().process_frame
	_check(_find_all(menu.screen, "Button", "Page_").size() == 5,
		"and still a tab per page after the theme changes under an open menu")
	var actions := _find_all(menu.screen, "Button", "Action_")
	_check(actions.size() == 2, "and Help and Leave under them")

	var fps_switch := _row_control(menu, "show_fps") as DotMenuSwitch
	_check(fps_switch != null and not fps_switch.button_pressed, "a switch shows the stored value")
	fps_switch.button_pressed = true
	_check(menu.settings.get_bool(&"show_fps"), "and flipping it writes the setting, with nothing to apply")
	_check(menu._fps_label.visible, "which the counter follows at once")

	menu.screen.show_page(&"video")
	await get_tree().process_frame
	var fov := _row_control(menu, "field_of_view")
	var slider := fov.find_child("Slider", true, false) as HSlider if fov != null else null
	_check(slider != null and slider.min_value == 70.0 and slider.max_value == 120.0, "a slider's range is the setting's own")
	slider.value = 101.0
	_check(menu.settings.get_int(&"field_of_view") == 101, "dragging it writes an integer setting as an integer")
	var readout := fov.find_child("Readout", true, false) as Label
	_check(readout.text == "101°", "and the readout says it in the row's format")

	var fps := _row_control(menu, "fps_max") as OptionButton
	_check(fps != null and fps.get_item_text(fps.selected) == "Unlimited", "the frame-rate list shows what is stored")
	fps.select(3)
	fps.item_selected.emit(3)
	_check(menu.settings.get_int(&"fps_max") == 75, "and picking from it stores the number")

	var _console := menu.settings.set_value(&"fps_max", 97)
	menu.screen.show_page(&"video")
	await get_tree().process_frame
	fps = _row_control(menu, "fps_max") as OptionButton
	_check(fps.get_item_text(fps.selected) == "97", "a cap set at the console is shown, not replaced by the first item")
	var _back := menu.settings.set_value(&"fps_max", 0)
	Engine.max_fps = 0

	_check(_row_control(menu, "window_mode_web") == null and _row_control(menu, "window_mode") != null,
		"the desktop's window row, not the browser's")

	menu.screen.show_page(&"controls")
	await get_tree().process_frame
	var keys := menu.screen.find_children("Row_bind_*", "DotMenuKeyButton", true, false)
	_check(keys.size() == 9, "a key button for every binding row")
	_check(menu.screen.find_child("ResetKeys", true, false) != null, "and a way to put them all back")
	_free_menu(menu)

	var narrow := _menu([DotMenuStock.GROUP_AUDIO, DotMenuStock.GROUP_INTERFACE] as Array[StringName])
	narrow.open(&"video")
	await get_tree().process_frame
	_check(_row_control(narrow, "render_scale") == null and narrow.screen.find_child("Body", true, false).get_child_count() == 0,
		"a page whose settings were not declared draws nothing, not dead switches")
	narrow.open(&"audio")
	await get_tree().process_frame
	_check(_row_control(narrow, "master_volume") != null and _row_control(narrow, "music_volume") == null,
		"and a row for an undeclared setting is left out")
	_free_menu(narrow)


func _test_rows() -> void:
	_section("A game extends a page")

	var cfg := DotMenuConfig.new()
	cfg.rows_hidden = PackedStringArray(["vsync"])
	cfg.pages_hidden = PackedStringArray(["audio"])
	cfg.page_order = PackedStringArray(["controls"])
	cfg.rows = {"show_fps": {"title": "FPS"}}
	var menu := _menu(DotMenuStock.DEFAULT_GROUPS, cfg)

	var lit := [false]
	var pressed := [0]
	var allowed := [true]
	var gameplay := DotMenuPage.make(&"gameplay", "Gameplay", "Your view.")
	gameplay.section("View") \
		.add(DotMenuRow.live_toggle("Flashlight", "", func() -> bool: return lit[0], func(on: bool) -> void: lit[0] = on)
			.named(&"flashlight").enabled_when(func() -> bool: return allowed[0])
			.described_by(func() -> String: return "Allowed." if allowed[0] else "This server turned flashlights off.")) \
		.add(DotMenuRow.button("Arrange", "Drag the HUD.", "Move HUD elements", func() -> void: pressed[0] += 1).named(&"arrange")) \
		.add(DotMenuRow.custom("Name", "", func(kit: DotMenuKit) -> Control:
			var e := LineEdit.new()
			e.text = "custom"
			return e).named(&"name")) \
		.add(DotMenuRow.note("Only you see it."))
	menu.add_page(gameplay, &"video")
	var _moved := menu.page(&"general").take_row(&"show_fps")
	gameplay.section("View").add(_moved)

	menu.open(&"gameplay")
	await get_tree().process_frame
	var order: Array = menu.screen.visible_pages().map(func(p: DotMenuPage) -> StringName: return p.id)
	_check(order == [&"controls", &"general", &"gameplay", &"video", &"advanced"], "pages in the config's order, the hidden one gone")

	var light := _row_control(menu, "flashlight") as DotMenuSwitch
	_check(light != null and not light.disabled, "a live row draws its owner's state")
	light.button_pressed = true
	_check(lit[0], "and writes through its setter, storing nothing")
	(_row_control(menu, "arrange") as Button).pressed.emit()
	_check(pressed[0] == 1, "a button row calls the game")
	_check((_row_control(menu, "name") as LineEdit).text == "custom", "a custom row is whatever the game builds")
	_check(_row_control(menu, "show_fps") != null and menu.screen.find_child("Body", true, false).find_children("*", "Label", true, false).any(func(l: Node) -> bool: return (l as Label).text == "FPS"),
		"a stock row moved to the game's page, under the config's words")

	allowed[0] = false
	menu.screen.refresh()
	await get_tree().process_frame
	light = _row_control(menu, "flashlight") as DotMenuSwitch
	var says_off := menu.screen.find_child("Body", true, false).find_children("*", "Label", true, false).any(
		func(l: Node) -> bool: return (l as Label).text.contains("turned flashlights off"))
	_check(light.disabled and says_off, "drawn again, it is disabled and says why")

	menu.screen.show_page(&"video")
	await get_tree().process_frame
	_check(_row_control(menu, "vsync") == null and _row_control(menu, "fps_max") != null, "a hidden row is gone and its neighbours are not")
	_free_menu(menu)


func _test_facade() -> void:
	_section("Escape, help and the theme key")

	var menu := _menu()
	var changes: Array = []
	var themes_seen: Array = []
	menu.overlays_changed.connect(func(open: bool) -> void: changes.append(open))
	menu.theme_changed.connect(func(p: DotMenuPalette) -> void: themes_seen.append(p.id))

	_check(menu.handle_event(_key(KEY_ESCAPE)) and menu.is_open(), "Escape opens the menu")
	_check(changes == [true], "and says something is open, once")
	_check(menu.handle_event(_key(KEY_R)), "every key is the menu's while it is open: R behind it is no restart")
	_check(menu.handle_event(_key(KEY_ESCAPE)) and not menu.is_open(), "Escape closes it")
	_check(changes == [true, false], "and says nothing is")

	_check(menu.handle_event(_key(KEY_H)) and menu.help.is_open(), "the help key opens help")
	menu.open()
	_check(not menu.help.is_open(), "the menu opened over help closes help")
	menu.open_help()
	_check(menu.help.is_open() and menu.is_open(), "help opened from the menu sits over it")
	var _e := menu.handle_event(_key(KEY_ESCAPE))
	_check(not menu.help.is_open() and menu.is_open(), "Escape closes help and leaves the menu")
	var _e2 := menu.handle_event(_key(KEY_ESCAPE))

	menu.config.escape_grace_ms = 60000
	var _o := menu.handle_event(_key(KEY_ESCAPE))
	_check(menu.handle_event(_key(KEY_ESCAPE)) and menu.is_open(), "an Escape right after opening is swallowed, not a flash")
	menu.config.escape_grace_ms = 0
	menu.close()

	menu.open_on_escape = false
	_check(not menu.handle_event(_key(KEY_ESCAPE)) and not menu.is_open(),
		"a game whose Escape is its own keeps it, with nothing open")
	menu.open()
	var _shut := menu.handle_event(_key(KEY_ESCAPE))
	_check(not menu.is_open(), "and Escape still closes the menu it opened some other way")
	menu.open_on_escape = true

	var busy := [true]
	menu.busy = func() -> bool: return busy[0]
	_check(not menu.handle_event(_key(KEY_ESCAPE)) and not menu.is_open(), "while the game has the keyboard, Escape is the game's")
	busy[0] = false

	var surface_before := menu.screen.theme.get_stylebox(&"normal", &"Button") as StyleBoxFlat
	_check(menu.handle_event(_key(KEY_P)), "the theme key is the menu's")
	_check(menu.settings.get_string(&"ui_theme") == "ember", "and stores the next theme")
	_check(themes_seen == [&"ember"], "which every screen hears about once")
	var surface_after := menu.screen.theme.get_stylebox(&"normal", &"Button") as StyleBoxFlat
	_check(surface_before != surface_after and menu.kit.palette.id == &"ember", "and is rebuilt in")
	_check(menu.help.kit == menu.kit and menu.picker.kit == menu.kit, "the help and the picker too")

	var _same := menu.settings.set_value(&"show_fps", true)
	_check(themes_seen.size() == 1, "a change to anything else does not rebuild the screens")

	var mine := DotMenuPicker.new()
	add_child(mine)
	menu.add_overlay(mine)
	mine.open([{"id": "a", "name": "A"}])
	menu.overlay_opened()
	_check(menu.any_open(), "a game's own overlay counts as open")
	var _x := menu.handle_event(_key(KEY_ESCAPE))
	_check(not mine.is_open() and not menu.any_open(), "and Escape closes it")
	mine.queue_free()
	_free_menu(menu)
	await get_tree().process_frame


func _test_server_rules() -> void:
	_section("What a server may do")

	var menu := _menu()
	var _p := menu.settings.set_value(&"field_of_view", 110)
	var _t := menu.settings.set_value(&"ui_theme", &"violet")
	menu.open(&"video")
	await get_tree().process_frame

	var clamped := menu.apply_server_rules({
		"clamps": {"field_of_view": 95, "sensitivity": 1.0},
		"rows_hidden": ["render_scale"], "pages_hidden": ["audio"],
		"themes": ["midnight", "contrast"], "leave_text": "Disconnect",
	})
	await get_tree().process_frame
	_check(clamped == PackedStringArray(["field_of_view"]), "it clamps what the policy allows, and only that")
	_check(menu.settings.get_int(&"field_of_view") == 95, "the game sees the bound")
	var fov := _row_control(menu, "field_of_view")
	var slider := fov.find_child("Slider", true, false) as HSlider
	_check(slider.value == 110.0, "the menu shows what the player chose, not the clamp")
	var notes := menu.screen.find_child("Body", true, false).find_children("*", "Label", true, false).filter(
		func(l: Node) -> bool: return (l as Label).text.contains("caps it at 95"))
	_check(notes.size() == 1, "and says the server caps it")
	_check(_row_control(menu, "render_scale") == null, "a row it hides is gone")
	_check(not menu.screen.visible_pages().any(func(p: DotMenuPage) -> bool: return p.id == &"audio"), "and a page")
	_check(menu.kit.palette.id == &"midnight", "a theme it does not offer is moved off, for this connection")
	_check(menu.settings.get_string(&"ui_theme") == "violet", "while the stored choice is untouched")
	var leave := menu.screen.find_child("Action_leave", true, false) as Button
	_check(leave.text == "Disconnect", "it may reword Leave")

	menu.release_server_rules()
	await get_tree().process_frame
	_check(menu.settings.get_int(&"field_of_view") == 110, "leaving gives the player's own value back")
	_check(menu.kit.palette.id == &"violet", "and their own theme")
	# Found again: the theme change rebuilt the screen, and the old button with it.
	leave = menu.screen.find_child("Action_leave", true, false) as Button
	_check(_row_control(menu, "render_scale") != null and leave.text == "Leave", "and everything it hid or reworded")
	_free_menu(menu)


func _test_help_and_picker() -> void:
	_section("Help and the picker")

	var menu := _menu()
	menu.help.add_section("Running", [["!r", "Restart"]], &"plain")
	menu.help.show_browser_tips = true
	menu.open_help([["rtv", "Vote to change the map"]], true)
	await get_tree().process_frame
	var texts: Array = menu.help.find_children("*", "Label", true, false).map(func(l: Node) -> String: return (l as Label).text)
	_check(texts.has("Flashlight") and texts.has("Menu and settings"), "every key, and Escape, which no row has")
	_check(texts.has("!rtv") and texts.has("RUNNING"), "the server's commands and the game's own card")
	_check(texts.has("Ctrl + W") and texts.any(func(t: String) -> bool: return t.contains("Duck is on Ctrl")),
		"and the browser card warns about the one shortcut a ducking player will press")

	var _r := menu.bindings.rebind(menu.bindings.row_for_action(&"test_flashlight"), "L", menu.settings)
	menu.help.close()
	menu.open_help(null, false)
	await get_tree().process_frame
	var caps: Array = menu.help.find_children("*", "Label", true, false).map(func(l: Node) -> String: return (l as Label).text)
	_check(caps.has("L"), "a key rebound a moment ago is shown where it is now")
	_check(caps.any(func(t: String) -> bool: return t.begins_with("You are playing offline")), "and offline it says why there are no commands")
	menu.help.close()

	var items: Array = []
	for i in 10:
		items.append({"id": "map_%d" % i, "name": "Map %d" % i, "tags": ["tier %d" % (i % 3)], "current": i == 8})
	var chosen: Array = []
	menu.picked.connect(func(id: StringName) -> void: chosen.append(id))
	menu.picker.instructions = "1–7, 8 and 9, 0 or M."
	menu.open_picker(items, "Change map")
	_check(menu.picker.page == 1, "the picker opens on the page with what is on now")
	_check(_texts(menu.picker).has("1–7, 8 and 9, 0 or M."), "in the game's own words, set after it was built")
	var _k := menu.handle_event(_key(KEY_8))
	_check(menu.picker.page == 0, "8 is the page before")
	var _k2 := menu.handle_event(_key(KEY_3))
	_check(chosen == [&"map_2"] and not menu.picker.is_open(), "a number picks its row and closes")
	menu.picker_action = &"test_flashlight"
	menu.open_picker(items, "Change map")
	var _k3 := menu.handle_event(_key(KEY_L))
	_check(not menu.picker.is_open() and chosen.size() == 1, "and the key that opened it closes it, choosing nothing")
	_free_menu(menu)
	await get_tree().process_frame


func _test_layout() -> void:
	_section("Moving the HUD")
	DotMenuKit._backdrop_shader()
	DotMenuKit.clear_cache()
	_check(DotMenuKit._shader == null, "clear_cache() drops the shared shader")
	_check(DotMenuKit._backdrop_shader() != null and DotMenuKit._shader != null, "and use refills it")

	var hud := FakeHud.new()
	add_child(hud)
	hud.size = Vector2(800, 800)
	var editor := DotMenuLayoutEditor.new()
	editor.target = hud
	editor.pieces = {&"timer": "Timer", &"keys": "Keys"}
	add_child(editor)
	var saved: Array = []
	editor.saved.connect(func(t: String) -> void: saved.append(t))

	_check(editor.piece_at(Vector2(400, 700)) == &"timer", "a piece is found under the pointer")
	editor.drag(&"timer", Vector2(400, 700), Vector2(200, 100))
	_check(hud.positions[&"timer"].is_equal_approx(Vector2(0.25, 0.125)), "a drag moves its centre, as a fraction of the screen")
	var decoded := DotMenuLayoutEditor.decode(saved[-1], [&"timer", &"keys"])
	_check(decoded[&"timer"].is_equal_approx(Vector2(0.25, 0.125)), "and is saved as text that reads back the same")
	_check(DotMenuLayoutEditor.decode('{"timer": [3, -1], "nope": [0.5, 0.5]}', [&"timer"]) == {&"timer": Vector2(1, 0)},
		"a hand-edited layout is held on screen, and a piece nobody has is dropped")
	_check(DotMenuLayoutEditor.decode("{ broken").is_empty(), "and one that does not parse is the default layout")
	editor.reset_all()
	_check(hud.positions.is_empty() and saved[-1] == "", "reset puts everything back")
	editor.queue_free()
	hud.queue_free()


func _test_settings_node() -> void:
	_section("One node for a game that has no presentation layer")

	var trimmed := DotMenuStock.declare(DotSettingsSchema.new(), DotMenuStock.DEFAULT_GROUPS, null,
		[&"ui_volume", &"shake_scale", &"allow_flashes", &"chat_window"] as Array[StringName])
	_check(not trimmed.has(&"ui_volume") and not trimmed.has(&"chat_window") and trimmed.has(&"sfx_volume"),
		"a game leaves out the stock keys it has nothing to apply to")
	var own := DotSettingsSchema.new()
	own.add(DotSettingsDef.number(&"shake_scale", 0.5, 0.0, 2.0, &"accessibility"))
	var _o := DotMenuStock.declare(own, DotMenuStock.DEFAULT_GROUPS, null, [&"shake_scale"] as Array[StringName])
	_check(own.has(&"shake_scale"), "but never one it declared itself")

	var node := DotMenuSettings.new()
	node.app_namespace = &"menu_settings_test"
	var schema := DotSettingsSchema.new()
	schema.add(DotSettingsDef.integer(&"field_of_view", 92, 70, 120, &"video").with_scope(DotSettingsDef.Scope.SERVER_CLAMPED))
	node.schema = DotMenuStock.declare(schema)
	add_child(node)
	var res := node.setup(DotSettingsStoreMemory.new())
	_check(res.ok and node.settings != null and node.applier != null and node.menu != null, "it builds the three")

	var look := FakeLook.new()
	var cam := FakeCamera.new()
	var mixer := FakeMixer.new()
	node.bind_look(look)
	node.bind_camera(cam)
	node.bind_audio(mixer)
	_check(cam.fov == 92.0 and is_equal_approx(look.mouse_sensitivity, 2.5 * DotMenuApplier.DEGREES_PER_COUNT)
		and is_equal_approx(mixer.master, 0.8), "anything bound is applied as it is bound, a game's own default included")
	var d := node.describe()
	_check(int(d["look_bound"]) == 1 and bool(d["camera_bound"]) and bool(d["audio_bound"]), "and says what is bound")

	var states: Array = []
	node.menu_state_changed.connect(func(open: bool) -> void: states.append(open))
	node.open(&"video")
	_check(node.is_open() and states == [true], "it opens the full menu")
	node.close()
	_check(not node.is_open() and states == [true, false], "and closes it")
	node.queue_free()
	await get_tree().process_frame


## Anything shaped like dot-server's DotClientLink, for the board's feed.
class FakeLink extends RefCounted:
	signal scoreboard_received(snapshot: Dictionary)
	var asked: Array = []
	var scoreboard: Dictionary = {}

	func want_scoreboard(open: bool) -> bool:
		asked.append(open)
		return true


func _snapshot() -> Dictionary:
	return {
		"server": {"name": "Test Server", "game": "Arena", "map": "dm_yard", "players": 4, "max": 16},
		"you": 3,
		"header": {"Time left": "4:12"},
		"teams": [{"id": 1, "name": "Red", "color": "#e05050", "score": 5}, {"id": 2, "name": "Blue", "color": [0.3, 0.5, 1.0], "score": 7}],
		"players": [
			{"id": 1, "name": "ada", "score": 10, "ping": 30, "seconds": 245, "team": 1},
			{"id": 2, "name": "bea", "score": 25, "ping": 250, "seconds": 3729, "team": 1},
			{"id": 3, "name": "cy", "score": 5, "ping": -1, "seconds": 12, "team": 2, "bot": false},
			{"id": 4, "name": "dot", "score": 0, "ping": 80, "seconds": 60, "team": 0},
		],
	}


func _texts(root: Node) -> Array:
	return root.find_children("*", "Label", true, false).filter(
		func(n: Node) -> bool: return not n.is_queued_for_deletion()).map(func(l: Node) -> String: return (l as Label).text)


func _test_scoreboard() -> void:
	_section("The scoreboard: held, themed, and the game's to change")

	_check(DotMenuScoreboard.duration(245) == "4:05" and DotMenuScoreboard.duration(3729) == "1:02:09"
		and DotMenuScoreboard.duration(-1) == "-", "time connected reads as a clock")

	var menu := _menu()
	menu.bindings.add(&"test_scores", &"bind_scores", "Scoreboard", "Tab", "Interface")
	menu.bindings.add_to_schema(menu.settings.schema)
	menu.bindings.apply_all(menu.settings)
	menu.scoreboard_action = &"test_scores"
	var board := menu.scoreboard
	var link := FakeLink.new()
	board.feed_from(link)

	var tab := _key(KEY_TAB)
	_check(menu.handle_event(tab) and board.is_open(), "Tab held shows it")
	_check(not menu.any_open(), "and it is not an overlay: the player keeps moving and the pointer stays")
	_check(link.asked == [true], "the server is told to start sending")
	link.scoreboard_received.emit(_snapshot())
	await get_tree().process_frame

	var texts := _texts(board)
	_check(texts.has("Test Server") and texts.any(func(t: String) -> bool: return t.contains("dm_yard") and t.contains("Time left 4:12")),
		"the server's name, its map and the round's own facts")
	_check(texts.has("4 / 16 players"), "and how full it is")
	_check(board.find_child("Team_1", true, false) != null and board.find_child("Team_2", true, false) != null,
		"a block per team")
	var red := board.find_child("Team_1", true, false)
	var red_names: Array = _texts(red).filter(func(t: String) -> bool: return t == "ada" or t == "bea")
	_check(red_names == ["bea", "ada"], "each ordered by score, best first")
	_check(texts.has("1:02:09") and texts.has("4:05") and texts.has("-"), "time connected and an unknown ping")
	var spect := board.find_child("Spectators", true, false) as Label
	_check(spect != null and spect.text.contains("dot"), "a player on no team is listed as spectating")
	var you_label: Label = null
	for l in board.find_children("*", "Label", true, false):
		if (l as Label).text == "cy":
			you_label = l
	_check(you_label != null and you_label.get_theme_color(&"font_color") == menu.kit.palette.accent, "this player is picked out")
	_check(board.ping_colour(30) == menu.kit.palette.hud_ahead and board.ping_colour(250) == menu.kit.palette.danger,
		"ping is coloured by how bad it is")

	var released := InputEventKey.new()
	released.physical_keycode = KEY_TAB
	released.keycode = KEY_TAB
	released.pressed = false
	_check(menu.handle_event(released) and not board.is_open(), "letting go of Tab hides it")
	_check(link.asked == [true, false], "and stops the server sending")

	board.add_column({"key": &"kills", "title": "K", "kind": DotMenuScoreboard.KIND_NUMBER}, &"score")
	board.add_column({"key": &"rank", "title": "Rank", "kind": DotMenuScoreboard.KIND_CUSTOM,
		"build": func(kit: DotMenuKit, row: Dictionary) -> Control: return kit.label("#%d" % int(row.get("rank", 0)))})
	board.decorate = func(row: Dictionary) -> void:
		row["kills"] = int(row.get("score", 0)) / 5
		row["rank"] = 9
	_check(board.columns.map(func(c: Dictionary) -> StringName: return c["key"]) == [&"avatar", &"name", &"kills", &"score", &"seconds", &"ping", &"rank"],
		"a game adds its own columns where it wants them")
	board.open()
	await get_tree().process_frame
	texts = _texts(board)
	_check(texts.has("#9") and texts.has("5"), "drawn from its own decoration and its own builder")
	board.close()
	board.prepare = func(snap: Dictionary) -> void:
		snap["teams"] = []
		snap["header"] = {"Course": "Ice Works"}
	board.open()
	await get_tree().process_frame
	texts = _texts(board)
	_check(board.find_child("Team_1", true, false) == null and texts.any(func(t: String) -> bool: return t.contains("Course Ice Works"))
		and (board.snapshot.get("teams", []) as Array).size() == 2,
		"the client can rewrite what is drawn without touching what the server sent")
	board.close()
	board.prepare = Callable()

	board.source = func() -> Dictionary:
		return {"players": [{"id": "me", "name": "Solo", "score": 3, "seconds": 30, "ping": -1}], "you": "me"}
	board.build_row = func(kit: DotMenuKit, row: Dictionary, _cols: Array) -> Control:
		return kit.label("ROW %s" % row["name"])
	board.open()
	await get_tree().process_frame
	texts = _texts(board)
	_check(texts.has("ROW Solo") and texts.has("Scoreboard"), "offline, the game's own snapshot and its own rows")
	link.scoreboard_received.emit(_snapshot())
	_check(board.rows().size() == 1, "and a source wins over the feed")

	# --- Columns a player hides ---
	board.build_row = Callable()
	board.source = func() -> Dictionary:
		return {"players": [{"id": "me", "name": "Solo", "score": 3, "seconds": 30, "ping": 77, "kills": 9, "rank": 4}], "you": "me"}
	board.add_column({"key": &"best", "title": "Best", "kind": DotMenuScoreboard.KIND_NUMBER, "hidden": true}, &"ping")
	board.open()
	await get_tree().process_frame
	texts = _texts(board)
	_check(not texts.has("Best") and texts.has("Ping") and texts.has("Score"), "a column the game starts hidden is not drawn")
	menu.open(&"general")
	await get_tree().process_frame
	_check(_row_control(menu, "scoreboard_col_ping") != null and _row_control(menu, "scoreboard_col_best") != null
		and _row_control(menu, "scoreboard_col_kills") != null,
		"Settings lists the live board's columns, the game's own included")
	_check(_row_control(menu, "scoreboard_col_name") == null and _row_control(menu, "scoreboard_col_avatar") == null,
		"but neither the required name nor an untitled column")
	var titles := menu.screen.find_children("*", "Label", true, false).map(func(l: Label) -> String: return l.text)
	_check(titles.has("Ping") and titles.has("Time") and titles.has("Best"), "by the titles the board draws")
	menu.close()
	# Opening the menu puts a held board away; hold it again.
	board.open()

	var ping_off := menu.settings.set_value(DotMenuScoreboard.SETTING, "ping,seconds")
	await get_tree().process_frame
	texts = _texts(board)
	_check(ping_off.ok and not texts.has("Ping") and not texts.has("77") and not texts.has("Time") and not texts.has("0:30"),
		"a setting change redraws the open board: titles and rows lose the column")
	_check(texts.has("Score") and texts.has("Player") and texts.has("3") and texts.has("Solo") and texts.has("K"),
		"and the rest still lays out")
	_check(board.visible_columns().size() == board.columns.size() - 3, "visible_columns is the subset (ping, seconds, best)")

	var _nm := menu.settings.set_value(DotMenuScoreboard.SETTING, "name,score")
	await get_tree().process_frame
	texts = _texts(board)
	_check(texts.has("Player") and texts.has("Solo") and not texts.has("Score"), "the name column cannot be hidden")
	var _all := menu.settings.set_value(DotMenuScoreboard.SETTING, "avatar,name,score,seconds,ping,kills,rank,nonsense")
	await get_tree().process_frame
	_check(board.visible_columns().size() == 1 and _texts(board).has("Solo"), "any subset draws, an unknown key is ignored")

	var _show := menu.settings.set_value(DotMenuScoreboard.SETTING, "+best")
	await get_tree().process_frame
	texts = _texts(board)
	_check(texts.has("Best") and texts.has("Ping"), "the player's choice overrides the game's default-hidden")
	var _toggle := menu.settings.set_value(DotMenuScoreboard.SETTING, "")
	menu.scoreboard_column_rows()[0].setter.call(false)
	_check(DotMenuScoreboard.parse_choices(menu.settings.get_string(DotMenuScoreboard.SETTING, "")).size() == 1,
		"a Settings switch writes the setting")

	var req := DotMenuScoreboard.column_required({"key": &"score", "required": true})
	_check(req and DotMenuScoreboard.column_required({"key": &"name"}) and not DotMenuScoreboard.column_required({"key": &"name", "required": false}),
		"required defaults on for the name column only")
	var rt := DotMenuScoreboard.parse_choices(DotMenuScoreboard.format_choices({&"ping": true, &"best": false}))
	_check(rt == {&"ping": true, &"best": false}, "the stored text round-trips")

	# Persisted: a second manager over the same store sees the choice.
	var store := DotSettingsStoreMemory.new()
	var m1 := DotMenuStock.manager(_schema(DotMenuStock.DEFAULT_GROUPS), "", &"menu_persist", &"", store)
	add_child(m1)
	var _s1 := m1.setup()
	var _w := m1.set_value(DotMenuScoreboard.SETTING, "ping,+best")
	var _f := m1.flush()
	var m2 := DotMenuStock.manager(_schema(DotMenuStock.DEFAULT_GROUPS), "", &"menu_persist", &"", store)
	add_child(m2)
	var _s2 := m2.setup()
	_check(m2.get_string(DotMenuScoreboard.SETTING, "") == "ping,+best", "the choice survives a restart")
	m1.queue_free()
	m2.queue_free()
	board.player_hidden = {}
	board.remove_column(&"best")

	var _e := menu.handle_event(_key(KEY_ESCAPE))
	_check(menu.is_open() and not board.is_open(), "Escape while it is held opens the menu instead")
	var _c := menu.handle_event(_key(KEY_ESCAPE))

	var _t := menu.cycle_theme()
	_check(board.kit == menu.kit, "and a theme change reaches it")
	_free_menu(menu)
	await get_tree().process_frame


## net_stat is three settings, one overlay and a meter. What is asserted is the wiring and
## the arithmetic; how it LOOKS is tools/screenshot.sh's (shot net_stat_*).
func _test_net_stat() -> void:
	_section("net_stat: three settings, one overlay, a meter")

	var menu := _menu()
	var st := menu.settings
	var ns := menu.net_stat
	_check(st.schema.has(&"net_stat") and st.schema.has(&"net_stat_height") and st.schema.has(&"net_stat_position"),
		"the interface group declares net_stat and its height and corner")
	_check(ns != null and not ns.visible and st.get_int(&"net_stat") == 0, "and it starts off")

	menu.open(&"advanced")
	await get_tree().process_frame
	_check(_row_control(menu, "net_stat") != null and _row_control(menu, "net_stat_height") != null,
		"the Advanced page shows the level and the height")
	menu.close()

	var _fps := st.set_value(&"show_fps", true)
	var _two := st.set_value(&"net_stat", 2)
	_check(ns.visible and ns.level == DotMenuNetStat.Level.GRAPH, "net_stat 2 draws the graph")
	_check(not menu._fps_label.visible, "and the frame counter steps aside: net_stat shows the frame rate itself")

	# What a console sends: the line's argument, as text.
	var three := st.set_value(&"net_stat", "3")
	_check(three.ok and ns.level == DotMenuNetStat.Level.FULL, "\"3\" typed at a console is level 3")

	var _h := st.set_value(&"net_stat_height", 160)
	await get_tree().process_frame
	_check(ns.graph_height == 160 and is_equal_approx(ns.size.y, ns.panel_height()) and ns.size.y > 160.0,
		"the height setting is the graph's, and the panel grows around it (%.0f px)" % ns.size.y)
	_check(ns.size.x > 200.0, "and it has a width: anchors alone draw nothing")

	var _c := st.set_value(&"net_stat_position", &"top_left")
	_check(is_zero_approx(ns.anchor_left) and is_zero_approx(ns.anchor_top) and ns.offset_left > 0.0,
		"the corner setting moves it")
	var bad := st.set_value(&"net_stat_position", &"middle")
	_check(not bad.ok or ns.corner == &"top_left", "a corner that is not one is refused")

	# A meter fed by hand: 4 KB on the state channel and 512 B of control a bucket, 40 ms ping.
	var meter := DotMeteredPeer.new()
	meter.note_rtt(40.0)
	ns.source = func() -> Object: return meter
	ns.reset()
	for i in 25:
		meter.bytes_in_by_channel[1] += 4096
		meter.bytes_in_by_channel[0] += 512
		meter.bytes_in += 4608
		meter.packets_in += 2
		meter.bytes_out_by_channel[0] += 100
		meter.packets_out += 1
		ns._push(meter)
	var d := ns.describe()
	_check(bool(d["connected"]) and is_equal_approx(float(d["rtt"]), 40.0), "it reads the meter it is given (%s)" % [d])
	# A held ping is one sample, not one a bar: the line marks where it was measured.
	var fresh := 0
	for b: Dictionary in ns._buckets:
		fresh += 1 if bool(b.get("fresh", false)) else 0
	_check(fresh == 1, "a ping held across bars is marked as one sample (%d)" % fresh)
	# Twenty-five bars, so the last second (twenty) is all traffic: the first only takes the
	# baseline, because a meter's totals are not arrivals since a bar.
	_check(is_equal_approx(float(d["in_rate"]), 4608.0 / ns.bucket_sec) and is_equal_approx(float(d["out_rate"]), 100.0 / ns.bucket_sec),
		"in and out are bytes a second over the last second's bars (%.0f, %.0f)" % [d["in_rate"], d["out_rate"]])
	var last: Dictionary = ns._buckets[ns._buckets.size() - 1]
	_check((last["in"] as PackedInt64Array)[1] == 4096 and (last["in"] as PackedInt64Array)[0] == 512,
		"and each bar keeps its channels apart")

	ns.source = func() -> Object: return null
	ns._push(null)
	_check(not bool(ns.describe()["connected"]), "with no meter it says so, not a flat line")

	# The frame clock on the wall clock: frames held to 25 ms by a busy wait read as 25 ms or
	# more, whatever the smoothed process delta says. Headless, so render is 0 and the busy
	# wait lands in the script part.
	_check(ns.frames.is_running(), "the frame clock runs while the panel is shown")
	var burn := func() -> void:
		var until := Time.get_ticks_usec() + 25000
		while Time.get_ticks_usec() < until:
			pass
	get_tree().process_frame.connect(burn)
	for _f in 12:
		await get_tree().process_frame
	get_tree().process_frame.disconnect(burn)
	var fc := ns.frames.summary(0.2)
	_check(int(fc["frames"]) >= 3 and float(fc["mean_ms"]) >= 24.0 and float(fc["fps"]) <= 41.0,
		"frame times are wall-clock times (%d frames, %.1f ms, %.1f fps)" % [fc["frames"], fc["mean_ms"], fc["fps"]])
	_check(float(fc["script_ms"]) >= 20.0 and float(fc["script_ms"]) <= float(fc["mean_ms"]) + 0.5,
		"and the busy wait is in the script part, inside the frame (%.1f of %.1f ms)" % [fc["script_ms"], fc["mean_ms"]])
	var held := Time.get_ticks_usec() + 60000
	while Time.get_ticks_usec() < held:
		pass
	await get_tree().process_frame
	await get_tree().process_frame
	_check(int(ns.frames.summary(1.0)["hitches"]) >= 1, "a 60 ms frame is counted as a hitch")

	# Prediction counters, from whatever the net source returns, per second.
	var fake := FakeNetManager.new()
	ns.net_source = func() -> Object: return fake
	ns._net_marks.clear()
	ns._push(null)
	fake.counters[&"replayed_ticks"] = 600
	fake.counters[&"snapshots"] = 20
	fake.counters[&"lead_ticks"] = 4
	await get_tree().create_timer(0.25).timeout
	ns._push(null)
	var net: Dictionary = ns.describe()["net"]
	_check(not net.is_empty() and float(net["replayed"]) > 600.0 and int(net["lead"]) == 4,
		"prediction cost is read from the manager's running totals, per second (%s)" % [net])
	ns.net_source = Callable()
	var px := int(ns.describe()["pixels_3d"])
	var win := get_window().size
	_check(px == win.x * win.y, "the 3D pixel count is the window's device pixels at scale 1 (%d)" % px)

	var _off := st.set_value(&"net_stat", 0)
	_check(not ns.visible and menu._fps_label.visible, "net_stat 0 hides it, and the counter comes back")

	_free_menu(menu)

	# A game with its own settings and no menu: declare the three, follow them.
	var own := DotSettingsSchema.new()
	own.add(DotSettingsDef.number(&"volume", 1.0, 0.0, 1.0, &"audio"))
	var _declared := DotMenuStock.declare_net_stat(own)
	var mine := _manager(own)
	var host := Node.new()
	add_child(host)
	var followed := DotMenuNetStat.follow(host, mine)
	var _lvl := mine.set_value(&"net_stat", 2)
	var _hh := mine.set_value(&"net_stat_height", 64)
	_check(followed.visible and followed.level == 2 and followed.graph_height == 64 and own.keys().size() == 4,
		"a game with no menu declares the three and follows them")
	host.queue_free()
	await get_tree().process_frame
	_check(mine.set_value(&"net_stat", 1).ok, "and a change after the overlay is gone is no error")
	mine.queue_free()


## Anything shaped like dot-voice's DotVoiceManager, as far as the applier and the menu care.
class FakeVoice extends Node:
	signal server_enabled_changed(enabled: bool)
	var server_enabled := true
	var open_mic_calls: Array = []
	var devices: Array = []
	func set_open_mic(on: bool) -> void:
		open_mic_calls.append(on)
	func set_input_device(device: String) -> bool:
		devices.append(device)
		return true
	func set_volume(_v: float) -> void:
		pass
	func tell(on: bool) -> void:
		server_enabled = on
		server_enabled_changed.emit(on)


func _test_voice() -> void:
	_section("Voice: the settings, the talk key, and a server that has it off")

	var schema := _schema()
	_check(schema.has(&"voice_mode") and schema.has(&"voice_input_device"), "the default groups declare voice_mode and voice_input_device")
	_check(DotMenuStock.audio_page().find_row(&"voice_mode") != null and DotMenuStock.audio_page().find_row(&"voice_input_device") != null,
		"and the Audio page has a row for each")

	var vpage := DotMenuStock.video_page()
	DotMenuStock.add_gore_row(vpage)
	_check(vpage.find_section(&"image").find_row(&"gore") != null, "add_gore_row puts the gore toggle in the Image section")
	DotMenuStock.add_gore_row(null)

	var node := DotMenuSettings.new()
	node.app_namespace = &"menu_voice_test"
	node.schema = DotMenuStock.declare(DotSettingsSchema.new())
	node.bindings = _keys()
	add_child(node)
	var res := node.setup(DotSettingsStoreMemory.new())
	_check(res.ok and not node.bindings.row_for_action(&"dot_voice_talk").is_empty(),
		"a game with the voice settings gets the Push to talk key in its table")
	_check(node.settings.schema.has(&"bind_voice_talk") and InputMap.has_action(&"dot_voice_talk"),
		"stored as bind_voice_talk, on the dot_voice_talk action")
	var talk_keys := InputMap.action_get_events(&"dot_voice_talk") if InputMap.has_action(&"dot_voice_talk") else []
	_check(talk_keys.size() == 1 and talk_keys[0] is InputEventKey and (talk_keys[0] as InputEventKey).physical_keycode == KEY_V,
		"on V by default")

	# Published after the menu: looked up in the registry, not handed over. Armed: nothing is called before it is published.
	var voice := FakeVoice.new()
	add_child(voice)
	_check(voice.open_mic_calls.is_empty(), "an unpublished voice is told nothing")
	DotRegistry.register(DotMenuApplier.VOICE_SERVICE, voice)
	_check(voice.open_mic_calls == [false] and voice.devices == ["Default"],
		"published as dot_voice_client, it is bound and told the stored mode and device (%s %s)" % [str(voice.open_mic_calls), str(voice.devices)])
	var _set := node.settings.set_value(&"voice_mode", &"open_mic")
	_check(voice.open_mic_calls.back() == true, "choosing an open microphone reaches it")

	voice.tell(false)
	var hidden: PackedStringArray = node.menu.screen.extra_hidden_rows
	_check(hidden.has("voice_mode") and hidden.has("bind_voice_talk") and hidden.has("voice_volume"),
		"the server turning voice off hides the voice rows and the talk key (%s)" % str(hidden))
	voice.tell(true)
	_check(node.menu.screen.extra_hidden_rows.is_empty(), "and on shows them again")

	node.menu.apply_server_rules({"rows_hidden": ["field_of_view"]})
	voice.tell(false)
	node.menu.release_server_rules()
	_check(node.menu.screen.extra_hidden_rows.has("voice_mode") and not node.menu.screen.extra_hidden_rows.has("field_of_view"),
		"leaving a server's rules keeps the voice rows hidden for their own reason")

	var taken := DotMenuBindings.new()
	taken.add(&"test_checkpoint", &"bind_checkpoint", "Go to checkpoint", "V", "Running")
	_check(taken.free_key(["V", "K", "B"]) == "K", "a game whose V is taken gets the talk key on the next free one")

	DotRegistry.unregister_instance(DotMenuApplier.VOICE_SERVICE, voice)
	voice.queue_free()
	node.queue_free()
	await get_tree().process_frame


## A game's help: the goal and a modes card, which only the game can say.
class FilledSettings extends DotMenuSettings:
	func _fill_help(h: DotMenuHelp) -> void:
		h.about = "Reach the far side first."
		h.add_text("Modes", "Race: first across wins. Relay: the team's total.")


## Shaped like a client link, for the stock Leave.
class FakeLeaveLink extends Node:
	var connected := true
	var left: Array = []

	func is_connected_to_server() -> bool:
		return connected

	func disconnect_from_server(reason: String = "") -> void:
		left.append(reason)
		connected = false


func _test_help_key_and_leave() -> void:
	_section("H is help in every game, and Leave is stock")

	var fresh := DotMenu.new()
	_check(fresh.help_action == DotMenuBindings.HELP_ACTION, "a menu's help key is dot_menu_help unless the game says otherwise")
	fresh.free()

	# A game with no table: DotMenuSettings gives it one with the help key, on H.
	if InputMap.has_action(DotMenuBindings.HELP_ACTION):
		InputMap.erase_action(DotMenuBindings.HELP_ACTION)
	var node := FilledSettings.new()
	node.app_namespace = &"menu_help_test"
	node.config = DotMenuConfig.new()
	node.config.brand_name = "Test Run"
	node.config.escape_grace_ms = 0
	add_child(node)
	var res := node.setup(DotSettingsStoreMemory.new())
	var row := node.bindings.row_for_action(DotMenuBindings.HELP_ACTION) if node.bindings != null else {}
	_check(res.ok and not row.is_empty() and str(row["default"]) == "H", "a game with no key table gets one holding the help key, on H")
	_check(node.settings.schema.has(DotMenuBindings.HELP_SETTING), "stored as bind_help, so the Controls page can rebind it")
	var hint := node.menu.help_hint
	_check(hint != null and hint.visible and _texts(hint).has("H") and _texts(hint).has("Help"),
		"the HUD shows the help key in a corner while nothing is open")
	_check(node.menu.handle_event(_key(KEY_H)) and node.menu.help.is_open(), "H opens help with nothing else open")
	_check(not hint.visible, "and the hint steps aside while help is up")
	await get_tree().process_frame
	var texts := _texts(node.menu.help)
	_check(texts.has("How to play Test Run") and texts.has("HOW TO PLAY") and texts.has("Reach the far side first."),
		"headed with the game's name, the goal first")
	_check(texts.has("MODES") and texts.has("Help and controls"), "the game's own card, and the help key on its key card")
	_check(node.menu.handle_event(_key(KEY_H)) and not node.menu.help.is_open(), "and H closes it again")
	var _r := node.bindings.rebind(row, "F2", node.settings)
	_check(not node.menu.handle_event(_key(KEY_H)) and node.menu.handle_event(_key(KEY_F2)) and node.menu.help.is_open(),
		"rebound, the new key opens help and H is the game's again")
	_check(_texts(hint).has("F2"), "and the hint says the new key")
	node.menu.help.close()
	await get_tree().process_frame

	# Leave: there, and worded for where the player is.
	var leave := node.menu.screen.find_child("Action_leave", true, false) as Button
	node.open()
	_check(leave != null and leave.visible and leave.text == ("" if DotPlatform.is_web() else "Quit game"),
		"Leave is in the stock menu, and solo on a desktop it quits")
	_check(node.menu.screen.find_child("Action_help", true, false) != null, "so is Help & commands")
	node.close()
	var link := FakeLeaveLink.new()
	add_child(link)
	node.menu.leave_link = link
	node.open()
	_check(leave.text == "Leave server", "connected, it leaves the server")
	node.menu.screen.action_requested.emit(&"leave")
	_check(link.left.size() == 1 and not node.menu.any_open(), "and pressing it disconnects and closes the menu")
	node.queue_free()
	link.queue_free()
	await get_tree().process_frame

	# A table with something on H already: help goes to the next free key, never onto H twice.
	var keys := DotMenuBindings.new()
	keys.add(&"test_heal", &"bind_heal", "Medkit", "H", "Hands")
	var taken := DotMenuSettings.new()
	taken.app_namespace = &"menu_help_taken_test"
	taken.bindings = keys
	add_child(taken)
	var _t := taken.setup(DotSettingsStoreMemory.new(), false)
	_check(keys.key_for(DotMenuBindings.HELP_ACTION) == "F1" and keys.defaults_on("H").size() == 1,
		"a table that already has H gets help on F1, and H stays on one row")
	taken.queue_free()

	# A game whose help row is its own action keeps it, and the menu opens on that.
	var own := DotMenuBindings.new()
	own.add(&"test_own_help", &"bind_help", "Help", "H", "Interface")
	var own_node := DotMenuSettings.new()
	own_node.app_namespace = &"menu_help_own_test"
	own_node.bindings = own
	add_child(own_node)
	var _o := own_node.setup(DotSettingsStoreMemory.new())
	_check(own.rows.filter(func(r: Dictionary) -> bool: return r["setting"] == &"bind_help").size() == 1
		and own_node.menu.help_action == &"test_own_help", "a game's own help row is kept, and is the menu's help key")
	own_node.queue_free()

	# A menu built by hand with no table still gets H.
	if InputMap.has_action(DotMenuBindings.HELP_ACTION):
		InputMap.erase_action(DotMenuBindings.HELP_ACTION)
	var bare := DotMenu.new()
	bare.manage_pointer = false
	add_child(bare)
	var _b := bare.setup()
	_check(bare.handle_event(_key(KEY_H)) and bare.help.is_open(), "a menu with no key table puts help on H itself")
	await get_tree().process_frame
	_check(_texts(bare.help).has("Help and controls"), "and lists it, since no row does")
	bare.help.close()
	bare.help.title_text = "How to play Later"
	bare.open_help()
	await get_tree().process_frame
	_check(_texts(bare.help).has("How to play Later"), "a heading set after the screen was built is the one drawn")
	bare.help.close()
	_check(bare.leave_label() == "Leave", "a menu that leaves the game's way keeps the config's word")
	var quiet := DotMenu.new()
	quiet.manage_pointer = false
	quiet.config = DotMenuConfig.new()
	quiet.config.help_hint = &"off"
	add_child(quiet)
	var _q := quiet.setup()
	_check(quiet.help_hint == null, "a game that lists the key in its own HUD turns the hint off")
	quiet.queue_free()
	bare.queue_free()
	await get_tree().process_frame


## Shaped like a client link for the map menu: what it was asked, and a notice signal.
class FakeMapLink extends Node:
	signal notice_received(notice: Object)
	var sent: Array = []

	func is_connected_to_server() -> bool:
		return true

	func send_chat(text: String, _team_only: bool = false) -> void:
		sent.append(text)

	func answer(data: Dictionary) -> void:
		var n := FakeNotice.new()
		n.topic = &"map_menu"
		n.data = data
		notice_received.emit(n)


class FakeNotice extends RefCounted:
	var topic: StringName = &""
	var data: Dictionary = {}


func _test_map_menu() -> void:
	_section("M is the map menu: solo changes, a server decides")

	# Every DotMenuSettings game gets the key, on M.
	for a in [DotMenuBindings.MAPS_ACTION, DotMenuBindings.HELP_ACTION]:
		if InputMap.has_action(a):
			InputMap.erase_action(a)
	var node := DotMenuSettings.new()
	node.app_namespace = &"menu_maps_test"
	node.config = DotMenuConfig.new()
	node.config.escape_grace_ms = 0
	add_child(node)
	var _s := node.setup(DotSettingsStoreMemory.new())
	var row := node.bindings.row_for_action(DotMenuBindings.MAPS_ACTION)
	_check(not row.is_empty() and str(row["default"]) == "M" and node.settings.schema.has(DotMenuBindings.MAPS_SETTING),
		"every game's table has the map key, on M, stored as bind_maps")
	_check(not node.menu.handle_event(_key(KEY_M)) and not node.menu.any_open(), "and M does nothing until the game hands it a list")

	var changed: Array = []
	var game_picks: Array = []
	node.menu.picked.connect(func(id: StringName) -> void: game_picks.append(id))
	var rows: Array = []
	for i in 9:
		rows.append({"id": "course_%d" % i, "name": "Course %d" % i, "mode": "Race" if i % 2 == 0 else "Relay",
			"current": i == 1, "thumbnail": ImageTexture.create_from_image(Image.create(16, 9, false, Image.FORMAT_RGB8)) if i == 0 else ""})
	var maps := node.use_maps(func() -> Array: return rows, func(id: StringName) -> DotResult:
		changed.append(id)
		return DotResult.success(id))
	_check(maps != null and node.menu.handle_event(_key(KEY_M)) and node.menu.picker.is_open(), "solo, M opens the picker")
	await get_tree().process_frame
	var texts := _texts(node.menu.picker)
	_check(texts.has("Change map — solo") and texts.has("Race") and texts.has("Relay"), "headed solo, each row with its mode")
	_check(node.menu.picker.find_children("*", "TextureRect", true, false).size() == 1
		and node.menu.picker.find_children("Thumb", "PanelContainer", true, false).size() == 7,
		"a picture where a map has one, and an empty frame of the same size where it does not")
	node.menu.picker.open([{"id": "a", "name": "A", "detail": "blurb"}, {"id": "b", "name": "B"}], "x")
	await get_tree().process_frame
	_check(node.menu.picker.find_children("Thumb", "PanelContainer", true, false).is_empty(),
		"and a page where no map has a picture draws no empty frames")
	node.menu.picker.visible = false
	maps.open()
	var _k := node.menu.handle_event(_key(KEY_3))
	await get_tree().process_frame
	_check(changed == [&"course_2"] and not node.menu.picker.is_open(), "a number changes to that map, directly")
	_check(game_picks.is_empty(), "and the choice never reaches the game's own picker handler")
	var _k2 := node.menu.handle_event(_key(KEY_M))
	var _k3 := node.menu.handle_event(_key(KEY_M))
	_check(not node.menu.picker.is_open() and changed.size() == 1, "M again closes it, changing nothing")

	var refuse := node.use_maps(func() -> Array: return rows, func(_id: StringName) -> DotResult:
		return DotResult.fail(DotError.CODE_STATE, "A round is being decided."))
	refuse.open()
	var _k4 := node.menu.handle_event(_key(KEY_1))
	await get_tree().process_frame
	_check(node.menu.toast_text() == "A round is being decided.", "a change the game refuses is said on screen")

	node.menu.toast("short", 0.05)
	_check(node.menu.toast_text() == "short", "a toast with a lifetime shows")
	await get_tree().create_timer(0.3).timeout
	_check(node.menu.toast_text() == "", "and expires when its time is up")
	node.menu.toast("first", 0.1)
	node.menu.toast("second", 5.0)
	await get_tree().create_timer(0.3).timeout
	_check(node.menu.toast_text() == "second", "an older toast's timer does not hide a newer one")

	# Connected: the server is asked, and its answer decides.
	var link := FakeMapLink.new()
	add_child(link)
	maps.link = link
	maps.change_fn = func(id: StringName) -> DotResult:
		changed.append(id)
		return DotResult.success(id)
	var _k5 := node.menu.handle_event(_key(KEY_M))
	_check(link.sent == ["/mapmenu"] and not node.menu.picker.is_open(), "online, M asks the server rather than opening a list of its own")
	link.answer({"maps": [{"id": "dm_atrium", "name": "Atrium", "current": true}, {"id": "dm_yard", "name": "Yard"}],
		"allowed": true, "flag": "generic", "vote": true, "where": "this server"})
	await get_tree().process_frame
	_check(node.menu.picker.is_open() and _texts(node.menu.picker).has("Change map — this server"), "allowed, the server's list opens to change")
	var _k6 := node.menu.handle_event(_key(KEY_2))
	_check(link.sent.back() == "/mapmenu dm_yard" and changed.size() == 1, "and a choice is the server's to make, not this client's")
	# A long list comes in parts and opens once, whole.
	link.answer({"maps": [{"id": "a1", "name": "A1"}], "allowed": true, "flag": "generic", "vote": true, "part": 1, "parts": 2})
	var half_open := node.menu.picker.is_open()
	link.answer({"maps": [{"id": "a2", "name": "A2"}, {"id": "a3", "name": "A3"}], "allowed": true, "flag": "generic", "vote": true, "part": 2, "parts": 2})
	_check(not half_open and node.menu.picker.is_open() and node.menu.picker.items.size() == 3,
		"a list sent in parts opens once, with every part")
	node.menu.picker.close()
	link.answer({"result": {"ok": true, "text": "Changing to Yard."}})
	_check(node.menu.toast_text() == "Changing to Yard.", "what the server did is said on screen")

	link.answer({"maps": [{"id": "dm_atrium", "name": "Atrium"}, {"id": "dm_yard", "name": "Yard"}],
		"allowed": false, "flag": "generic", "vote": true, "where": "this server"})
	await get_tree().process_frame
	texts = _texts(node.menu.picker)
	_check(node.menu.picker.is_open() and texts.has("Vote for a map — this server")
		and texts.any(func(t: String) -> bool: return t.contains("'generic'") and t.contains("rocks the vote")),
		"without the owner's flag it is a vote, and it says which flag")
	node.menu.picker.close()
	link.answer({"maps": [{"id": "dm_yard", "name": "Yard"}], "allowed": false, "flag": "changemap", "vote": false})
	_check(not node.menu.picker.is_open() and node.menu.toast_text().contains("'changemap'"),
		"with no flag and no vote, the refusal is shown and nothing opens")

	await _test_map_menu_without_table(rows)
	link.queue_free()
	node.queue_free()
	await get_tree().process_frame


## The map key on a menu with no key table, and on a table that already has M.
func _test_map_menu_without_table(rows: Array) -> void:
	# A menu built by hand with no table still gets M once the game hands it a list.
	if InputMap.has_action(DotMenuBindings.MAPS_ACTION):
		InputMap.erase_action(DotMenuBindings.MAPS_ACTION)
	var bare := DotMenu.new()
	bare.manage_pointer = false
	add_child(bare)
	var _b := bare.setup()
	var _u := bare.use_maps(func() -> Array: return rows, func(id: StringName) -> DotResult: return DotResult.success(id))
	_check(bare.handle_event(_key(KEY_M)) and bare.picker.is_open(), "a menu with no key table puts the map menu on M itself")
	bare.picker.close()
	bare.open_help()
	await get_tree().process_frame
	_check(_texts(bare.help).has("Change map"), "and lists it on the help screen, since no row does")
	bare.help.close()

	# A table with something on M already: the map key goes to F3, never onto M twice.
	var keys := DotMenuBindings.new()
	keys.add(&"test_mark", &"bind_mark", "Mark", "M", "Hands")
	var taken := DotMenuSettings.new()
	taken.app_namespace = &"menu_maps_taken_test"
	taken.bindings = keys
	add_child(taken)
	var _t := taken.setup(DotSettingsStoreMemory.new(), false)
	_check(keys.key_for(DotMenuBindings.MAPS_ACTION) == "F3" and keys.defaults_on("M").size() == 1,
		"a table that already has M gets the map key on F3 (each game's suite fails on that, so move the game's own)")
	taken.queue_free()
	bare.queue_free()


## Contrast ratio of [param fg] over [param plate] laid on [param ground], in linear light.
func _contrast(fg: Color, plate: Color, ground: Color) -> float:
	var under := ground.lerp(Color(plate, 1.0), plate.a)
	var a := fg.srgb_to_linear().get_luminance()
	var b := under.srgb_to_linear().get_luminance()
	return (maxf(a, b) + 0.05) / (minf(a, b) + 0.05)


func _test_hud_follows() -> void:
	_section("The HUD follows the theme")

	var t := DotMenuThemes.stock()
	var midnight := t.named(&"midnight")
	_check(midnight.hud_plate.get_luminance() < 0.1 and midnight.hud_plate.a >= 0.7 and midnight.hud_keycap.get_luminance() < 0.3,
		"the default theme's HUD is dark: deep plates and dark key caps")
	_check(t.find(&"arcade") != null and t.named(&"arcade").hud_team_fill >= 0.99 and t.named(&"arcade").hud_keycap.get_luminance() > 0.8,
		"and the first bright HUD is kept as a theme a player can pick")
	var unreadable := PackedStringArray()
	for id in t.ids():
		var p := t.named(id)
		for ground in [Color.WHITE, Color.BLACK, Color(0.75, 0.8, 0.9)]:
			if _contrast(p.hud_text, p.hud_plate, ground) < 4.5:
				unreadable.append("%s on %s" % [id, ground.to_html(false)])
	_check(unreadable.is_empty(), "every stock theme's HUD words read on their plate over a white, a black and a pale-blue map (%s)" % ", ".join(unreadable))

	var again := DotMenuPalette.from_dictionary(midnight.to_dictionary())
	_check(again.ok and is_equal_approx(again.value.hud_team_fill, midnight.hud_team_fill) and again.value.hud_keycap_edge.to_html() == midnight.hud_keycap_edge.to_html(),
		"the HUD's numbers and colours survive a round trip through the theme's data")
	_check(not DotMenuPalette.from_dictionary({"id": "x", "hud_team_fill": "lots"}).ok, "and a number nobody can read is refused")

	var menu := _menu()
	var root := Control.new()
	root.size = Vector2(1280.0, 720.0)
	add_child(root)
	var vitals := DotVitals.new()
	root.add_child(vitals)
	var words := Label.new()
	root.add_child(words)
	var accent := Theme.new()
	accent.set_color(&"highlight", DotHudPiece.THEME_TYPE, Color.MAGENTA)
	menu.follow_hud(root, accent)
	var hud := DotHud.new()
	add_child(hud)
	menu.follow_hud(hud)
	_check(menu.followed_huds().size() == 2, "a game hands the menu its HUD roots")
	_check(vitals.colour(&"plate") == midnight.hud_plate and vitals.colour(&"keycap") == midnight.hud_keycap,
		"a piece under a followed root draws in the theme's HUD colours")
	_check(vitals.colour(&"highlight") == Color.MAGENTA, "and in the game's own accent")
	_check(words.get_theme_color(&"font_color") == midnight.hud_text and words.get_theme_constant(&"outline_size") > 0,
		"and a plain Label under it reads the theme's text, outlined")

	var _set := menu.settings.set_value(&"ui_theme", &"paper")
	var paper := t.named(&"paper")
	_check(vitals.colour(&"plate") == paper.hud_plate and vitals.colour(&"text") == paper.hud_text,
		"a theme picked in the menu reaches the piece at once")
	_check(vitals.colour(&"highlight") == Color.MAGENTA, "and the game keeps its accent in every theme")
	_check(words.get_theme_color(&"font_color") == paper.hud_text, "and the Label follows too")
	var _key := menu.cycle_theme()
	_check(vitals.colour(&"plate") == menu.palette().hud_plate, "the theme key reaches it as well")
	var _arc := menu.settings.set_value(&"ui_theme", &"arcade")
	_check(vitals.number(&"team_fill") == 100, "under Arcade the score plates are painted, as the first HUD's were")
	_set = menu.settings.set_value(&"ui_theme", &"midnight")
	_check(vitals.number(&"team_fill") < 50, "and under the default they are tinted")

	_check(menu.settings.schema.has(&"hud_scale") and is_equal_approx(menu.hud_scale(), 1.0), "the HUD size is a stock setting, 1 by default")
	_check(is_equal_approx(root.scale.x, 1.0), "and a HUD at size 1 is left as the game laid it out")
	_set = menu.settings.set_value(&"hud_scale", 1.2)
	_check(is_equal_approx(root.scale.x, 1.2) and is_equal_approx(hud.user_scale, 1.2), "a new size reaches a plain root and a DotHud")
	var frame := root.get_viewport().get_visible_rect().size
	_check(absf(root.size.x * root.scale.x - frame.x) < 1.0, "and the plain root still spans the frame")
	_set = menu.settings.set_value(&"hud_scale", 1.0)
	_check(is_equal_approx(root.scale.x, 1.0) and is_equal_approx(hud.user_scale, 1.0), "and back")

	menu.unfollow_hud(root)
	_set = menu.settings.set_value(&"ui_theme", &"contrast")
	_check(vitals.colour(&"plate") != t.named(&"contrast").hud_plate, "a root no longer followed keeps what it had")
	hud.free()
	_check(menu.followed_huds().is_empty(), "and a freed one drops out")
	root.queue_free()
	_free_menu(menu)
	await get_tree().process_frame


func _old_document_manager(schema: DotSettingsSchema, values: Dictionary) -> DotSettingsManager:
	# A document from before documents recorded their defaults: values only.
	var store := DotSettingsStoreMemory.new()
	var _saved := store.save_document(&"moved", &"local", {"version": 1, "values": values})
	var m := DotSettingsManager.new()
	m.schema = schema
	m.local_store = store
	m.app_namespace = &"moved"
	m.persist = false
	m.register_as_service = false
	add_child(m)
	var _res := m.setup()
	return m


func _medkit_keys() -> DotMenuBindings:
	var k := DotMenuBindings.new()
	k.add(&"test_use", &"bind_use", "Use", "E", "Hands")
	k.add(&"test_heal", &"bind_heal", "Medkit", "G", "Hands")
	k.add_help("Hands")
	return k


func _test_moved_defaults() -> void:
	_section("A default that moved under a saved document")

	# Declared: the medkit's default was H until help took it.
	var k := _medkit_keys().renamed(&"bind_heal", ["H"])
	var s := DotSettingsSchema.new()
	k.add_to_schema(s)
	_check(s.find(&"bind_heal").previous_defaults == ["H"], "a renamed default reaches the setting's declaration")
	var m := _old_document_manager(s, {"bind_help": "H", "bind_heal": "H", "bind_use": "Q"})
	k.apply_all(m)
	_check(m.get_string(&"bind_heal") == "G" and k.key_for(&"test_heal") == "G",
		"an old file with the medkit on H puts it on its new default, G")
	_check(m.get_string(&"bind_help") == "H" and k.key_for(DotMenuBindings.HELP_ACTION) == "H", "and help keeps H")
	_check(m.get_string(&"bind_use") == "Q" and k.key_for(&"test_use") == "Q", "a key the player chose is kept")
	m.queue_free()

	# Not declared: the conflict check on load settles it the same way.
	var k2 := _medkit_keys()
	var s2 := DotSettingsSchema.new()
	k2.add_to_schema(s2)
	var m2 := _old_document_manager(s2, {"bind_help": "H", "bind_heal": "H", "bind_use": "Q"})
	var moved := k2.settle(m2)
	_check(moved.size() == 1 and m2.get_string(&"bind_heal") == "G" and m2.get_string(&"bind_help") == "H",
		"two rows on one key: the row whose default it is keeps it, the other goes to its default (%s)" % ", ".join(moved))
	_check(m2.get_string(&"bind_use") == "Q", "and a chosen key nobody else is on stays")
	_check(k2.settle(m2).is_empty(), "settling twice moves nothing")
	m2.queue_free()

	# Two of the player's own choices on one key, neither a default (a file edited by hand):
	# the first row in the table keeps it.
	var k3 := _medkit_keys()
	var s3 := DotSettingsSchema.new()
	k3.add_to_schema(s3)
	var m3 := _old_document_manager(s3, {"bind_use": "J", "bind_heal": "J"})
	var _m3 := k3.settle(m3)
	_check(m3.get_string(&"bind_use") == "J" and m3.get_string(&"bind_heal") == "G", "with no owner, the first row keeps the key")
	m3.queue_free()

	# A table that ships two rows on one default meant it.
	var k4 := DotMenuBindings.new()
	k4.add(&"test_a", &"bind_a", "A", "Q", "Hands")
	k4.add(&"test_b", &"bind_b", "B", "Q", "Hands")
	var s4 := DotSettingsSchema.new()
	k4.add_to_schema(s4)
	var m4 := _old_document_manager(s4, {})
	_check(k4.settle(m4).is_empty(), "rows that all default to the key are left alone")
	m4.queue_free()

	# The applier settles too: it is what DotMenuSettings and the presentations boot through.
	var k5 := _medkit_keys()
	var s5 := DotSettingsSchema.new()
	k5.add_to_schema(s5)
	var m5 := _old_document_manager(s5, {"bind_heal": "H"})
	var ap := DotMenuApplier.new()
	ap.settings = m5
	ap.bindings = k5
	ap.apply_all()
	_check(m5.get_string(&"bind_heal") == "G", "DotMenuApplier.apply_all settles before applying")
	ap.free()
	m5.queue_free()


func _section(title: String) -> void:
	_section_count += 1
	_line("[%d] %s" % [_section_count, title])


func _check(ok: bool, what: String) -> void:
	if ok:
		_passed += 1
		_line("    ok    %s" % what)
	else:
		_failed += 1
		_line("    FAIL  %s" % what)


func _line(text: String) -> void:
	print(text)


class FakeLoadoutLink extends Node:
	signal notice_received(notice: Object)
	var sent: Array = []

	func is_connected_to_server() -> bool:
		return true

	func send_chat(text: String, _team_only: bool = false) -> void:
		sent.append(text)

	func answer(data: Dictionary) -> void:
		var n := FakeNotice.new()
		n.topic = &"loadout_menu"
		n.data = data
		notice_received.emit(n)


static func _loadout_offer(choose: bool = true) -> Dictionary:
	return {
		"choose": choose, "budget": 7, "note": "",
		"slots": [
			{"id": "primary", "name": "Primary", "current": "rifle", "fixed": false, "choices": [
				{"id": "rifle", "name": "Rifle", "cost": 2, "tags": ["automatic"]},
				{"id": "sniper", "name": "Long Rifle", "cost": 6, "tags": ["scoped"]},
				{"id": "launcher", "name": "Launcher", "cost": 4, "tags": ["explosive"]}]},
			{"id": "secondary", "name": "Sidearm", "current": "pistol", "fixed": false, "choices": [
				{"id": "pistol", "name": "Pistol", "cost": 1}, {"id": "revolver", "name": "Revolver", "cost": 1}]},
			{"id": "thrown", "name": "Grenades", "current": "frag", "fixed": true, "choices": [
				{"id": "frag", "name": "Frag", "cost": 1}]},
		],
	}


func _test_avatar_action_keys() -> void:
	_section("comma, period and slash are the emote, pose and gesture rows")
	var node := DotMenuSettings.new()
	node.app_namespace = &"menu_avatar_test"
	node.avatar_actions = true
	node.config = DotMenuConfig.new()
	add_child(node)
	var _s := node.setup(DotSettingsStoreMemory.new(), false)
	var want := {DotMenuBindings.AVATAR_EMOTE_ACTION: KEY_COMMA, DotMenuBindings.AVATAR_POSE_ACTION: KEY_PERIOD,
		DotMenuBindings.AVATAR_GESTURE_ACTION: KEY_SLASH}
	var good := true
	for action in want:
		var row := node.bindings.row_for_action(action)
		var ev := DotInputBinding.from_text(str(row.get("default", ""))) as InputEventKey
		good = good and ev != null and ev.physical_keycode == want[action]
	_check(good, "each default reads back as its key")
	_check(node.settings.schema.has(DotMenuBindings.AVATAR_GESTURE_SETTING), "stored as bind_avatar_gesture")
	var plain := DotMenuSettings.new()
	plain.app_namespace = &"menu_avatar_off"
	plain.config = DotMenuConfig.new()
	add_child(plain)
	var _t := plain.setup(DotSettingsStoreMemory.new(), false)
	_check(plain.bindings.row_for_action(DotMenuBindings.AVATAR_EMOTE_ACTION).is_empty(), "a game that does not ask has none")
	node.queue_free()
	plain.queue_free()


func _test_loadout_menu() -> void:
	_section("B is the loadout menu: cards, the budget, a draft sent on close")

	if FileAccess.file_exists(DotMenuLoadout.REMEMBER_FILE):
		var _rm := DirAccess.remove_absolute(DotMenuLoadout.REMEMBER_FILE)
	for a in [DotMenuBindings.LOADOUT_ACTION, DotMenuBindings.HELP_ACTION, DotMenuBindings.MAPS_ACTION]:
		if InputMap.has_action(a):
			InputMap.erase_action(a)
	var node := DotMenuSettings.new()
	node.app_namespace = &"menu_loadout_test"
	node.loadout_menu = true
	node.config = DotMenuConfig.new()
	node.config.escape_grace_ms = 0
	add_child(node)
	var _s := node.setup(DotSettingsStoreMemory.new())
	var row := node.bindings.row_for_action(DotMenuBindings.LOADOUT_ACTION)
	_check(not row.is_empty() and str(row["default"]) == "B" and node.settings.schema.has(DotMenuBindings.LOADOUT_SETTING),
		"a game that asks for it has the loadout key in its table, on B, stored as bind_loadout")
	_check(not node.menu.handle_event(_key(KEY_B)) and not node.menu.any_open(), "and B does nothing until the game hands it an offer")

	var saved: Array = []
	var icon := ImageTexture.create_from_image(Image.create(32, 16, false, Image.FORMAT_RGB8))
	var lo := node.use_loadout(
		func() -> Dictionary: return _loadout_offer(),
		func(picks: Dictionary) -> Dictionary:
			saved.append(picks)
			return {"ok": true, "text": "Loadout equipped.", "now": true},
		func(_slot: String, choice: Dictionary) -> Dictionary:
			return {"icon": icon if choice["id"] == "rifle" else null,
				"stats": [{"label": "Damage", "value": 0.4 if choice["id"] == "rifle" else 0.9, "text": "x"}]})
	lo.remember_as("menu_test", "acct")
	var screen := node.menu.loadout_screen
	_check(lo != null and node.menu.handle_event(_key(KEY_B)) and screen.is_open() and node.menu.any_open(), "solo, B opens the loadout screen")
	await get_tree().process_frame
	var texts := _texts(screen)
	_check(texts.has("PRIMARY") and texts.has("SIDEARM") and texts.has("GRENADES  ·  SERVER"), "every slot is a tab, a fixed one marked as the server's")
	_check(texts.has("EQUIPPED") and texts.has("6 pt") and texts.has("4 / 7 points"), "the cards say what is equipped, what each costs, and the budget")
	_check(screen.find_children("*", "TextureRect", true, false).size() >= 2, "a card with art shows it (the card, the tab and the detail)")
	_check(screen.find_children("Stats", "VBoxContainer", true, false).size() == 1, "and the highlighted card has its statistics drawn")

	var _r := screen.handle_key(_key(KEY_RIGHT))
	var _a := screen.handle_key(_key(KEY_ENTER))
	await get_tree().process_frame
	_check(screen.draft.get("primary") == "rifle" and str(screen.describe()["status"]).contains("over the budget"),
		"a card over the budget is refused, saying by how much")
	_r = screen.handle_key(_key(KEY_RIGHT))
	_a = screen.handle_key(_key(KEY_ENTER))
	_check(screen.draft.get("primary") == "launcher" and screen.points_with() == 6, "a card within it goes in the draft")
	var _three := screen.handle_key(_key(KEY_3))
	_a = screen.handle_key(_key(KEY_ENTER))
	_check(screen.current_slot()["id"] == "thrown" and str(screen.describe()["status"]).contains("server sets"),
		"a number picks the slot, and a fixed slot cannot be changed")
	var _q := screen.handle_key(_key(KEY_Q))
	var _d := screen.handle_key(_key(KEY_DOWN))
	_check(screen.current_slot()["id"] == "secondary", "Q goes back a slot")
	var _back := screen.handle_key(_key(KEY_BACKSPACE))
	_check(screen.changes().is_empty(), "Backspace puts the draft back as it opened")
	var _one := screen.handle_key(_key(KEY_1))
	var _c := screen.pick(2)
	node.menu.use_theme(&"paper")
	await get_tree().process_frame
	_check(screen.is_open() and screen.kit.palette.id == &"paper" and _texts(screen).has("Launcher"), "a theme change redraws it open")
	var _close := screen.handle_key(_key(KEY_B))
	await get_tree().process_frame
	_check(not screen.is_open() and saved == [{"primary": "launcher"}], "B again closes it and sends the changed slot, once")
	_check(node.menu.toast_text() == "Loadout equipped.", "and what the game did is said on screen")
	_check(lo.remembered() == {"primary": "launcher", "secondary": "pistol"}, "the choice is remembered for this account, fixed slots left to the server")

	saved.clear()
	lo.open()
	await get_tree().process_frame
	var _esc := screen.handle_key(_key(KEY_ESCAPE))
	_check(not screen.is_open() and saved.is_empty(), "closing with nothing changed sends nothing")
	var restored: bool = await lo.restore()
	_check(restored and saved == [{"primary": "launcher", "secondary": "pistol"}], "restore() sends the remembered choice again")

	saved.clear()
	lo.open_offer(_loadout_offer(false))
	var _p := screen.pick(2)
	screen.close()
	_check(saved.is_empty() and lo.last_offer["choose"] == false, "when the server sets every loadout, nothing can be picked or sent")

	var link := FakeLoadoutLink.new()
	add_child(link)
	lo.link = link
	_check(node.menu.handle_event(_key(KEY_B)) and link.sent == ["/loadout"] and not screen.is_open(), "online, B asks the server")
	link.answer(_loadout_offer())
	await get_tree().process_frame
	_check(screen.is_open() and lo.last_offer["slots"][0]["choices"][0].has("stats"), "and opens on its offer, with this client's art and numbers")
	_one = screen.handle_key(_key(KEY_2))
	_c = screen.pick(1)
	screen.close()
	_check(link.sent.back() == "/loadout secondary=revolver" and saved.is_empty(), "a choice is the server's to take, not this client's")
	link.answer({"result": {"ok": false, "text": "This server does not allow 'revolver' in the secondary slot."}})
	_check(node.menu.toast_text().contains("does not allow"), "and a refusal is said on screen")
	load("res://examples/loadout_random_checks.gd").run(self, screen, lo, link)
	# A menu built by hand with no table still gets B once the game hands it an offer.
	if InputMap.has_action(DotMenuBindings.LOADOUT_ACTION):
		InputMap.erase_action(DotMenuBindings.LOADOUT_ACTION)
	var bare := DotMenu.new()
	bare.manage_pointer = false
	add_child(bare)
	var _b := bare.setup()
	var _u := bare.use_loadout(func() -> Dictionary: return _loadout_offer(), func(_p2: Dictionary) -> bool: return true)
	_check(bare.handle_event(_key(KEY_B)) and bare.loadout_screen.is_open(), "a menu with no key table puts the loadout on B itself")
	bare.loadout_screen.cancel()
	bare.open_help()
	await get_tree().process_frame
	_check(_texts(bare.help).has("Loadout"), "and lists it on the help screen")
	bare.help.close()
	_check(node.menu.describe().has("loadout"), "describe() says what the loadout menu is doing")

	if FileAccess.file_exists(DotMenuLoadout.REMEMBER_FILE):
		var _rm2 := DirAccess.remove_absolute(DotMenuLoadout.REMEMBER_FILE)
	bare.queue_free()
	link.queue_free()
	node.queue_free()
	await get_tree().process_frame


## What net_stat reads from a dot-net manager, and nothing else.
class FakeNetManager extends RefCounted:
	var is_server := false
	var counters := {&"snapshots": 0, &"snapshot_usec": 0, &"reconciles": 0, &"reconcile_usec": 0,
		&"replayed_ticks": 0, &"client_ticks": 0, &"predict_usec": 0, &"lead_ticks": 0}

	func perf_counters() -> Dictionary:
		return counters.duplicate()


func _wheel(index: MouseButton) -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.button_index = index
	e.pressed = true
	return e


func _on_action(action: StringName, text: String) -> bool:
	var ev := DotInputBinding.from_text(text)
	for other in InputMap.action_get_events(action):
		if DotMenuBindings.same_input(ev, other):
			return true
	return false


func _test_wheel() -> void:
	_section("Extra keys and the wheel")

	# A game with nothing to switch: the wheel also jumps.
	var k := _keys().add_wheel_jump()
	var labels: Array = []
	for row in k.rows_in("Movement"):
		labels.append(str(row["label"]))
	_check(labels.slice(4, 7) == ["Jump", "Jump (wheel up)", "Jump (wheel down)"],
		"the wheel's jump rows are drawn right after Jump (%s)" % [labels])
	_check(k.row_for_action(&"dot_fps_jump")["setting"] == &"bind_jump", "the action's own row is still the one row_for_action finds")
	var s := DotSettingsSchema.new()
	k.add_to_schema(s)
	_check(s.has(DotMenuBindings.WHEEL_JUMP_UP_SETTING) and s.has(DotMenuBindings.WHEEL_JUMP_DOWN_SETTING),
		"each extra key is a setting of its own")
	var st := _manager(s)
	k.apply_all(st)
	_check(_on_action(&"dot_fps_jump", "Space") and _on_action(&"dot_fps_jump", "Wheel up") and _on_action(&"dot_fps_jump", "Wheel down"),
		"Space and both wheel directions are all on jump at once")
	_check(_wheel(MOUSE_BUTTON_WHEEL_UP).is_action_pressed(&"dot_fps_jump"), "a wheel tick is a press of jump")

	var _f := k.apply_setting(&"bind_jump", "J")
	_check(_on_action(&"dot_fps_jump", "J") and not _on_action(&"dot_fps_jump", "Space") and _on_action(&"dot_fps_jump", "Wheel up"),
		"re-applying Jump's own key replaces only that key and keeps the wheel")
	var _back := k.apply_setting(&"bind_jump", "Space")

	var up := k.row_for_setting(DotMenuBindings.WHEEL_JUMP_UP_SETTING)
	var res := k.rebind(up, "F", st)
	_check(res.ok and st.get_string(DotMenuBindings.WHEEL_JUMP_UP_SETTING) == "F" and st.get_string(&"bind_flashlight") == "Wheel up",
		"rebinding the wheel's jump onto a taken key swaps (%s)" % (str(res.value) if res.ok else res.error.message))
	_check(_on_action(&"dot_fps_jump", "F") and not _on_action(&"dot_fps_jump", "Wheel up") and _on_action(&"dot_fps_jump", "Space")
		and _on_action(&"test_flashlight", "Wheel up") and not _on_action(&"test_flashlight", "F"),
		"and both halves land on the InputMap, Space untouched")

	var down := k.row_for_setting(DotMenuBindings.WHEEL_JUMP_DOWN_SETTING)
	var cleared := k.rebind(down, DotMenuBindings.NONE, st)
	_check(cleared.ok and k.stored(down, st) == DotMenuBindings.NONE and not _on_action(&"dot_fps_jump", "Wheel down")
		and DotMenuBindings.shown(down) == "—", "an extra key can be set to nothing")
	_check(not k.rebind(k.row_for_action(&"dot_fps_forward"), DotMenuBindings.NONE, st).ok
		and st.get_string(&"bind_forward") == "W", "an action's own row cannot")
	var steal := k.rebind(down, "W", st)
	_check(not steal.ok and steal.error.code == DotError.CODE_CONFLICT and st.get_string(&"bind_forward") == "W",
		"a key on nothing is not swapped onto Forward, which would leave Forward on nothing")
	var _r := k.rebind(down, "Wheel down", st)
	_check(_on_action(&"dot_fps_jump", "Wheel down") and DotMenuBindings.shown(down) == "Wheel down", "and set back")

	k.reset_all(st)
	_check(st.get_string(DotMenuBindings.WHEEL_JUMP_UP_SETTING) == "Wheel up" and _on_action(&"dot_fps_jump", "Wheel up")
		and st.get_string(&"bind_flashlight") == "F", "a reset puts the wheel back on jump")
	st.queue_free()

	# A document where the player had put the wheel on something before the wheel jumped.
	var k2 := _keys().add_wheel_jump()
	var s2 := DotSettingsSchema.new()
	k2.add_to_schema(s2)
	var m := _old_document_manager(s2, {"bind_flashlight": "Wheel up"})
	k2.apply_all(m)
	_check(m.get_string(&"bind_flashlight") == "Wheel up" and _on_action(&"test_flashlight", "Wheel up"),
		"a key the player put on the wheel is kept when the wheel jump arrives")
	_check(k2.stored(k2.row_for_setting(DotMenuBindings.WHEEL_JUMP_UP_SETTING), m) == DotMenuBindings.NONE
		and not _on_action(&"dot_fps_jump", "Wheel up") and _on_action(&"dot_fps_jump", "Wheel down"),
		"and that direction's jump goes to nothing, the other still jumps")
	m.queue_free()

	# A game with weapons: the wheel goes through them, and does not jump.
	var w := _keys().add_wheel_jump().add_wheel_weapons()
	_check(w.row_for_setting(DotMenuBindings.WHEEL_JUMP_UP_SETTING).is_empty() and w.row_for_setting(DotMenuBindings.WHEEL_JUMP_DOWN_SETTING).is_empty(),
		"add_wheel_weapons takes the wheel's jump rows off")
	var s3 := DotSettingsSchema.new()
	w.add_to_schema(s3)
	var m3 := _manager(s3)
	w.apply_all(m3)
	_check(w.key_for(DotMenuBindings.WEAPON_PREVIOUS_ACTION) == "Wheel up" and w.key_for(DotMenuBindings.WEAPON_NEXT_ACTION) == "Wheel down",
		"previous weapon on wheel up, next on wheel down")
	_check(not _on_action(&"dot_fps_jump", "Wheel up") and not _on_action(&"dot_fps_jump", "Wheel down") and _on_action(&"dot_fps_jump", "Space"),
		"and jump is on Space alone")
	_check(_wheel(MOUSE_BUTTON_WHEEL_DOWN).is_action_pressed(DotMenuBindings.WEAPON_NEXT_ACTION)
		and not _wheel(MOUSE_BUTTON_WHEEL_DOWN).is_action_pressed(&"dot_fps_jump"), "a wheel tick is a weapon change, not a jump")
	var own := _keys().add_wheel_weapons(&"test_prev", &"test_next")
	_check(own.row_for_action(&"test_prev")["default"] == "Wheel up" and own.row_for_action(&"test_next")["setting"] == DotMenuBindings.WEAPON_NEXT_SETTING,
		"a game's own actions, stored as the stock settings")
	m3.queue_free()

	# The Controls page: Delete clears an extra key's button, and only an extra key's.
	var b := DotMenuKeyButton.new()
	b.clearable = true
	var got: Array = []
	b.captured.connect(func(t: String) -> void: got.append(t))
	add_child(b)
	b.listen()
	b._opened_on_frame = -1
	var del := InputEventKey.new()
	del.physical_keycode = KEY_DELETE
	del.pressed = true
	b._input(del)
	_check(got == [DotMenuBindings.NONE] and b.prompt.contains("Del"), "Delete on an extra key's button sets it to nothing")
	b.queue_free()

	for a in [DotMenuBindings.WEAPON_PREVIOUS_ACTION, DotMenuBindings.WEAPON_NEXT_ACTION]:
		if InputMap.has_action(a):
			InputMap.erase_action(a)
