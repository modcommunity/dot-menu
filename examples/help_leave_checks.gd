extends RefCounted

const Selftest := preload("res://examples/menu_selftest.gd")

## The help key and leaving a server, run from menu_selftest.

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

static func run(host: Selftest) -> void:
	host._section("H is help in every game, and Leave is stock")

	var fresh := DotMenu.new()
	host._check(fresh.help_action == DotMenuBindings.HELP_ACTION, "a menu's help key is dot_menu_help unless the game says otherwise")
	fresh.free()

	# A game with no table: DotMenuSettings gives it one with the help key, on H.
	if InputMap.has_action(DotMenuBindings.HELP_ACTION):
		InputMap.erase_action(DotMenuBindings.HELP_ACTION)
	var node := FilledSettings.new()
	node.app_namespace = &"menu_help_test"
	node.config = DotMenuConfig.new()
	node.config.brand_name = "Test Run"
	node.config.escape_grace_ms = 0
	host.add_child(node)
	var res := node.setup(DotSettingsStoreMemory.new())
	var row := node.bindings.row_for_action(DotMenuBindings.HELP_ACTION) if node.bindings != null else {}
	host._check(res.ok and not row.is_empty() and str(row["default"]) == "H", "a game with no key table gets one holding the help key, on H")
	host._check(node.settings.schema.has(DotMenuBindings.HELP_SETTING), "stored as bind_help, so the Controls page can rebind it")
	var hint := node.menu.help_hint
	host._check(hint != null and hint.visible and host._texts(hint).has("H") and host._texts(hint).has("Help"),
		"the HUD shows the help key in a corner while nothing is open")
	host._check(node.menu.handle_event(host._key(KEY_H)) and node.menu.help.is_open(), "H opens help with nothing else open")
	host._check(not hint.visible, "and the hint steps aside while help is up")
	await host.get_tree().process_frame
	var texts := host._texts(node.menu.help)
	host._check(texts.has("How to play Test Run") and texts.has("HOW TO PLAY") and texts.has("Reach the far side first."),
		"headed with the game's name, the goal first")
	host._check(texts.has("MODES") and texts.has("Help and controls"), "the game's own card, and the help key on its key card")
	host._check(node.menu.handle_event(host._key(KEY_H)) and not node.menu.help.is_open(), "and H closes it again")
	var _r := node.bindings.rebind(row, "F2", node.settings)
	host._check(not node.menu.handle_event(host._key(KEY_H)) and node.menu.handle_event(host._key(KEY_F2)) and node.menu.help.is_open(),
		"rebound, the new key opens help and H is the game's again")
	host._check(host._texts(hint).has("F2"), "and the hint says the new key")
	node.menu.help.close()
	await host.get_tree().process_frame

	await _leave(host, node)
	_taken_key(host)
	_own_row(host)
	await _bare_menu(host)


static func _leave(host: Selftest, node: FilledSettings) -> void:
	# Leave: there, and worded for where the player is.
	var leave := node.menu.screen.find_child("Action_leave", true, false) as Button
	node.open()
	host._check(leave != null and leave.visible and leave.text == ("" if DotPlatform.is_web() else "Quit game"),
		"Leave is in the stock menu, and solo on a desktop it quits")
	host._check(node.menu.screen.find_child("Action_help", true, false) != null, "so is Help & commands")
	node.close()
	var link := FakeLeaveLink.new()
	host.add_child(link)
	node.menu.leave_link = link
	node.open()
	host._check(leave.text == "Leave server", "connected, it leaves the server")
	node.menu.screen.action_requested.emit(&"leave")
	host._check(link.left.size() == 1 and not node.menu.any_open(), "and pressing it disconnects and closes the menu")
	node.queue_free()
	link.queue_free()
	await host.get_tree().process_frame


static func _taken_key(host: Selftest) -> void:
	# A table with something on H already: help goes to the next free key, never onto H twice.
	var keys := DotMenuBindings.new()
	keys.add(&"test_heal", &"bind_heal", "Medkit", "H", "Hands")
	var taken := DotMenuSettings.new()
	taken.app_namespace = &"menu_help_taken_test"
	taken.bindings = keys
	host.add_child(taken)
	var _t := taken.setup(DotSettingsStoreMemory.new(), false)
	host._check(keys.key_for(DotMenuBindings.HELP_ACTION) == "F1" and keys.defaults_on("H").size() == 1,
		"a table that already has H gets help on F1, and H stays on one row")
	taken.queue_free()


static func _own_row(host: Selftest) -> void:
	# A game whose help row is its own action keeps it, and the menu opens on that.
	var own := DotMenuBindings.new()
	own.add(&"test_own_help", &"bind_help", "Help", "H", "Interface")
	var own_node := DotMenuSettings.new()
	own_node.app_namespace = &"menu_help_own_test"
	own_node.bindings = own
	host.add_child(own_node)
	var _o := own_node.setup(DotSettingsStoreMemory.new())
	host._check(own.rows.filter(func(r: Dictionary) -> bool: return r["setting"] == &"bind_help").size() == 1
		and own_node.menu.help_action == &"test_own_help", "a game's own help row is kept, and is the menu's help key")
	own_node.queue_free()


static func _bare_menu(host: Selftest) -> void:
	# A menu built by hand with no table still gets H.
	if InputMap.has_action(DotMenuBindings.HELP_ACTION):
		InputMap.erase_action(DotMenuBindings.HELP_ACTION)
	var bare := DotMenu.new()
	bare.manage_pointer = false
	host.add_child(bare)
	var _b := bare.setup()
	host._check(bare.handle_event(host._key(KEY_H)) and bare.help.is_open(), "a menu with no key table puts help on H itself")
	await host.get_tree().process_frame
	host._check(host._texts(bare.help).has("Help and controls"), "and lists it, since no row does")
	bare.help.close()
	bare.help.title_text = "How to play Later"
	bare.open_help()
	await host.get_tree().process_frame
	host._check(host._texts(bare.help).has("How to play Later"), "a heading set after the screen was built is the one drawn")
	bare.help.close()
	host._check(bare.leave_label() == "Leave", "a menu that leaves the game's way keeps the config's word")
	var quiet := DotMenu.new()
	quiet.manage_pointer = false
	quiet.config = DotMenuConfig.new()
	quiet.config.help_hint = &"off"
	host.add_child(quiet)
	var _q := quiet.setup()
	host._check(quiet.help_hint == null, "a game that lists the key in its own HUD turns the hint off")
	quiet.queue_free()
	bare.queue_free()
	await host.get_tree().process_frame
