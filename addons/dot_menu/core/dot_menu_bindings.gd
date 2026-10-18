class_name DotMenuBindings
extends RefCounted

## Every key a client reads, as one table: the action, the setting that stores it, the words
## a player sees, the default, and the card it goes on.
##
## [codeblock]
## var keys := DotMenuBindings.new()
## keys.add_movement()                                   # dot_fps_* — WASD, Space, Ctrl
## keys.add(&"mygame_reload", &"bind_reload", "Reload", "R", "Combat")
## keys.add_to_schema(schema)                            # one binding setting per row
## keys.apply_all(settings)                              # onto the InputMap, at boot
## [/codeblock]
##
## [b]Data, because four things read it and they must never disagree.[/b] The client matches
## events against the actions, the settings schema declares one binding per row, the Controls
## page draws a key button per row, and the help screen lists each with the key it is on
## NOW. In the game this came from the keys had been a `match` on keycodes and a sentence in
## a doc comment, and the sentence had already drifted once.
##
## [b]Stored per DEVICE by default.[/b] A key is a fact about a keyboard: a laptop and a
## desktop are laid out differently, and a binding synchronised between them breaks one of
## the two. A row may say otherwise (`scope`), which is for a key that was stored per account
## before it was in a table: changing a stored setting's scope resets somebody's key.
##
## [b]An action may have extra keys[/b] ([method add_extra]): a row of its own that ADDS one
## event to the action instead of replacing what is there, stored in a setting of its own,
## and the one kind of row that may be set to nothing ([constant NONE]). The mouse wheel is
## the reason: "jump" on Space and on both wheel directions is three keys on one action, and
## the action, the setting and the Controls row are each still one fact. See
## [method add_wheel_jump] and [method add_wheel_weapons].
##
## [b]Escape is in no row and cannot be bound.[/b] It is the menu, it is how a browser
## releases the pointer, and a player who bound it to something else could never leave.
## [method add] refuses it.

const CHANNEL := "menu.bindings"

## The help key's action, setting and default: H in every game of the family (API 4).
const HELP_ACTION := &"dot_menu_help"
const HELP_SETTING := &"bind_help"
const HELP_KEY := "H"

## The map menu's action, setting and default: M in every game with more than one map (API 5).
## See [DotMenuMaps].
const MAPS_ACTION := &"dot_menu_maps"
const MAPS_SETTING := &"bind_maps"
const MAPS_KEY := "M"

## The loadout menu's key (API 6), B, in every game where players choose what they carry: the
## same row on every such game's Controls page, so "B is loadout" holds across the family.
const LOADOUT_ACTION := &"dot_menu_loadout"
const LOADOUT_SETTING := &"bind_loadout"
const LOADOUT_KEY := "B"

## The stock weapon-cycling actions and settings ([method add_wheel_weapons], API 10): the
## settings are the ones game-arena has always stored the wheel's weapon rows as, so a game
## that moves its own rows onto these keeps every player's keys.
const WEAPON_PREVIOUS_ACTION := &"dot_menu_weapon_previous"
const WEAPON_NEXT_ACTION := &"dot_menu_weapon_next"
const WEAPON_PREVIOUS_SETTING := &"bind_weapon_previous"
const WEAPON_NEXT_SETTING := &"bind_weapon_next"

## The wheel's extra jump keys ([method add_wheel_jump], API 10).
const JUMP_ACTION := &"dot_fps_jump"
const WHEEL_JUMP_UP_SETTING := &"bind_jump_wheel_up"
const WHEEL_JUMP_DOWN_SETTING := &"bind_jump_wheel_down"

## What an extra row ([method add_extra]) stores to say "no key". A word rather than "",
## because "" already means "the default" for every row (a document cleared by hand).
const NONE := "None"

## Rows, in the order the Controls page and the help screen draw them:
## `{action, setting, label, default, group, scope}`, plus `extra: true` on a row from
## [method add_extra].
var rows: Array[Dictionary] = []

