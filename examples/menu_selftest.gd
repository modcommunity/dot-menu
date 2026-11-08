extends "res://examples/menu_selftest_base.gd"

## Exercises dot-menu with no game: the data model, stock settings and what applies them, the bindings table, the screens, the facade's keys, and what a server may do.
## CHECKS is the guard the section counter cannot be: a script error aborts that test, not the run, and only the total notices checks that never ran.
const SECTIONS := 34
const CHECKS := 524


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
	await load("res://examples/scoreboard_checks.gd").run(self)
	await load("res://examples/net_stat_checks.gd").run(self)
	await load("res://examples/touch_checks.gd").run(self)
	await _test_voice()
	await load("res://examples/help_leave_checks.gd").run(self)
	await load("res://examples/game_settings_checks.gd").run(self)
	await load("res://examples/exit_tree_checks.gd").run(self)
	await load("res://examples/map_menu_checks.gd").run(self)
	await _test_map_modes()
	await load("res://examples/loadout_menu_checks.gd").run(self)
	_test_avatar_action_keys()
	_test_workbench_key()
	_test_team_menu()
	_test_team_menu_unwired()
	await _test_hud_follows()
	_test_moved_defaults()
	await load("res://examples/wheel_checks.gd").run(self)
	await load("res://examples/scoreboard_scroll_checks.gd").run(self)
	await load("res://examples/team_screen_scroll_checks.gd").run(self)
	await load("res://examples/stats_checks.gd").run(self)
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
	_check(DotMenuStock.declare(DotSettingsSchema.new()).has(&"reduce_motion") and not fx.reduce_motion and not fx.reduced_motion,
		"reduce_motion is a stock Comfort key, off by default")
	var _rm := st.set_value(&"reduce_motion", true)
	_check(fx.reduce_motion and fx.reduced_motion, "turning reduce_motion on reaches both spellings of the effects' flag")
	_check(cam.fov == 90.0, "and the field of view the camera")
	_check(heard.size() == 1 and heard[0][1] == &"applied", "a game's handler hears the boot value once")

	var hands := FakeHands.new()
	add_child(hands)
	_check(DotMenuStock.VIEWMODEL_FOV == 54, "the view model default is 54, the value that read closest to a first-person shooter's in the Arena render")
	_check(hands.horizontal == float(DotMenuStock.VIEWMODEL_FOV), "a view model added after boot gets the viewmodel_fov default")
	var on_screen := func(cam: float) -> float: return DotViewLens.lens_scale(cam, DotViewLens.vertical_from_horizontal_4_3(54.0)) / tan(deg_to_rad(cam) * 0.5)
	_check(is_equal_approx(on_screen.call(73.7), on_screen.call(83.6)) and is_equal_approx(on_screen.call(60.0), on_screen.call(100.0)), "the hands' size on screen does not depend on the world field of view")
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
	menu.remove_child(menu.help)
	menu.help._window.custom_minimum_size = Vector2(7, 7)
	menu.help._fit()
	_check(menu.help._window.custom_minimum_size == Vector2(7, 7), "a pending fit on a detached help does nothing instead of erroring")
	menu.add_child(menu.help)

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








func _test_net_stat_own() -> void:
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














