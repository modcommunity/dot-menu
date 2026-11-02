extends RefCounted

const Selftest := preload("res://examples/menu_selftest.gd")

## The map menu, run from menu_selftest.

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

static func run(host: Selftest) -> void:
	host._section("M is the map menu: solo changes, a server decides")

	# Every DotMenuSettings game gets the key, on M.
	for a in [DotMenuBindings.MAPS_ACTION, DotMenuBindings.HELP_ACTION]:
		if InputMap.has_action(a):
			InputMap.erase_action(a)
	var node := DotMenuSettings.new()
	node.app_namespace = &"menu_maps_test"
	node.config = DotMenuConfig.new()
	node.config.escape_grace_ms = 0
	host.add_child(node)
	var _s := node.setup(DotSettingsStoreMemory.new())
	var row := node.bindings.row_for_action(DotMenuBindings.MAPS_ACTION)
	host._check(not row.is_empty() and str(row["default"]) == "M" and node.settings.schema.has(DotMenuBindings.MAPS_SETTING),
		"every game's table has the map key, on M, stored as bind_maps")
	host._check(not node.menu.handle_event(host._key(KEY_M)) and not node.menu.any_open(), "and M does nothing until the game hands it a list")

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
	host._check(maps != null and node.menu.handle_event(host._key(KEY_M)) and node.menu.picker.is_open(), "solo, M opens the picker")
	await host.get_tree().process_frame
	var texts := host._texts(node.menu.picker)
	host._check(texts.has("Change map — solo") and texts.has("Race") and texts.has("Relay"), "headed solo, each row with its mode")
	host._check(node.menu.picker.find_children("*", "TextureRect", true, false).size() == 1
		and node.menu.picker.find_children("Thumb", "PanelContainer", true, false).size() == 7,
		"a picture where a map has one, and an empty frame of the same size where it does not")
	node.menu.picker.open([{"id": "a", "name": "A", "detail": "blurb"}, {"id": "b", "name": "B"}], "x")
	await host.get_tree().process_frame
	host._check(node.menu.picker.find_children("Thumb", "PanelContainer", true, false).is_empty(),
		"and a page where no map has a picture draws no empty frames")
	node.menu.picker.visible = false
	maps.open()
	var _k := node.menu.handle_event(host._key(KEY_3))
	await host.get_tree().process_frame
	host._check(changed == [&"course_2"] and not node.menu.picker.is_open(), "a number changes to that map, directly")
	host._check(game_picks.is_empty(), "and the choice never reaches the game's own picker handler")
	var _k2 := node.menu.handle_event(host._key(KEY_M))
	var _k3 := node.menu.handle_event(host._key(KEY_M))
	host._check(not node.menu.picker.is_open() and changed.size() == 1, "M again closes it, changing nothing")

	var refuse := node.use_maps(func() -> Array: return rows, func(_id: StringName) -> DotResult:
		return DotResult.fail(DotError.CODE_STATE, "A round is being decided."))
	refuse.open()
	var _k4 := node.menu.handle_event(host._key(KEY_1))
	await host.get_tree().process_frame
	host._check(node.menu.toast_text() == "A round is being decided.", "a change the game refuses is said on screen")

	node.menu.toast("short", 0.05)
	host._check(node.menu.toast_text() == "short", "a toast with a lifetime shows")
	await host.get_tree().create_timer(0.3).timeout
	host._check(node.menu.toast_text() == "", "and expires when its time is up")
	node.menu.toast("first", 0.1)
	node.menu.toast("second", 5.0)
	await host.get_tree().create_timer(0.3).timeout
	host._check(node.menu.toast_text() == "second", "an older toast's timer does not hide a newer one")

	# Connected: the server is asked, and its answer decides.
	var link := FakeMapLink.new()
	host.add_child(link)
	maps.link = link
	maps.change_fn = func(id: StringName) -> DotResult:
		changed.append(id)
		return DotResult.success(id)
	var _k5 := node.menu.handle_event(host._key(KEY_M))
	host._check(link.sent == ["/mapmenu"] and not node.menu.picker.is_open(), "online, M asks the server rather than opening a list of its own")
	link.answer({"maps": [{"id": "dm_atrium", "name": "Atrium", "current": true}, {"id": "dm_yard", "name": "Yard"}],
		"allowed": true, "flag": "generic", "vote": true, "where": "this server"})
	await host.get_tree().process_frame
	host._check(node.menu.picker.is_open() and host._texts(node.menu.picker).has("Change map — this server"), "allowed, the server's list opens to change")
	var _k6 := node.menu.handle_event(host._key(KEY_2))
	host._check(link.sent.back() == "/mapmenu dm_yard" and changed.size() == 1, "and a choice is the server's to make, not this client's")
	# A long list comes in parts and opens once, whole.
	link.answer({"maps": [{"id": "a1", "name": "A1"}], "allowed": true, "flag": "generic", "vote": true, "part": 1, "parts": 2})
	var half_open := node.menu.picker.is_open()
	link.answer({"maps": [{"id": "a2", "name": "A2"}, {"id": "a3", "name": "A3"}], "allowed": true, "flag": "generic", "vote": true, "part": 2, "parts": 2})
	host._check(not half_open and node.menu.picker.is_open() and node.menu.picker.items.size() == 3,
		"a list sent in parts opens once, with every part")
	node.menu.picker.close()
	link.answer({"result": {"ok": true, "text": "Changing to Yard."}})
	host._check(node.menu.toast_text() == "Changing to Yard.", "what the server did is said on screen")

	link.answer({"maps": [{"id": "dm_atrium", "name": "Atrium"}, {"id": "dm_yard", "name": "Yard"}],
		"allowed": false, "flag": "generic", "vote": true, "where": "this server"})
	await host.get_tree().process_frame
	texts = host._texts(node.menu.picker)
	host._check(node.menu.picker.is_open() and texts.has("Vote for a map — this server")
		and texts.any(func(t: String) -> bool: return t.contains("'generic'") and t.contains("rocks the vote")),
		"without the owner's flag it is a vote, and it says which flag")
	node.menu.picker.close()
	link.answer({"maps": [{"id": "dm_yard", "name": "Yard"}], "allowed": false, "flag": "changemap", "vote": false})
	host._check(not node.menu.picker.is_open() and node.menu.toast_text().contains("'changemap'"),
		"with no flag and no vote, the refusal is shown and nothing opens")

	await host._test_map_menu_without_table(rows)
	link.queue_free()
	node.queue_free()
	await host.get_tree().process_frame