## What a row's default USED to be: `{setting: ["old key", ...]}`, from [method renamed].
##
## A settings document from before documents recorded their defaults cannot tell a key the
## player chose from the default they never touched. A stored key equal to one of these is
## the latter and moves to the row's current default, once ([member
## DotSettingsDef.previous_defaults], which [method add_to_schema] fills from this).
var renamed_defaults: Dictionary = {}

# What each extra row put on its action: {setting: InputEvent}. A primary row's apply erases
# every event on the action (dot-ui's apply replaces, on purpose), so it puts these back, and
# an extra's own re-apply takes off exactly the one it added.
var _extra_events: Dictionary = {}


## Adds a row. [param scope] is a [enum DotSettingsDef.Scope]. Returns this, to chain.
##
## A second row for the same action or the same setting replaces the first in place, so a
## game can rename a stock row ("Duck" for "Crouch") without moving it. Extra rows
## ([method add_extra]) are not the action's row and are never replaced by one.
func add(
	action: StringName, setting: StringName, label: String, default_key: String,
	group: String = "General", scope: int = DotSettingsDef.Scope.DEVICE
) -> DotMenuBindings:
	if DotInputBinding.from_text(default_key) is InputEventKey \
			and (DotInputBinding.from_text(default_key) as InputEventKey).physical_keycode == KEY_ESCAPE:
		push_error("DotMenuBindings: Escape is the menu and cannot be bound (%s)." % action)
		return self

	var row := {
		"action": action, "setting": setting, "label": label, "default": default_key,
		"group": group, "scope": scope,
	}
	for i in range(rows.size()):
		if (rows[i]["action"] == action and not is_extra(rows[i])) or rows[i]["setting"] == setting:
			rows[i] = row
			return self
	rows.append(row)
	return self


## Adds an EXTRA key for [param action]: a row of its own, stored in [param setting], that
## adds its event to the action beside the action's own row instead of replacing it.
## Rebinding swaps with any other row as usual; unlike an action's own row it can be set to
## nothing ([constant NONE]; Delete on the Controls page). [param group] empty is the group of
## the action's own row. Drawn right after the action's last row. Returns this, to chain.
##
## [b]A row, not a second column.[/b] Every reader of the table (schema, Controls page,
## help screen, settle, the swap) already understands a row; a second column would be a
## second kind of binding each of them had to learn, and a table of one key per row is what
## lets "is this key taken" have one answer.
func add_extra(
	action: StringName, setting: StringName, label: String, default_key: String,
	group: String = "", scope: int = DotSettingsDef.Scope.DEVICE
) -> DotMenuBindings:
	var own := row_for_action(action)
	var row := {
		"action": action, "setting": setting, "label": label, "default": default_key,
		"group": group if group != "" else (str(own["group"]) if not own.is_empty() else "General"),
		"scope": scope, "extra": true,
	}
	for i in range(rows.size()):
		if rows[i]["setting"] == setting:
			rows[i] = row
			return self
	var at := -1
	for i in range(rows.size()):
		if rows[i]["action"] == action:
			at = i
	if at < 0:
		rows.append(row)
	else:
		rows.insert(at + 1, row)
	return self


## Whether [param row] is an extra key ([method add_extra]) rather than its action's own row.
static func is_extra(row: Dictionary) -> bool:
	return bool(row.get("extra", false))


## Removes the row stored as [param setting], whichever kind it is. True if there was one.
func remove_setting(setting: StringName) -> bool:
	for i in range(rows.size()):
		if rows[i]["setting"] == setting:
			_take_off_extra(rows[i])
			rows.remove_at(i)
			return true
	return false


## Declares that [param setting]'s default used to be each of [param old_keys] (as typed:
## "H", "C"). For a row whose default moved to make room for a key the family shares (help on
## H, the map menu on M, loadout on B, the view on F5): a returning player who never touched
## the row gets the new default instead of keeping the old one on two actions. Call before
## [method add_to_schema]. Returns this, to chain.
func renamed(setting: StringName, old_keys: Array) -> DotMenuBindings:
	var list: Array = renamed_defaults.get(setting, [])
	for k in old_keys:
		if not list.has(str(k)):
			list.append(str(k))
	renamed_defaults[setting] = list
	return self


