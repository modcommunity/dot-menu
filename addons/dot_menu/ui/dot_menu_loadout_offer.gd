extends Control

## The offer half of [DotMenuLoadoutScreen] (its base script): what the server offered, the draft, and the
## questions asked of them (slots, locks, Random, the budget). No drawing; the screen is in dot_menu_loadout_screen.gd.

## The offer it was opened with.
var offer: Dictionary = {}

## Slot id to item id: what closing will send.
var draft: Dictionary = {}

## The slot shown (index into the offer's slots) and the card the keys are on.
var slot_index: int = 0
var card_index: int = 0

var _original: Dictionary = {}


## Whether the server offers Random to this player.
func random_offered() -> bool:
	var r: Variant = offer.get("random", {})
	return r is Dictionary and bool((r as Dictionary).get("enabled", false)) and may_choose()


## Whether the server lets this player roll a random loadout at every spawn (its rule is 1 or 2).
func random_spawn_offered() -> bool:
	return random_offered() and random_spawn_rule() > 0


## The server's `mp_loadout_random_on_spawn` for this player's class: 0 off, 1 their choice, 2 forced.
func random_spawn_rule() -> int:
	var r: Variant = offer.get("random", {})
	return int((r as Dictionary).get("spawn", 0)) if r is Dictionary else 0


## Whether random-every-spawn applies to this player now: forced by the server, or their toggle.
func random_spawn_on() -> bool:
	var r: Variant = offer.get("random", {})
	return random_spawn_rule() == 2 or (r is Dictionary and bool((r as Dictionary).get("spawn_on", false)))


## The slots that differ from what the screen opened with: slot id to item id.
func changes() -> Dictionary:
	var out: Dictionary = {}
	for k: Variant in draft.keys():
		if str(_original.get(k, "")) != str(draft[k]):
			out[k] = draft[k]
	return out


func slots() -> Array:
	return offer.get("slots", []) if offer.get("slots") is Array else []


func may_choose() -> bool:
	return bool(offer.get("choose", true))


func current_slot() -> Dictionary:
	var all := slots()
	return all[slot_index] if slot_index >= 0 and slot_index < all.size() else {}


func choices() -> Array:
	var s := current_slot()
	return s.get("choices", []) if s.get("choices") is Array else []


func slot_locked(slot: Dictionary) -> bool:
	return not may_choose() or bool(slot.get("fixed", false)) or spawn_locked()


## Whether "random every spawn" is on (the player's tick, or forced by the server), which locks every
## other control of the screen until it is unticked: the loadout is rolled at each spawn, so a pick here
## would mean nothing. The draft is left as it was, so unticking brings the earlier picks back.
func spawn_locked() -> bool:
	return random_spawn_offered() and random_spawn_on()


## Whether cards show their cost: only when the server prices something (a budget, or a weapon with a cost).
func costs_shown() -> bool:
	return int(offer.get("budget", 0)) > 0 or bool(offer.get("priced", false))


## Points the draft would be over the budget with [param item] in [param slot_id]; 0 within it.
func over_budget_by(slot_id: String, item: Dictionary) -> int:
	var budget := int(offer.get("budget", 0))
	if budget <= 0:
		return 0
	return maxi(0, points_with(slot_id, item) - budget)


## The draft's points with [param item] in [param slot_id] (or as it is, with an empty item).
func points_with(slot_id: String = "", item: Dictionary = {}) -> int:
	var total := 0
	for s: Variant in slots():
		var slot := s as Dictionary
		var id := str(slot["id"])
		var held := str(item.get("id", "")) if id == slot_id and not item.is_empty() else str(draft.get(id, ""))
		total += _cost_of(slot, held)
	return total


static func _cost_of(slot: Dictionary, item_id: String) -> int:
	for c: Variant in slot.get("choices", []):
		if str((c as Dictionary).get("id", "")) == item_id:
			return int((c as Dictionary).get("cost", 0))
	return 0


static func _choice(slot: Dictionary, item_id: String) -> Dictionary:
	for c: Variant in slot.get("choices", []):
		if str((c as Dictionary).get("id", "")) == item_id:
			return c as Dictionary
	return {} if item_id == "" else {"id": item_id, "name": item_id.capitalize()}
