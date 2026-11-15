extends "res://examples/menu_selftest_base.gd"

## The team menu and the workbench and avatar action keys, run from menu_selftest.


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