## dot-player-controller's movement actions, by their own names. `DotFpsSampler` polls
## `dot_fps_*` and `register_default_actions` only creates what is missing, so a binding
## applied here first is the one it reads — there is no second copy of the movement keys.
##
## Duck is Ctrl, which is the genre's; a game that wants Shift passes it.
func add_movement(group: String = "Movement", crouch_key: String = "Ctrl", crouch_label: String = "Duck") -> DotMenuBindings:
	add(&"dot_fps_forward", &"bind_forward", "Forward", "W", group)
	add(&"dot_fps_back", &"bind_back", "Back", "S", group)
	add(&"dot_fps_left", &"bind_left", "Strafe left", "A", group)
	add(&"dot_fps_right", &"bind_right", "Strafe right", "D", group)
	add(&"dot_fps_jump", &"bind_jump", "Jump", "Space", group)
	add(&"dot_fps_crouch", &"bind_duck", crouch_label, crouch_key, group)
	return self


## The mouse wheel also jumps, both ways (`bind_jump_wheel_up`, `bind_jump_wheel_down`): two
## extra rows on `dot_fps_jump` beside Space. For every game where the wheel has nothing else
## to do; a game that cycles weapons calls [method add_wheel_weapons] instead, which takes
## these off again. Each is rebindable and may be set to nothing.
##
## [b]Not part of [method add_movement].[/b] Half the family's games put the wheel on their
## weapons, and in those a default wheel jump would be the wheel on two actions in every
## table that forgot to say otherwise, which [method settle] leaves alone (both rows default
## to it) and the player meets as a jump on every weapon change. Opting in is one call; a
## forgotten one is a wheel that does nothing, which is visible, not one that does two things.
##
## [b]A wheel tick is a press and a release in one event pair[/b], so it is never "held" when
## anything polls; dot-player-controller's `DotFpsSampler` latches presses between samples
## (its API 5) so each tick reaches the command as one press of jump.
func add_wheel_jump(group: String = "") -> DotMenuBindings:
	add_extra(JUMP_ACTION, WHEEL_JUMP_UP_SETTING, "Jump (wheel up)", "Wheel up", group)
	add_extra(JUMP_ACTION, WHEEL_JUMP_DOWN_SETTING, "Jump (wheel down)", "Wheel down", group)
	return self


## Takes the wheel's jump rows off again ([method add_wheel_jump]). True if there were any.
func remove_wheel_jump() -> bool:
	var a := remove_setting(WHEEL_JUMP_UP_SETTING)
	var b := remove_setting(WHEEL_JUMP_DOWN_SETTING)
	return a or b


## The wheel goes through the weapons: "Previous weapon" on Wheel up and "Next weapon" on
## Wheel down, as the action's own rows, and the wheel's jump rows (if any) are taken off.
## For every game with weapons or items to switch between. The defaults are the stock
## actions ([constant WEAPON_PREVIOUS_ACTION], [constant WEAPON_NEXT_ACTION]); a game with
## actions of its own passes them. The game still does the cycling: it reads the actions
## from its own input handler (`event.is_action_pressed(WEAPON_NEXT_ACTION)`), because only
## it knows what a slot is.
func add_wheel_weapons(
	previous_action: StringName = WEAPON_PREVIOUS_ACTION, next_action: StringName = WEAPON_NEXT_ACTION,
	group: String = "Weapons",
	previous_setting: StringName = WEAPON_PREVIOUS_SETTING, next_setting: StringName = WEAPON_NEXT_SETTING
) -> DotMenuBindings:
	var _off := remove_wheel_jump()
	add(previous_action, previous_setting, "Previous weapon", "Wheel up", group)
	add(next_action, next_setting, "Next weapon", "Wheel down", group)
	return self


## The push-to-talk key: dot-voice's `dot_voice_talk` action (`DotVoiceManager.TALK_ACTION`,
## named here as text because dot-menu does not depend on dot-voice), stored as
## `bind_voice_talk`, on V. [DotMenuSettings] adds it when the schema has the voice group.
func add_voice(group: String = "Communication", key: String = "V") -> DotMenuBindings:
	return add(&"dot_voice_talk", &"bind_voice_talk", "Push to talk", key, group)


