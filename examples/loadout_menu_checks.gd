extends RefCounted

const Selftest := preload("res://examples/menu_selftest.gd")

## The loadout menu, run from menu_selftest.

const MapChecks := preload("res://examples/map_menu_checks.gd")

class FakeLoadoutLink extends Node:
	signal notice_received(notice: Object)
	var sent: Array = []

	func is_connected_to_server() -> bool:
		return true

	func send_chat(text: String, _team_only: bool = false) -> void:
		sent.append(text)

	func answer(data: Dictionary) -> void:
		var n := MapChecks.FakeNotice.new()
		n.topic = &"loadout_menu"
		n.data = data
		notice_received.emit(n)

static func run(host: Selftest) -> void:
	host._section("B is the loadout menu: cards, the budget, a draft sent on close")

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
	host.add_child(node)
	var _s := node.setup(DotSettingsStoreMemory.new())
	var row := node.bindings.row_for_action(DotMenuBindings.LOADOUT_ACTION)
	host._check(not row.is_empty() and str(row["default"]) == "B" and node.settings.schema.has(DotMenuBindings.LOADOUT_SETTING),
		"a game that asks for it has the loadout key in its table, on B, stored as bind_loadout")
	host._check(not node.menu.handle_event(host._key(KEY_B)) and not node.menu.any_open(), "and B does nothing until the game hands it an offer")

	var saved: Array = []
	var icon := ImageTexture.create_from_image(Image.create(32, 16, false, Image.FORMAT_RGB8))
	var lo := node.use_loadout(
		func() -> Dictionary: return host._loadout_offer(),
		func(picks: Dictionary) -> Dictionary:
			saved.append(picks)
			return {"ok": true, "text": "Loadout equipped.", "now": true},
		func(_slot: String, choice: Dictionary) -> Dictionary:
			return {"icon": icon if choice["id"] == "rifle" else null,
				"stats": [{"label": "Damage", "value": 0.4 if choice["id"] == "rifle" else 0.9, "text": "x"}]})
	lo.remember_as("menu_test", "acct")
	var screen := node.menu.loadout_screen
	host._check(lo != null and node.menu.handle_event(host._key(KEY_B)) and screen.is_open() and node.menu.any_open(), "solo, B opens the loadout screen")
	await host.get_tree().process_frame
	var texts := host._texts(screen)
	host._check(texts.has("PRIMARY") and texts.has("SIDEARM") and texts.has("GRENADES  ·  SERVER"), "every slot is a tab, a fixed one marked as the server's")
	host._check(texts.has("EQUIPPED") and texts.has("6 pt") and texts.has("4 / 7 points"), "the cards say what is equipped, what each costs, and the budget")
	host._check(screen.find_children("*", "TextureRect", true, false).size() >= 2, "a card with art shows it (the card, the tab and the detail)")
	host._check(screen.find_children("Stats", "VBoxContainer", true, false).size() == 1, "and the highlighted card has its statistics drawn")

	await _draft(host, node, screen, lo, saved)
	await _restore_and_server_sets(host, screen, lo, saved)

	var link := FakeLoadoutLink.new()
	host.add_child(link)
	lo.link = link
	await _online(host, node, screen, lo, link, saved)

	await host._test_loadout_bare(node)

	if FileAccess.file_exists(DotMenuLoadout.REMEMBER_FILE):
		var _rm2 := DirAccess.remove_absolute(DotMenuLoadout.REMEMBER_FILE)
	link.queue_free()
	node.queue_free()
	await host.get_tree().process_frame


