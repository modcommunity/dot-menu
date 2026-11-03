extends RefCounted

const Selftest := preload("res://examples/menu_selftest.gd")

## The Tab scoreboard, run from menu_selftest.

## Anything shaped like dot-server's DotClientLink, for the board's feed.
class FakeLink extends RefCounted:
	signal scoreboard_received(snapshot: Dictionary)
	var asked: Array = []
	var scoreboard: Dictionary = {}

	func want_scoreboard(open: bool) -> bool:
		asked.append(open)
		return true

static func run(host: Selftest) -> void:
	host._section("The scoreboard: held, themed, and the game's to change")

	host._check(DotMenuScoreboard.duration(245) == "4:05" and DotMenuScoreboard.duration(3729) == "1:02:09"
		and DotMenuScoreboard.duration(-1) == "-", "time connected reads as a clock")

	var menu := host._menu()
	menu.bindings.add(&"test_scores", &"bind_scores", "Scoreboard", "Tab", "Interface")
	menu.bindings.add_to_schema(menu.settings.schema)
	menu.bindings.apply_all(menu.settings)
	menu.scoreboard_action = &"test_scores"
	var board := menu.scoreboard
	var link := FakeLink.new()
	board.feed_from(link)

	await _held(host, menu, board, link)
	await _custom(host, board, link)
	await _hidden(host, menu, board)
	await _choices(host, menu, board)
	_persisted(host, board)

	var _e := menu.handle_event(host._key(KEY_ESCAPE))
	host._check(menu.is_open() and not board.is_open(), "Escape while it is held opens the menu instead")
	var _c := menu.handle_event(host._key(KEY_ESCAPE))

	var _t := menu.cycle_theme()
	host._check(board.kit == menu.kit, "and a theme change reaches it")
	host._free_menu(menu)
	await host.get_tree().process_frame


static func _held(host: Selftest, menu: DotMenu, board: DotMenuScoreboard, link: FakeLink) -> void:
	var tab := host._key(KEY_TAB)
	host._check(menu.handle_event(tab) and board.is_open(), "Tab held shows it")
	host._check(not menu.any_open(), "and it is not an overlay: the player keeps moving and the pointer stays")
	host._check(link.asked == [true], "the server is told to start sending")
	link.scoreboard_received.emit(host._snapshot())
	await host.get_tree().process_frame

	var texts := host._texts(board)
	host._check(texts.has("Test Server") and texts.any(func(t: String) -> bool: return t.contains("dm_yard") and t.contains("Time left 4:12")),
		"the server's name, its map and the round's own facts")
	host._check(texts.has("4 / 16 players"), "and how full it is")
	host._check(board.find_child("Team_1", true, false) != null and board.find_child("Team_2", true, false) != null,
		"a block per team")
	var red := board.find_child("Team_1", true, false)
	var red_names: Array = host._texts(red).filter(func(t: String) -> bool: return t == "ada" or t == "bea")
	host._check(red_names == ["bea", "ada"], "each ordered by score, best first")
	host._check(texts.has("1:02:09") and texts.has("4:05") and texts.has("-"), "time connected and an unknown ping")
	var spect := board.find_child("Spectators", true, false) as Label
	host._check(spect != null and spect.text.contains("dot"), "a player on no team is listed as spectating")
	var you_label: Label = null
	for l in board.find_children("*", "Label", true, false):
		if (l as Label).text == "cy":
			you_label = l
	host._check(you_label != null and you_label.get_theme_color(&"font_color") == menu.kit.palette.accent, "this player is picked out")
	host._check(board.ping_colour(30) == menu.kit.palette.hud_ahead and board.ping_colour(250) == menu.kit.palette.danger,
		"ping is coloured by how bad it is")

	var released := InputEventKey.new()
	released.physical_keycode = KEY_TAB
	released.keycode = KEY_TAB
	released.pressed = false
	host._check(menu.handle_event(released) and not board.is_open(), "letting go of Tab hides it")
	host._check(link.asked == [true, false], "and stops the server sending")


static func _custom(host: Selftest, board: DotMenuScoreboard, link: FakeLink) -> void:
	board.add_column({"key": &"kills", "title": "K", "kind": DotMenuScoreboard.KIND_NUMBER}, &"score")
	board.add_column({"key": &"rank", "title": "Rank", "kind": DotMenuScoreboard.KIND_CUSTOM,
		"build": func(kit: DotMenuKit, row: Dictionary) -> Control: return kit.label("#%d" % int(row.get("rank", 0)))})
	board.decorate = func(row: Dictionary) -> void:
		row["kills"] = int(row.get("score", 0)) / 5
		row["rank"] = 9
	host._check(board.columns.map(func(c: Dictionary) -> StringName: return c["key"]) == [&"avatar", &"name", &"kills", &"score", &"seconds", &"ping", &"rank"],
		"a game adds its own columns where it wants them")
	board.open()
	await host.get_tree().process_frame
	var texts := host._texts(board)
	host._check(texts.has("#9") and texts.has("5"), "drawn from its own decoration and its own builder")
	board.close()
	board.prepare = func(snap: Dictionary) -> void:
		snap["teams"] = []
		snap["header"] = {"Course": "Ice Works"}
	board.open()
	await host.get_tree().process_frame
	texts = host._texts(board)
	host._check(board.find_child("Team_1", true, false) == null and texts.any(func(t: String) -> bool: return t.contains("Course Ice Works"))
		and (board.snapshot.get("teams", []) as Array).size() == 2,
		"the client can rewrite what is drawn without touching what the server sent")
	board.close()
	board.prepare = Callable()

	board.source = func() -> Dictionary:
		return {"players": [{"id": "me", "name": "Solo", "score": 3, "seconds": 30, "ping": -1}], "you": "me"}
	board.build_row = func(kit: DotMenuKit, row: Dictionary, _cols: Array) -> Control:
		return kit.label("ROW %s" % row["name"])
	board.open()
	await host.get_tree().process_frame
	texts = host._texts(board)
	host._check(texts.has("ROW Solo") and texts.has("Scoreboard"), "offline, the game's own snapshot and its own rows")
	link.scoreboard_received.emit(host._snapshot())
	host._check(board.rows().size() == 1, "and a source wins over the feed")