## The help screen's key, which every game has on H unless it says otherwise: [DotMenu]'s
## default [member DotMenu.help_action]. [DotMenuSettings] adds it to a game's table; a game
## that builds its [DotMenu] itself calls this. [param group] empty is [method help_group].
func add_help(group: String = "", key: String = HELP_KEY) -> DotMenuBindings:
	return add(HELP_ACTION, HELP_SETTING, "Help and controls", key, group if group != "" else help_group())


## The map menu key (`dot_menu_maps`, stored as `bind_maps`), M by default, on the same card
## as help. [DotMenuSettings] adds it to every game's table; a game that builds its menu by
## hand calls this itself.
func add_maps(group: String = "", key: String = MAPS_KEY) -> DotMenuBindings:
	return add(MAPS_ACTION, MAPS_SETTING, "Change map", key, group if group != "" else help_group())


## The loadout menu key (`dot_menu_loadout`, stored as `bind_loadout`), B by default, on the same
## card as help. [DotMenuSettings] adds it when [member DotMenuSettings.loadout_menu] is on.
func add_loadout(group: String = "", key: String = LOADOUT_KEY) -> DotMenuBindings:
	return add(LOADOUT_ACTION, LOADOUT_SETTING, "Loadout", key, group if group != "" else help_group())


## The card the help key goes on: the interface keys, or the general ones, or the last card.
func help_group() -> String:
	var all := groups()
	for wanted in ["Interface", "General"]:
		if all.has(wanted):
			return wanted
	return all[all.size() - 1] if not all.is_empty() else "General"