func _test_map_modes() -> void:
	_section("- switches the map menu between Maps and Game modes")
	for a in [DotMenuBindings.MAPS_ACTION, DotMenuBindings.HELP_ACTION, DotMenuBindings.MODES_ACTION]:
		if InputMap.has_action(a):
			InputMap.erase_action(a)
	var node := DotMenuSettings.new()
	node.app_namespace = &"menu_modes_test"
	node.config = DotMenuConfig.new()
	node.config.escape_grace_ms = 0
	node.map_modes = true
	add_child(node)
	var _s := node.setup(DotSettingsStoreMemory.new())
	var mrow := node.bindings.row_for_action(DotMenuBindings.MODES_ACTION)
	_check(not mrow.is_empty() and str(mrow["default"]) == "Minus", "the tab key is in the table, on - by default")

	var chosen: Array = []
	var maps_only: Array = [{"id": "map:a", "name": "A"}, {"id": "map:b", "name": "B", "current": true}]
	var both: Array = maps_only + [{"id": "mode:ffa", "name": "Free for all", "kind": "mode"}, {"id": "mode:tdm", "name": "Team", "kind": "mode"}]
	var rows: Array = maps_only.duplicate()
	var maps := node.use_maps(func() -> Array: return rows, func(id: StringName, mode: StringName) -> DotResult:
		chosen.append([id, mode])
		return DotResult.success(id))
	maps.open()
	await get_tree().process_frame
	_check(not maps.has_tabs() and node.menu.picker.tabs.is_empty(), "no modes provided: no tab")
	var _m1 := node.menu.handle_event(_key(KEY_MINUS))
	_check(node.menu.picker.items.size() == 2 and node.menu.picker.is_open(), "and - does nothing then")
	node.menu.picker.close()

	rows.assign(both)
	maps.open()
	await get_tree().process_frame
	_check(maps.has_tabs() and node.menu.picker.tabs.size() == 2 and node.menu.picker.items.size() == 2 and maps.tab == &"maps",
		"modes provided: the tabs show, Maps first, with the maps only")
	_check(node.menu.picker.find_child("Tab_modes", true, false) != null, "a button per tab")
	var _m2 := node.menu.handle_event(_key(KEY_MINUS))
	_check(maps.tab == &"modes" and str(node.menu.picker.items[0]["id"]) == "mode:ffa", "- shows the modes")
	var _m3 := node.menu.handle_event(_key(KEY_MINUS))
	_check(maps.tab == &"maps", "and again, the maps")

	var edit := LineEdit.new()
	add_child(edit)
	edit.grab_focus()
	var _m4 := node.menu.handle_event(_key(KEY_MINUS))
	_check(maps.tab == &"maps", "- is not the tab key while a text field has the keyboard")
	edit.queue_free()
	await get_tree().process_frame

	var _m5 := node.menu.handle_event(_key(KEY_MINUS))
	var _m6 := node.menu.handle_event(_key(KEY_2))
	_check(maps.tab == &"maps" and node.menu.picker.is_open() and maps.mode == &"mode:tdm", "a mode picked is kept and the list returns to Maps")
	var _m7 := node.menu.handle_event(_key(KEY_1))
	await get_tree().process_frame
	_check(chosen == [[&"map:a", &"mode:tdm"]], "the map picked carries the mode")

	maps.modes_tab = &"hide"
	maps.open()
	await get_tree().process_frame
	_check(not maps.has_tabs() and node.menu.picker.items.size() == 2, "the cvar hide removes the tab")
	node.menu.picker.close()
	maps.modes_tab = &"show"
	rows.assign(maps_only)
	maps.open()
	await get_tree().process_frame
	_check(maps.has_tabs(), "and show forces it")
	node.menu.picker.close()
	maps.modes_tab = &"auto"

	await _test_modes_rebind(node, rows, both)
	node.queue_free()
	await get_tree().process_frame


## The map key on a menu with no key table, and on a table that already has M.
func _test_modes_rebind(node: DotMenuSettings, rows: Array, both: Array) -> void:
	var maps := node.menu.maps
	var row := node.bindings.row_for_action(DotMenuBindings.MODES_ACTION)
	var res := node.bindings.rebind(row, "F6", node.settings)
	_check(res.ok and node.bindings.key_for(DotMenuBindings.MODES_ACTION) == "F6", "the key rebinds")
	rows.assign(both)
	maps.open()
	await get_tree().process_frame
	var _m8 := node.menu.handle_event(_key(KEY_MINUS))
	var still := maps.tab == &"maps"
	var _m9 := node.menu.handle_event(_key(KEY_F6))
	_check(still and maps.tab == &"modes", "and the old key stops, the new one switches")
	node.menu.picker.close()


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


func _test_team_menu() -> void:
	_section("the team menu lists what the server sent, spectate last")
	var two := {"teams": [{"id": 1, "name": "Red", "colour": "e04040", "count": 2, "max": 0, "closed": "", "current": true},
		{"id": 2, "name": "Blue", "colour": "4060e0", "count": 1, "max": 0, "closed": "", "current": false}],
		"ffa": false, "spectating": false, "spectate_ok": true}
	var entries := DotMenuTeamScreen.entries_for(two)
	_check(entries.size() == 3 and entries[2]["id"] == "spectate", "two teams make two cards and a Spectate card at the end")
	_check(entries[0]["name"] == "Red" and entries[0]["current"] and entries[1]["count"] == 1, "names, current and live counts come from the data")
	var four: Dictionary = two.duplicate(true)
	for i in range(3, 5):
		four["teams"].append({"id": i, "name": "Team %d" % i, "colour": "", "count": 0, "max": 0, "closed": "", "current": false})
	four["teams"][0]["name"] = "Alpha"
	entries = DotMenuTeamScreen.entries_for(four)
	_check(entries.size() == 5 and entries[0]["name"] == "Alpha", "four teams make four cards, renamed through the data")
	var ffa := {"teams": [], "ffa": true, "spectating": false, "spectate_ok": true}
	entries = DotMenuTeamScreen.entries_for(ffa)
	_check(entries.size() == 2 and entries[0]["kind"] == "play" and entries[1]["kind"] == "spectate", "a free-for-all lists Play and Spectate only")
	ffa["spectating"] = true
	entries = DotMenuTeamScreen.entries_for(ffa)
	_check(entries[0]["closed"] == "" and entries[1]["current"], "while spectating, Play is open and Spectate is the current card")
	ffa["spectate_ok"] = false
	_check(DotMenuTeamScreen.entries_for(ffa).size() == 1, "a server that turns spectate off drops that card")
	var screen := DotMenuTeamScreen.new()
	_check(screen.columns_for(2) == 2 and screen.columns_for(4) == 4 and screen.columns_for(8) <= 4, "the grid has a column per card up to a limit, then wraps")
	screen.free()
	var keys := DotMenuBindings.new().add_teams("Interface")
	var row := keys.row_for_action(DotMenuBindings.TEAMS_ACTION)
	var ev := DotInputBinding.from_text(str(row.get("default", ""))) as InputEventKey
	_check(ev != null and ev.physical_keycode == KEY_PERIOD, "the Choose team row defaults to the period key")
	_check(DotMenuBindings.new().add_avatar_actions().row_for_action(DotMenuBindings.AVATAR_POSE_ACTION).get("default", "") != row.get("default", "x"), "and no avatar action shares it")


