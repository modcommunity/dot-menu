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
	link.sent.clear()
	var _t := screen.handle_key(host._key(KEY_T))
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
	screen.cancel()
