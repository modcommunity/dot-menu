extends RefCounted

## The "Every spawn" toggle next to Random, and the cost label shown only when a server prices something.


static func _pt_labels(screen: DotMenuLoadoutScreen) -> int:
	var n := 0
	for l in screen.find_children("*", "Label", true, false):
		if (l as Label).text.ends_with(" pt"):
			n += 1
	return n


static func run(host: Node, screen: DotMenuLoadoutScreen, lo: DotMenuLoadout, link: Object) -> void:
	var offer: Dictionary = host._loadout_offer()
	offer["random"] = {"enabled": true, "price": "", "count": 0, "spawn": 1, "spawn_on": false}
	lo.open_offer(offer)
	var toggle := screen.find_child("RandomSpawn", true, false) as Button
	host._check(toggle != null and toggle.visible and not toggle.button_pressed and toggle.get_parent() == (screen.find_child("Random", true, false) as Button).get_parent(), "the Every spawn toggle sits next to Random, off")
	# Web builds ship a font without the ballot-box glyphs (they drew as empty squares): the label must be plain ASCII.
	var ascii := true
	for c in toggle.text:
		ascii = ascii and c.unicode_at(0) < 128
	host._check(ascii and toggle.text.begins_with("[ ]"), "the toggle label is ASCII (no glyph the web font lacks), unticked: " + toggle.text)
	link.sent.clear()
	var _t := screen.handle_key(host._key(KEY_T))
	host._check(toggle.text.begins_with("[x]"), "ticked label after T: " + toggle.text)
	host._check(link.sent == ["/loadout randomspawn on"] and screen.is_open() and toggle.button_pressed, "T turns it on, tells the server, and keeps the menu open")
	_t = screen.handle_key(host._key(KEY_T))
	host._check(link.sent.back() == "/loadout randomspawn off" and not toggle.button_pressed, "T again turns it off")
	link.sent.clear()
	toggle.button_pressed = true
	host._check(link.sent == ["/loadout randomspawn on"], "a click does the same")

	offer["random"] = {"enabled": true, "price": "", "count": 0, "spawn": 2, "spawn_on": false}
	lo.open_offer(offer)
	link.sent.clear()
	_t = screen.handle_key(host._key(KEY_T))
	host._check(toggle.visible and toggle.button_pressed and toggle.disabled and link.sent.is_empty(), "forced by the server: shown on, locked, T does nothing")

	offer["random"] = {"enabled": true, "price": "", "count": 0, "spawn": 0, "spawn_on": false}
	lo.open_offer(offer)
	host._check(not toggle.visible, "switched off by the server: the toggle is hidden")

	offer["random"] = {"enabled": true, "price": "", "count": 0, "spawn": 1, "spawn_on": true}
	lo.open_offer(offer)
	host._check(toggle.button_pressed, "a saved choice is shown on when the menu opens")

	# Costs: free by default, shown when a budget or a priced weapon exists.
	offer["budget"] = 0
	lo.open_offer(offer)
	host._check(_pt_labels(screen) == 0, "no budget and nothing priced: no cost on any card")
	offer["priced"] = true
	lo.open_offer(offer)
	host._check(_pt_labels(screen) > 0, "a priced weapon shows its cost without a budget bar")
	offer["budget"] = 7
	lo.open_offer(offer)
	host._check(_pt_labels(screen) > 0, "a budget shows costs too")
	_locking(host, screen, lo, link, offer)
	screen.cancel()


## Ticking Every spawn locks everything else until it is unticked; the earlier picks come back; a reload with the flag saved opens locked.
static func _locking(host: Node, screen: DotMenuLoadoutScreen, lo: DotMenuLoadout, link: Object, offer: Dictionary) -> void:
	offer["budget"] = 0
	offer["priced"] = false
	offer["saved"] = [{"index": 0, "name": "Main", "selected": true, "saved": true}, {"index": 1, "name": "Alt", "selected": false, "saved": true}]
	offer["random"] = {"enabled": true, "price": "", "count": 0, "spawn": 1, "spawn_on": false}
	lo.open_offer(offer)
	var before: Dictionary = screen.draft.duplicate()
	var other := -1
	for i in screen.choices().size():
		if str((screen.choices()[i] as Dictionary)["id"]) != str(before.get(str(screen.current_slot()["id"]), "")) and not bool((screen.choices()[i] as Dictionary).get("locked", false)):
			other = i
			break
	host._check(other >= 0 and not screen.spawn_locked() and not (screen.find_child("Random", true, false) as Button).disabled, "unticked: nothing is locked")
	host._check(screen.pick(other), "unticked: a card can be picked")
	var picked: Dictionary = screen.draft.duplicate()
	host._check(picked != before, "the pick is in the draft")
	var toggle := screen.find_child("RandomSpawn", true, false) as Button
	toggle.button_pressed = true
	host._check(screen.spawn_locked(), "ticked: the screen is locked")
	host._check((screen.find_child("Random", true, false) as Button).disabled, "ticked: Random is greyed")
	for chip in ["Chip1", "Chip2", "SaveNew", "Rename", "Delete"]:
		var b := screen.find_child(chip, true, false) as BaseButton
		host._check(b != null and b.disabled, "ticked: %s is greyed" % chip)
	host._check((screen.find_child("SavedName", true, false) as LineEdit).editable == false, "ticked: the name field is read-only")
	var snapshot: Dictionary = screen.draft.duplicate()
	var accepted := true
	for i in screen.choices().size():
		accepted = accepted and not screen.pick(i)
	host._check(accepted and screen.draft == snapshot, "ticked: no card can be picked, the draft does not move")
	screen.revert()
	host._check(screen.draft == snapshot, "ticked: Revert does nothing")
	link.sent.clear()
	screen.request_random()
	screen.manage("use 2")
	host._check(link.sent.is_empty() and screen.is_open(), "ticked: Random and the saved-loadout actions send nothing")
	# The toggle itself stays live, and unticking gives the controls and the earlier picks back.
	toggle.button_pressed = false
	host._check(not screen.spawn_locked() and not (screen.find_child("Random", true, false) as Button).disabled and not (screen.find_child("Chip2", true, false) as BaseButton).disabled, "unticked again: controls are live")
	host._check(screen.draft == picked, "unticked again: the earlier picks are still there")
	host._check(screen.pick(0) or screen.draft == picked, "unticked again: picking works")
	screen.cancel()
	# A reload: the server answers with the flag saved, and the menu opens already locked, toggle on.
	offer["random"] = {"enabled": true, "price": "", "count": 0, "spawn": 1, "spawn_on": true}
	lo.open_offer(offer)
	host._check(screen.spawn_locked() and toggle.button_pressed and (screen.find_child("Random", true, false) as Button).disabled, "reopened with the flag saved: ticked and locked")
	# The server forcing it locks too, and a server that has it off never locks.
	offer["random"] = {"enabled": true, "price": "", "count": 0, "spawn": 2, "spawn_on": false}
	lo.open_offer(offer)
	host._check(screen.spawn_locked(), "forced by the server: locked")
	offer["random"] = {"enabled": true, "price": "", "count": 0, "spawn": 0, "spawn_on": true}
	lo.open_offer(offer)
	host._check(not screen.spawn_locked(), "rule off on the server: a stale saved flag does not lock")
	screen.cancel()