## Every row whose DEFAULT is [param key] (as typed: "H", "Mouse 2"). More than one is a
## table that ships a conflict the swap cannot settle; what each game's suite asserts for H.
func defaults_on(key: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var wanted := DotInputBinding.from_text(key)
	for row in rows:
		var other := DotInputBinding.from_text(str(row["default"]))
		if wanted != null and other != null and same_input(wanted, other):
			out.append(row)
	return out


## The first of [param candidates] no row has as its default, or the last candidate. For a
## row added to a game's table from outside it (the talk key), which must not land on a key
## the game already uses: rebinding swaps, so a collision would silently move the game's own.
func free_key(candidates: Array) -> String:
	var taken := {}
	for row in rows:
		taken[str(row["default"]).to_upper()] = true
	for c in candidates:
		if not taken.has(str(c).to_upper()):
			return str(c)
	return str(candidates.back()) if not candidates.is_empty() else ""


## Removes [param action]'s own row and any extra keys it has. True if there was any.
func remove(action: StringName) -> bool:
	var found := false
	for i in range(rows.size() - 1, -1, -1):
		if rows[i]["action"] == action:
			_take_off_extra(rows[i])
			rows.remove_at(i)
			found = true
	return found


## Declares a binding setting for every row the schema does not already have. A row whose
## setting a game declared itself (with its own scope or description) is left alone.
func add_to_schema(s: DotSettingsSchema) -> void:
	for row in rows:
		var key: StringName = row["setting"]
		if not s.has(key):
			s.add(DotSettingsDef.binding(key, str(row["default"]), &"bindings")
				.with_scope(int(row.get("scope", DotSettingsDef.Scope.DEVICE)) as DotSettingsDef.Scope)
				.with_description(str(row["label"])))
		# Old defaults reach a declaration the game made itself too: they only add to it.
		var def := s.find(key)
		var old: Array = []
		for k in renamed_defaults.get(key, []):
			if str(k) != str(def.default_value):
				old.append(str(k))
		if not old.is_empty():
			var _d := def.with_previous_defaults(old)


func row_for_setting(key: StringName) -> Dictionary:
	for row in rows:
		if row["setting"] == key:
			return row
	return {}


## The action's own row, never one of its extra keys.
func row_for_action(action: StringName) -> Dictionary:
	for row in rows:
		if row["action"] == action and not is_extra(row):
			return row
	return {}


## The groups, in table order, each once.
func groups() -> PackedStringArray:
	var out := PackedStringArray()
	for row in rows:
		if not out.has(str(row["group"])):
			out.append(str(row["group"]))
	return out


func rows_in(group: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for row in rows:
		if str(row["group"]) == group:
			out.append(row)
	return out


## Puts one stored binding on its action. Returns what ended up bound.
##
## [b]Empty falls back to the default rather than unbinding.[/b] A settings file somebody
## cleared by hand would otherwise leave Forward bound to nothing, and the menu that could
## put it back is reached with a key the same file may have broken. Unbinding on purpose is
## binding the key to something else, which swaps (see [method rebind]).
##
## An extra row ([method add_extra]) adds its one event instead, and [constant NONE] takes it
## off; what it returns then is [constant NONE].
func apply_row(row: Dictionary, text: String) -> String:
	if is_extra(row):
		return _apply_extra(row, text)
	var wanted := text if DotInputBinding.is_bound(text) else str(row["default"])
	var bound := DotInputBinding.apply(row["action"], wanted)

	if bound == DotInputBinding.UNBOUND:
		DotLog.warn(CHANNEL, "a key binding names no input; the default is used", {
			"action": String(row["action"]), "binding": text,
		})
		bound = DotInputBinding.apply(row["action"], str(row["default"]))

	# dot-ui's apply replaced every event on the action, the extra keys' with them.
	for other in rows:
		if is_extra(other) and other["action"] == row["action"] and _extra_events.has(other["setting"]):
			var ev: InputEvent = _extra_events[other["setting"]]
			if not InputMap.action_has_event(row["action"], ev):
				InputMap.action_add_event(row["action"], ev)
	return bound


func _apply_extra(row: Dictionary, text: String) -> String:
	var action: StringName = row["action"]
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	_take_off_extra(row)
	if is_none(text):
		row["bound"] = NONE
		return NONE
	var event := DotInputBinding.from_text(text)
	if event == null:
		event = DotInputBinding.from_text(str(row["default"]))
	if event == null:
		row["bound"] = NONE
		return NONE
	if not InputMap.action_has_event(action, event):
		InputMap.action_add_event(action, event)
	_extra_events[row["setting"]] = event
	row["bound"] = DotInputBinding.to_text(event)
	return str(row["bound"])


# Takes off exactly the event this extra row added, and nothing the action's own row has.
func _take_off_extra(row: Dictionary) -> void:
	if not is_extra(row) or not _extra_events.has(row["setting"]):
		return
	var ev: InputEvent = _extra_events[row["setting"]]
	var _gone := _extra_events.erase(row["setting"])
	var action: StringName = row["action"]
	if not InputMap.has_action(action):
		return
	# Another row of the action may be on the same input; then it stays.
	var own := row_for_action(action)
	if not own.is_empty():
		var own_ev := DotInputBinding.from_text(DotInputBinding.describe_action(action))
		if own_ev != null and same_input(own_ev, ev):
			return
	for other_setting in _extra_events:
		if same_input(_extra_events[other_setting], ev):
			return
	if InputMap.action_has_event(action, ev):
		InputMap.action_erase_event(action, ev)


## Whether [param text] is the stored "no key" of an extra row.
static func is_none(text: String) -> bool:
	return text.strip_edges().to_lower() == NONE.to_lower()


## Every row from [param settings] onto the [InputMap]. Boot, and a reset. Settles any
## two rows stored on one key first ([method settle]).
func apply_all(settings: DotSettingsManager) -> void:
	var _settled := settle(settings)
	for row in rows:
		apply_row(row, stored(row, settings))


## Puts right any key two rows are stored on: the row whose default it is keeps it, every
## other goes back to its own default, and each move is logged. Returns `"label: old -> new"`
## for each row moved. [method apply_all] and [DotMenuApplier]'s run it at boot.
##
## [b]Why a document can hold a conflict at all.[/b] Rebinding swaps, so a player can never
## make one; a moved default can. A medkit saved on H by a build where H was its default,
## loaded by one where H is help, is two actions on one key: one of them never fires. The
## saved defaults ([DotSettingsManager]) and [method renamed] catch the moves somebody
## declared; this catches the rest, and a file edited by hand.
##
## Rows that all DEFAULT to the key are left alone: a table that ships a shared key meant it.
## Where no row's default is the key (two choices, by hand), the first row in the table keeps it.
func settle(settings: DotSettingsManager) -> PackedStringArray:
	var moved := PackedStringArray()
	if settings == null:
		return moved
	# Bounded: a row moved to its default can land on another row's choice, which the next
	# pass settles; each pass moves a row to its default for good, so rows.size() passes end it.
	for _pass in range(rows.size()):
		var groups: Array = []   # [[event, [rows]], ...]
		for row in rows:
			var ev := DotInputBinding.from_text(stored(row, settings))
			if ev == null:
				continue
			var placed := false
			for g in groups:
				if same_input(g[0], ev):
					(g[1] as Array).append(row)
					placed = true
					break
			if not placed:
				groups.append([ev, [row]])

		var changed := false
		for g in groups:
			var on_key: Array = g[1]
			if on_key.size() < 2:
				continue
			# An extra key never wins against an action's own row: it is new beside a key a
			# player may have put on the wheel long before it existed, and that choice stays.
			var contenders: Array = []
			for row in on_key:
				if not is_extra(row):
					contenders.append(row)
			if contenders.is_empty():
				contenders = on_key
			var owners: Array = []
			for row in contenders:
				var d := DotInputBinding.from_text(_default_text(row, settings))
				if d != null and same_input(d, g[0]):
					owners.append(row)
			if owners.size() == on_key.size():
				continue
			if owners.is_empty():
				owners.append(contenders[0])
			for row in on_key:
				if owners.has(row):
					continue
				var was := stored(row, settings)
				# An extra goes to nothing, not to its default: its default is usually the
				# very key it lost.
				var to := NONE if is_extra(row) else _default_text(row, settings)
				var res := settings.set_value(row["setting"], to, &"settle")
				if res.ok:
					moved.append("%s: %s -> %s" % [str(row["label"]), was, to])
					changed = true
		if not changed:
			break

	if not moved.is_empty():
		DotLog.info(CHANNEL, "two actions were stored on one key; the one whose default it is keeps it", {
			"moved": ", ".join(moved),
		})
	return moved


# The row's default as the schema declares it: a game may declare a row's setting itself,
# with a default of its own, and that is the one the document falls back to.
func _default_text(row: Dictionary, settings: DotSettingsManager) -> String:
	if settings != null and settings.schema != null:
		var def := settings.schema.find(row["setting"])
		if def != null:
			return str(def.default_value)
	return str(row["default"])


## Applies [param key] if it is one of this table's settings. True if it was.
## What a settings `changed` handler calls for anything it does not recognise.
func apply_setting(key: StringName, value: Variant) -> bool:
	var row := row_for_setting(key)
	if row.is_empty():
		return false
	var _bound := apply_row(row, str(value))
	return true


## The binding a row is on: the stored one, or the default where the stored one names
## nothing — which is what [method apply_row] put on the InputMap.
##
## [b]The effective binding, not the stored text.[/b] A document cleared by hand stores ""
## for a key that is really on its default; comparing the text, binding that default key to
## something else found no conflict, swapped nothing, and left one key on two actions.
##
## [b]In dot-ui's current spelling, not the stored one.[/b] A document written before dot-ui
## named the wheel says "Mouse 4" for it; the Controls page draws this text, and "Mouse 4"
## sends a player to their thumb button. On a dot-ui that has no names the round trip
## gives back the same text.
##
## An extra row set to nothing is [constant NONE].
func stored(row: Dictionary, settings: DotSettingsManager) -> String:
	var text := settings.get_string(row["setting"], str(row["default"])) if settings != null else str(row["default"])
	if is_extra(row) and is_none(text):
		return NONE
	var event := DotInputBinding.from_text(text)
	if event == null:
		event = DotInputBinding.from_text(str(row["default"]))
	return DotInputBinding.to_text(event) if event != null else str(row["default"])


## The key a row is on right now, for a button or a help line. "—" for nothing.
static func shown(row: Dictionary) -> String:
	if row.is_empty():
		return "—"
	if is_extra(row):
		var b := str(row.get("bound", row["default"]))
		return "—" if is_none(b) or b == "" else b
	var text := DotInputBinding.describe_action(row["action"])
	return text if text != DotInputBinding.UNBOUND else "—"


## The key [param action] is on right now, or "—".
func key_for(action: StringName) -> String:
	return shown(row_for_action(action))


## The row already using [param text], other than [param except], or an empty dictionary.
func row_using(text: String, except: StringName, settings: DotSettingsManager) -> Dictionary:
	var wanted := DotInputBinding.from_text(text)
	if wanted == null:
		return {}
	for row in rows:
		if row["setting"] == except:
			continue
		var other := DotInputBinding.from_text(stored(row, settings))
		if other != null and same_input(wanted, other):
			return row
	return {}


## Puts [param text] on [param row]; whatever already had that key gets this row's old one.
## Returns what to tell the player, or a [DotResult] failure when the setting refused it.
##
## [b]A swap, not a refusal and not a steal.[/b] Refusing ("F is already the flashlight")
## makes a player unbind one thing to bind another, and stealing leaves the other action on
## nothing — which for a movement key is a control they cannot use. Swapping is the one of
## the three that never leaves anything unbound.
func rebind(row: Dictionary, text: String, settings: DotSettingsManager) -> DotResult:
	if settings == null:
		return DotResult.fail(DotError.CODE_STATE, "No settings to store the key in.")

	var key: StringName = row["setting"]
	var old := stored(row, settings)
	var other := row_using(text, key, settings)

	# Only an extra key can be on nothing, and only an extra key can be given nothing. An
	# action's own row would fall back to its default and leave the key on two actions.
	if is_none(text) and not is_extra(row):
		return DotResult.fail(DotError.CODE_INVALID, "%s needs a key." % str(row["label"]))
	if is_none(old) and not other.is_empty() and not is_extra(other):
		return DotResult.fail(DotError.CODE_CONFLICT,
			"%s is %s. Give %s another key first." % [text, str(other["label"]), str(other["label"])])

	var res := settings.set_value(key, text)
	if not res.ok:
		return res

	# Applied here as well as by whoever listens to the settings: the two halves of a swap
	# must land together, and a table whose InputMap can lag its document is two copies.
	var _bound := apply_row(row, text)
	if not other.is_empty():
		var swapped := settings.set_value(other["setting"], old)
		if not swapped.ok:
			return swapped
		var _moved := apply_row(other, old)
		if is_none(old):
			return DotResult.success("%s is on %s now, and %s is on nothing." % [str(row["label"]), text, str(other["label"])])
		return DotResult.success("%s is on %s now, and %s moved to %s." % [str(row["label"]), text, str(other["label"]), old])
	if is_none(text):
		return DotResult.success("%s is on nothing now." % str(row["label"]))
	return DotResult.success("%s is on %s now." % [str(row["label"]), text])


func reset_all(settings: DotSettingsManager) -> void:
	if settings == null:
		return
	for row in rows:
		var _reset := settings.reset_value(row["setting"])
	apply_all(settings)


## Physical key and modifiers, or the same mouse button. A binding is where the key is, not
## what it says — mixing physical and logical makes a French player's A conflict with an
## English player's Q (dot-ui's reason).
static func same_input(a: InputEvent, b: InputEvent) -> bool:
	if a is InputEventKey and b is InputEventKey:
		var ka := a as InputEventKey
		var kb := b as InputEventKey
		return ka.physical_keycode == kb.physical_keycode \
			and ka.shift_pressed == kb.shift_pressed and ka.ctrl_pressed == kb.ctrl_pressed \
			and ka.alt_pressed == kb.alt_pressed and ka.meta_pressed == kb.meta_pressed

	if a is InputEventMouseButton and b is InputEventMouseButton:
		return (a as InputEventMouseButton).button_index == (b as InputEventMouseButton).button_index

	return DotInputBinding.to_text(a) == DotInputBinding.to_text(b)


func describe() -> Dictionary:
	return {"rows": rows.size(), "groups": Array(groups())}
