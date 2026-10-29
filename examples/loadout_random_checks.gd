extends RefCounted

## The loadout menu's Random button and R key, run from menu_selftest (kept out of it to hold its size baseline).


static func run(host: Node, screen: DotMenuLoadoutScreen, lo: DotMenuLoadout, link: Object) -> void:
	# Random: offered by the server, asked for on R, never when the server did not offer it.
	var with_random: Dictionary = host._loadout_offer()
	with_random["random"] = {"enabled": true, "price": "50", "count": 0}
	lo.open_offer(with_random)
	var rbtn := screen.find_child("Random", true, false) as Button
	host._check(rbtn != null and rbtn.visible and rbtn.text == "Random (50)", "an offer with Random shows the button and its price")
	link.sent.clear()
	var _one := screen.handle_key(host._key(KEY_R))
	host._check(link.sent == ["/loadout random"] and not screen.is_open(), "R asks the server for a random loadout and closes without the draft")
	link.answer({"result": {"ok": true, "text": "Loadout saved.", "random": true}})
	host._check(link.sent.back() == "/loadout", "and a rolled loadout reopens the menu on the new one")
	var off: Dictionary = host._loadout_offer()
	off["random"] = {"enabled": false, "price": "", "count": 0}
	lo.open_offer(off)
	link.sent.clear()
	_one = screen.handle_key(host._key(KEY_R))
	host._check(not rbtn.visible and link.sent.is_empty() and screen.is_open(), "switched off, the button is hidden and R does nothing")
	screen.cancel()
