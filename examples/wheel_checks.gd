extends RefCounted

const Selftest := preload("res://examples/menu_selftest.gd")

## Wheel bindings, run from menu_selftest.

static func run(host: Selftest) -> void:
	host._section("Extra keys and the wheel")

	# A game with nothing to switch: the wheel also jumps.
	var k := host._keys().add_wheel_jump()
	var labels: Array = []
	for row in k.rows_in("Movement"):
		labels.append(str(row["label"]))
	host._check(labels.slice(4, 7) == ["Jump", "Jump (wheel up)", "Jump (wheel down)"],
		"the wheel's jump rows are drawn right after Jump (%s)" % [labels])
	host._check(k.row_for_action(&"dot_fps_jump")["setting"] == &"bind_jump", "the action's own row is still the one row_for_action finds")
	var s := DotSettingsSchema.new()
	k.add_to_schema(s)
	host._check(s.has(DotMenuBindings.WHEEL_JUMP_UP_SETTING) and s.has(DotMenuBindings.WHEEL_JUMP_DOWN_SETTING),
		"each extra key is a setting of its own")
	var st := host._manager(s)
	k.apply_all(st)
	host._check(host._on_action(&"dot_fps_jump", "Space") and host._on_action(&"dot_fps_jump", "Wheel up") and host._on_action(&"dot_fps_jump", "Wheel down"),
		"Space and both wheel directions are all on jump at once")
	host._check(host._wheel(MOUSE_BUTTON_WHEEL_UP).is_action_pressed(&"dot_fps_jump"), "a wheel tick is a press of jump")

	_rebinding(host, k, st)
	_old_document(host)
	_weapons(host)
	_delete_key(host)


static func _rebinding(host: Selftest, k: DotMenuBindings, st: DotSettingsManager) -> void:
	var _f := k.apply_setting(&"bind_jump", "J")
	host._check(host._on_action(&"dot_fps_jump", "J") and not host._on_action(&"dot_fps_jump", "Space") and host._on_action(&"dot_fps_jump", "Wheel up"),
		"re-applying Jump's own key replaces only that key and keeps the wheel")
	var _back := k.apply_setting(&"bind_jump", "Space")

	var up := k.row_for_setting(DotMenuBindings.WHEEL_JUMP_UP_SETTING)
	var res := k.rebind(up, "F", st)
	host._check(res.ok and st.get_string(DotMenuBindings.WHEEL_JUMP_UP_SETTING) == "F" and st.get_string(&"bind_flashlight") == "Wheel up",
		"rebinding the wheel's jump onto a taken key swaps (%s)" % (str(res.value) if res.ok else res.error.message))
	host._check(host._on_action(&"dot_fps_jump", "F") and not host._on_action(&"dot_fps_jump", "Wheel up") and host._on_action(&"dot_fps_jump", "Space")
		and host._on_action(&"test_flashlight", "Wheel up") and not host._on_action(&"test_flashlight", "F"),
		"and both halves land on the InputMap, Space untouched")

	var down := k.row_for_setting(DotMenuBindings.WHEEL_JUMP_DOWN_SETTING)
	var cleared := k.rebind(down, DotMenuBindings.NONE, st)
	host._check(cleared.ok and k.stored(down, st) == DotMenuBindings.NONE and not host._on_action(&"dot_fps_jump", "Wheel down")
		and DotMenuBindings.shown(down) == "—", "an extra key can be set to nothing")
	host._check(not k.rebind(k.row_for_action(&"dot_fps_forward"), DotMenuBindings.NONE, st).ok
		and st.get_string(&"bind_forward") == "W", "an action's own row cannot")
	var steal := k.rebind(down, "W", st)
	host._check(not steal.ok and steal.error.code == DotError.CODE_CONFLICT and st.get_string(&"bind_forward") == "W",
		"a key on nothing is not swapped onto Forward, which would leave Forward on nothing")
	var _r := k.rebind(down, "Wheel down", st)
	host._check(host._on_action(&"dot_fps_jump", "Wheel down") and DotMenuBindings.shown(down) == "Wheel down", "and set back")

	k.reset_all(st)
	host._check(st.get_string(DotMenuBindings.WHEEL_JUMP_UP_SETTING) == "Wheel up" and host._on_action(&"dot_fps_jump", "Wheel up")
		and st.get_string(&"bind_flashlight") == "F", "a reset puts the wheel back on jump")
	st.queue_free()


