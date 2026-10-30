extends RefCounted

## The loadout screen's saved-loadout switcher, run from menu_selftest (kept out of it to hold its size baseline).


static func run(host: Node, screen: DotMenuLoadoutScreen, lo: DotMenuLoadout, link: Object) -> void:
	var off: Dictionary = host._loadout_offer()
	lo.open_offer(off)
	var saved_box := screen.find_child("Saved", true, false) as Control
	host._check(saved_box != null and not saved_box.visible, "an offer without saved loadouts hides the switcher")
	screen.cancel()
	off["saved"] = [
		{"index": 0, "name": "Assault", "selected": true, "saved": true},
		{"index": 1, "name": "Sniper", "selected": false, "saved": true},
	]
	lo.open_offer(off)
	host._check(saved_box.visible and screen.find_child("Chips", true, false).get_child_count() == 2, "an offer with two saved loadouts shows a chip each")
	link.sent.clear()
	(screen.find_child("Chip2", true, false) as Button).pressed.emit()
	host._check(link.sent == ["/loadout use 2"] and not screen.is_open(), "a chip asks the server to use that loadout and closes")
	link.answer({"result": {"ok": true, "text": "Loadout selected."}})
	host._check(link.sent.back() == "/loadout locked", "and the menu reopens on the server's answer")
	lo.open_offer(off)
	link.sent.clear()
	(screen.find_child("Chip1", true, false) as Button).pressed.emit()
	host._check(link.sent.is_empty() and screen.is_open(), "the lit chip does nothing")
	(screen.find_child("SavedName", true, false) as LineEdit).text = "  Close range "
	(screen.find_child("Rename", true, false) as Button).pressed.emit()
	host._check(link.sent == ["/loadout rename 1 Close range"], "Rename sends the selected index and the typed name")
	link.answer({"result": {"ok": true, "text": "Loadout renamed."}})
	lo.open_offer(off)
	link.sent.clear()
	(screen.find_child("SavedName", true, false) as LineEdit).text = "Backup"
	var _c := screen.pick(1)
	(screen.find_child("SaveNew", true, false) as Button).pressed.emit()
	host._check(link.sent.size() == 1 and (link.sent[0] as String).begins_with("/loadout save Backup "), "Save new sends the name with the draft's picks")
	link.answer({"result": {"ok": true, "text": "Loadout saved."}})
	lo.open_offer(off)
	link.sent.clear()
	(screen.find_child("Delete", true, false) as Button).pressed.emit()
	host._check(link.sent == ["/loadout delete 1"], "Delete sends the selected index")
	link.answer({"result": {"ok": false, "text": "A player keeps at least one loadout."}})
	host._check(link.sent.size() == 1, "a refusal does not reopen the menu")
	var one: Dictionary = host._loadout_offer()
	one["saved"] = [{"index": 0, "name": "Loadout 1", "selected": true, "saved": false}]
	lo.open_offer(one)
	host._check((screen.find_child("Delete", true, false) as Button).disabled and (screen.find_child("Rename", true, false) as Button).disabled, "a lone or unsaved loadout cannot be renamed or deleted")
	screen.cancel()