static func _draft(host: Selftest, node: DotMenuSettings, screen: DotMenuLoadoutScreen, lo: DotMenuLoadout, saved: Array) -> void:
	var _r := screen.handle_key(host._key(KEY_RIGHT))
	var _a := screen.handle_key(host._key(KEY_ENTER))
	await host.get_tree().process_frame
	host._check(screen.draft.get("primary") == "rifle" and str(screen.describe()["status"]).contains("over the budget"),
		"a card over the budget is refused, saying by how much")
	_r = screen.handle_key(host._key(KEY_RIGHT))
	_a = screen.handle_key(host._key(KEY_ENTER))
	host._check(screen.draft.get("primary") == "launcher" and screen.points_with() == 6, "a card within it goes in the draft")
	var _three := screen.handle_key(host._key(KEY_3))
	_a = screen.handle_key(host._key(KEY_ENTER))
	host._check(screen.current_slot()["id"] == "thrown" and str(screen.describe()["status"]).contains("server sets"),
		"a number picks the slot, and a fixed slot cannot be changed")
	var _q := screen.handle_key(host._key(KEY_Q))
	var _d := screen.handle_key(host._key(KEY_DOWN))
	host._check(screen.current_slot()["id"] == "secondary", "Q goes back a slot")
	var _back := screen.handle_key(host._key(KEY_BACKSPACE))
	host._check(screen.changes().is_empty(), "Backspace puts the draft back as it opened")
	var _one := screen.handle_key(host._key(KEY_1))
	var _c := screen.pick(2)
	node.menu.use_theme(&"paper")
	await host.get_tree().process_frame
	host._check(screen.is_open() and screen.kit.palette.id == &"paper" and host._texts(screen).has("Launcher"), "a theme change redraws it open")
	var _close := screen.handle_key(host._key(KEY_B))
	await host.get_tree().process_frame
	host._check(not screen.is_open() and saved == [{"primary": "launcher"}], "B again closes it and sends the changed slot, once")
	host._check(node.menu.toast_text() == "Loadout equipped.", "and what the game did is said on screen")
	host._check(lo.remembered() == {"primary": "launcher", "secondary": "pistol"}, "the choice is remembered for this account, fixed slots left to the server")


static func _restore_and_server_sets(host: Selftest, screen: DotMenuLoadoutScreen, lo: DotMenuLoadout, saved: Array) -> void:
	saved.clear()
	lo.open()
	await host.get_tree().process_frame
	var _esc := screen.handle_key(host._key(KEY_ESCAPE))
	host._check(not screen.is_open() and saved.is_empty(), "closing with nothing changed sends nothing")
	var restored: bool = await lo.restore()
	host._check(restored and saved == [{"primary": "launcher", "secondary": "pistol"}], "restore() sends the remembered choice again")

	saved.clear()
	lo.open_offer(host._loadout_offer(false))
	var _p := screen.pick(2)
	screen.close()
	host._check(saved.is_empty() and lo.last_offer["choose"] == false, "when the server sets every loadout, nothing can be picked or sent")



static func _online(host: Selftest, node: DotMenuSettings, screen: DotMenuLoadoutScreen, lo: DotMenuLoadout, link: FakeLoadoutLink, saved: Array) -> void:
	host._check(node.menu.handle_event(host._key(KEY_B)) and link.sent == ["/loadout locked"] and not screen.is_open(), "online, B asks the server, locked items included")
	link.answer(host._loadout_offer())
	await host.get_tree().process_frame
	host._check(screen.is_open() and lo.last_offer["slots"][0]["choices"][0].has("stats"), "and opens on its offer, with this client's art and numbers")
	var _one := screen.handle_key(host._key(KEY_2))
	var _c := screen.pick(1)
	screen.close()
	host._check(link.sent.back() == "/loadout secondary=revolver" and saved.is_empty(), "a choice is the server's to take, not this client's")
	link.answer({"result": {"ok": false, "text": "This server does not allow 'revolver' in the secondary slot."}})
	host._check(node.menu.toast_text().contains("does not allow"), "and a refusal is said on screen")
	load("res://examples/loadout_locked_checks.gd").run(host, screen, lo, link)
	load("res://examples/loadout_random_checks.gd").run(host, screen, lo, link)