static func _old_document(host: Selftest) -> void:
	# A document where the player had put the wheel on something before the wheel jumped.
	var k2 := host._keys().add_wheel_jump()
	var s2 := DotSettingsSchema.new()
	k2.add_to_schema(s2)
	var m := host._old_document_manager(s2, {"bind_flashlight": "Wheel up"})
	k2.apply_all(m)
	host._check(m.get_string(&"bind_flashlight") == "Wheel up" and host._on_action(&"test_flashlight", "Wheel up"),
		"a key the player put on the wheel is kept when the wheel jump arrives")
	host._check(k2.stored(k2.row_for_setting(DotMenuBindings.WHEEL_JUMP_UP_SETTING), m) == DotMenuBindings.NONE
		and not host._on_action(&"dot_fps_jump", "Wheel up") and host._on_action(&"dot_fps_jump", "Wheel down"),
		"and that direction's jump goes to nothing, the other still jumps")
	m.queue_free()


static func _weapons(host: Selftest) -> void:
	# A game with weapons: the wheel goes through them, and does not jump.
	var w := host._keys().add_wheel_jump().add_wheel_weapons()
	host._check(w.row_for_setting(DotMenuBindings.WHEEL_JUMP_UP_SETTING).is_empty() and w.row_for_setting(DotMenuBindings.WHEEL_JUMP_DOWN_SETTING).is_empty(),
		"add_wheel_weapons takes the wheel's jump rows off")
	var s3 := DotSettingsSchema.new()
	w.add_to_schema(s3)
	var m3 := host._manager(s3)
	w.apply_all(m3)
	host._check(w.key_for(DotMenuBindings.WEAPON_PREVIOUS_ACTION) == "Wheel up" and w.key_for(DotMenuBindings.WEAPON_NEXT_ACTION) == "Wheel down",
		"previous weapon on wheel up, next on wheel down")
	host._check(not host._on_action(&"dot_fps_jump", "Wheel up") and not host._on_action(&"dot_fps_jump", "Wheel down") and host._on_action(&"dot_fps_jump", "Space"),
		"and jump is on Space alone")
	host._check(host._wheel(MOUSE_BUTTON_WHEEL_DOWN).is_action_pressed(DotMenuBindings.WEAPON_NEXT_ACTION)
		and not host._wheel(MOUSE_BUTTON_WHEEL_DOWN).is_action_pressed(&"dot_fps_jump"), "a wheel tick is a weapon change, not a jump")
	var own := host._keys().add_wheel_weapons(&"test_prev", &"test_next")
	host._check(own.row_for_action(&"test_prev")["default"] == "Wheel up" and own.row_for_action(&"test_next")["setting"] == DotMenuBindings.WEAPON_NEXT_SETTING,
		"a game's own actions, stored as the stock settings")
	m3.queue_free()


static func _delete_key(host: Selftest) -> void:
	# The Controls page: Delete clears an extra key's button, and only an extra key's.
	var b := DotMenuKeyButton.new()
	b.clearable = true
	var got: Array = []
	b.captured.connect(func(t: String) -> void: got.append(t))
	host.add_child(b)
	b.listen()
	b._opened_on_frame = -1
	var del := InputEventKey.new()
	del.physical_keycode = KEY_DELETE
	del.pressed = true
	b._input(del)
	host._check(got == [DotMenuBindings.NONE] and b.prompt.contains("Del"), "Delete on an extra key's button sets it to nothing")
	b.queue_free()

	for a in [DotMenuBindings.WEAPON_PREVIOUS_ACTION, DotMenuBindings.WEAPON_NEXT_ACTION]:
		if InputMap.has_action(a):
			InputMap.erase_action(a)