func _test_team_menu_unwired() -> void:
	_section("the team key still opens a Play and Spectate menu when the game wired nothing")
	var menu := _menu()
	var teams := menu.use_teams()
	teams.open()
	_check(menu.team_screen.is_open() and bool(menu.team_screen.last_data.get("ffa", false)), "no link and no offer: the menu opens as a free-for-all")
	_check(teams.last_said == "" and DotMenuTeamScreen.entries_for(menu.team_screen.last_data).size() == 2, "no toast, and the cards are Play and Spectate")
	menu.team_screen.close()
	teams.default_when_unwired = false
	teams.open()
	_check(not menu.team_screen.is_open() and teams.last_said != "", "the switch off keeps the toast")
	teams.default_when_unwired = true
	teams.open()
	teams.choose("spectate")
	_check(teams.last_said == "This game cannot change teams.", "a choice nothing is wired to answer says so")
	_free_menu(menu)


func _test_workbench_key() -> void:
	_section("the workbench toggle is the semicolon, a rebindable row, and a rebind survives a restart")
	var table := DotMenuBindings.new().add_workbench("General")
	var row := table.row_for_action(DotMenuBindings.WORKBENCH_ACTION)
	var def := DotInputBinding.from_text(str(row.get("default", ""))) as InputEventKey
	_check(def != null and def.physical_keycode == KEY_SEMICOLON, "the default binding is the semicolon")
	_check(table.defaults_on("Semicolon").size() == 1, "and no other row shares it")
	_check(DotMenuBindings.new().add_avatar_actions().defaults_on("Semicolon").is_empty(), "the avatar pose no longer does")
	var store := DotSettingsStoreMemory.new()
	var a := DotMenuSettings.new()
	a.app_namespace = &"menu_wb_key"
	a.config = DotMenuConfig.new()
	a.bindings = DotMenuBindings.new().add_workbench("General")
	add_child(a)
	var _sa := a.setup(store, false)
	var ev := InputMap.action_get_events(DotMenuBindings.WORKBENCH_ACTION)
	_check(ev.size() == 1 and (ev[0] as InputEventKey).physical_keycode == KEY_SEMICOLON, "the action is in the InputMap on the semicolon")
	var done := a.bindings.rebind(a.bindings.row_for_action(DotMenuBindings.WORKBENCH_ACTION), "Backslash", a.settings)
	_check(done.ok, "it rebinds")
	var _f := a.settings.flush()
	a.queue_free()
	InputMap.erase_action(DotMenuBindings.WORKBENCH_ACTION)
	var b := DotMenuSettings.new()
	b.app_namespace = &"menu_wb_key"
	b.config = DotMenuConfig.new()
	b.bindings = DotMenuBindings.new().add_workbench("General")
	add_child(b)
	var _sb := b.setup(store, false)
	ev = InputMap.action_get_events(DotMenuBindings.WORKBENCH_ACTION)
	_check(ev.size() == 1 and (ev[0] as InputEventKey).physical_keycode == KEY_BACKSLASH, "a restart over the same store has it on the new key")
	b.queue_free()
	InputMap.erase_action(DotMenuBindings.WORKBENCH_ACTION)


func _test_avatar_action_keys() -> void:
	_section("comma, apostrophe and slash are the emote, pose and gesture rows")
	var node := DotMenuSettings.new()
	node.app_namespace = &"menu_avatar_test"
	node.avatar_actions = true
	node.config = DotMenuConfig.new()
	add_child(node)
	var _s := node.setup(DotSettingsStoreMemory.new(), false)
	var want := {DotMenuBindings.AVATAR_EMOTE_ACTION: KEY_COMMA, DotMenuBindings.AVATAR_POSE_ACTION: KEY_APOSTROPHE,
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






func _test_loadout_bare(node: DotMenuSettings) -> void:
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
	bare.queue_free()


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


