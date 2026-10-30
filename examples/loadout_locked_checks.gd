extends RefCounted

## Locked items in the loadout menu, run from menu_selftest.


class StoreCatcher extends RefCounted:
	var got: Array = []

	func on_store(item_id: StringName, url: String) -> void:
		got.append([item_id, url])


static func run(host: Node, screen: DotMenuLoadoutScreen, lo: DotMenuLoadout, link: Object) -> void:
	var offer: Dictionary = host._loadout_offer()
	var primary := (offer["slots"] as Array)[0] as Dictionary
	for c: Variant in primary["choices"]:
		var choice := c as Dictionary
		var locked: bool = choice["id"] == "sniper"
		choice["locked"] = locked
		choice["store"] = "https://example.com/store" if locked else ""
	lo.open_offer(offer)
	screen.show_slot(0)
	var before: String = str(screen.draft.get("primary", ""))
	host._check(not screen.pick(1) and str(screen.draft.get("primary", "")) == before, "a locked item cannot be picked")
	host._check(screen.describe()["status"].contains("store"), "and the status line says to get it in the store")
	var btn := screen.find_child("GetInStore", true, false) as Button
	host._check(btn != null, "the detail of a locked item has a Get in store button")
	var catcher := StoreCatcher.new()
	lo.store_requested.connect(catcher.on_store)
	var hooked: Array = []
	lo.store_fn = func(id: StringName) -> String:
		hooked.append(id)
		return ""
	if btn != null:
		btn.pressed.emit()
	host._check(catcher.got == [[&"sniper", "https://example.com/store"]] and hooked == [&"sniper"],
		"the button reaches store_requested and the game's store hook with the item's address")
	lo.store_requested.disconnect(catcher.on_store)
	lo.store_fn = Callable()
	host._check(not screen.pick(0) or str(screen.draft["primary"]) == "rifle", "an owned item still picks")
	screen.cancel()
	screen.show_slot(1)
	link.sent.clear()
	lo.include_locked = false
	@warning_ignore("missing_await")
	lo.open()
	host._check(link.sent == ["/loadout"], "with include_locked off the plain offer is asked for")
	lo.include_locked = true
