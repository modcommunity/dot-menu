extends Node
## Helpers, fakes and the voice section of menu_selftest.gd, kept apart so the suite stays under the size budget.

var _passed := 0
var _failed := 0
var _section_count := 0


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


class FakeProfiler extends RefCounted:
	func make_menu_panel(_kit: Object) -> Control:
		var l := Label.new()
		l.name = "FakeProfilerPanel"
		l.text = "profiler panel"
		return l


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