static func _hidden(host: Selftest, menu: DotMenu, board: DotMenuScoreboard) -> void:
	# --- Columns a player hides ---
	board.build_row = Callable()
	board.source = func() -> Dictionary:
		return {"players": [{"id": "me", "name": "Solo", "score": 3, "seconds": 30, "ping": 77, "kills": 9, "rank": 4}], "you": "me"}
	board.add_column({"key": &"best", "title": "Best", "kind": DotMenuScoreboard.KIND_NUMBER, "hidden": true}, &"ping")
	board.open()
	await host.get_tree().process_frame
	var texts := host._texts(board)
	host._check(not texts.has("Best") and texts.has("Ping") and texts.has("Score"), "a column the game starts hidden is not drawn")
	menu.open(&"general")
	await host.get_tree().process_frame
	host._check(host._row_control(menu, "scoreboard_col_ping") != null and host._row_control(menu, "scoreboard_col_best") != null
		and host._row_control(menu, "scoreboard_col_kills") != null,
		"Settings lists the live board's columns, the game's own included")
	host._check(host._row_control(menu, "scoreboard_col_name") == null and host._row_control(menu, "scoreboard_col_avatar") == null,
		"but neither the required name nor an untitled column")
	var titles := menu.screen.find_children("*", "Label", true, false).map(func(l: Label) -> String: return l.text)
	host._check(titles.has("Ping") and titles.has("Time") and titles.has("Best"), "by the titles the board draws")
	menu.close()
	# Opening the menu puts a held board away; hold it again.
	board.open()


static func _choices(host: Selftest, menu: DotMenu, board: DotMenuScoreboard) -> void:
	var ping_off := menu.settings.set_value(DotMenuScoreboard.SETTING, "ping,seconds")
	await host.get_tree().process_frame
	var texts := host._texts(board)
	host._check(ping_off.ok and not texts.has("Ping") and not texts.has("77") and not texts.has("Time") and not texts.has("0:30"),
		"a setting change redraws the open board: titles and rows lose the column")
	host._check(texts.has("Score") and texts.has("Player") and texts.has("3") and texts.has("Solo") and texts.has("K"),
		"and the rest still lays out")
	host._check(board.visible_columns().size() == board.columns.size() - 3, "visible_columns is the subset (ping, seconds, best)")

	var _nm := menu.settings.set_value(DotMenuScoreboard.SETTING, "name,score")
	await host.get_tree().process_frame
	texts = host._texts(board)
	host._check(texts.has("Player") and texts.has("Solo") and not texts.has("Score"), "the name column cannot be hidden")
	var _all := menu.settings.set_value(DotMenuScoreboard.SETTING, "avatar,name,score,seconds,ping,kills,rank,nonsense")
	await host.get_tree().process_frame
	host._check(board.visible_columns().size() == 1 and host._texts(board).has("Solo"), "any subset draws, an unknown key is ignored")

	var _show := menu.settings.set_value(DotMenuScoreboard.SETTING, "+best")
	await host.get_tree().process_frame
	texts = host._texts(board)
	host._check(texts.has("Best") and texts.has("Ping"), "the player's choice overrides the game's default-hidden")
	var _toggle := menu.settings.set_value(DotMenuScoreboard.SETTING, "")
	menu.scoreboard_column_rows()[0].setter.call(false)
	host._check(DotMenuScoreboard.parse_choices(menu.settings.get_string(DotMenuScoreboard.SETTING, "")).size() == 1,
		"a Settings switch writes the setting")


static func _persisted(host: Selftest, board: DotMenuScoreboard) -> void:
	var req := DotMenuScoreboard.column_required({"key": &"score", "required": true})
	host._check(req and DotMenuScoreboard.column_required({"key": &"name"}) and not DotMenuScoreboard.column_required({"key": &"name", "required": false}),
		"required defaults on for the name column only")
	var rt := DotMenuScoreboard.parse_choices(DotMenuScoreboard.format_choices({&"ping": true, &"best": false}))
	host._check(rt == {&"ping": true, &"best": false}, "the stored text round-trips")

	# Persisted: a second manager over the same store sees the choice.
	var store := DotSettingsStoreMemory.new()
	var m1 := DotMenuStock.manager(host._schema(DotMenuStock.DEFAULT_GROUPS), "", &"menu_persist", &"", store)
	host.add_child(m1)
	var _s1 := m1.setup()
	var _w := m1.set_value(DotMenuScoreboard.SETTING, "ping,+best")
	var _f := m1.flush()
	var m2 := DotMenuStock.manager(host._schema(DotMenuStock.DEFAULT_GROUPS), "", &"menu_persist", &"", store)
	host.add_child(m2)
	var _s2 := m2.setup()
	host._check(m2.get_string(DotMenuScoreboard.SETTING, "") == "ping,+best", "the choice survives a restart")
	m1.queue_free()
	m2.queue_free()
	board.player_hidden = {}
	board.remove_column(&"best")
