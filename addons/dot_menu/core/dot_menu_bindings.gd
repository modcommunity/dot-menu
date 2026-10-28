class_name DotMenuBindings
extends RefCounted

## Every key a client reads, as one table (action, setting, label, default, card), so the client, schema, Controls page and help screen never disagree. Stored per device by default.
## Escape is in no row and cannot be bound: it is the menu. [method add_extra] adds a key to an action as a row of its own. Example: docs/examples.md.

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

## The avatar emote, pose and gesture keys (API 16): `,` `.` `/` in every game that plays avatar
## actions. The actions are the ones dot-user-avatar's `DotAvatarActionInput` listens on.
const AVATAR_EMOTE_ACTION := &"dot_avatar_emote"
const AVATAR_POSE_ACTION := &"dot_avatar_pose"
const AVATAR_GESTURE_ACTION := &"dot_avatar_gesture"
const AVATAR_EMOTE_SETTING := &"bind_avatar_emote"
const AVATAR_POSE_SETTING := &"bind_avatar_pose"
const AVATAR_GESTURE_SETTING := &"bind_avatar_gesture"

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

## What a row's default was, `{setting: ["old key", ...]}` from [method renamed]. A stored key equal to one of
## these cannot be told from a chosen one in old documents, so it moves to the current default, once.
var renamed_defaults: Dictionary = {}

# What each extra row put on its action: {setting: InputEvent}. A primary row's apply erases
# every event on the action (dot-ui's apply replaces, on purpose), so it puts these back, and
# an extra's own re-apply takes off exactly the one it added.
var _extra_events: Dictionary = {}


## Adds a row. [param scope] is a [enum DotSettingsDef.Scope]. Returns this, to chain.
## A second row for the same action or setting replaces the first in place, so a game can
## rename a stock row without moving it. Extra rows ([method add_extra]) are never replaced.
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


## Adds an EXTRA key for [param action]: a row of its own, stored in [param setting], that adds its event instead of replacing it.
## Unlike an action's own row it can be set to [constant NONE]. [param group] empty is the action's group. Returns this.
## A row, not a second column: every reader of the table already understands a row.
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


## Declares that [param setting]'s default was each of [param old_keys] (as typed), for a default moved to make room for a family-shared key.
## A returning player who never touched the row gets the new default. Call before [method add_to_schema]. Returns this.
func renamed(setting: StringName, old_keys: Array) -> DotMenuBindings:
	var list: Array = renamed_defaults.get(setting, [])
	for k in old_keys:
		if not list.has(str(k)):
			list.append(str(k))
	renamed_defaults[setting] = list
	return self


## dot-player-controller's movement actions, by their own names. `DotFpsSampler` polls
## `dot_fps_*` and only creates actions that are missing, so a binding applied here first is
## the one it reads. Duck is Ctrl; a game that wants Shift passes it.
func add_movement(group: String = "Movement", crouch_key: String = "Ctrl", crouch_label: String = "Duck") -> DotMenuBindings:
	add(&"dot_fps_forward", &"bind_forward", "Forward", "W", group)
	add(&"dot_fps_back", &"bind_back", "Back", "S", group)
	add(&"dot_fps_left", &"bind_left", "Strafe left", "A", group)
	add(&"dot_fps_right", &"bind_right", "Strafe right", "D", group)
	add(&"dot_fps_jump", &"bind_jump", "Jump", "Space", group)
	add(&"dot_fps_crouch", &"bind_duck", crouch_label, crouch_key, group)
	return self


## The mouse wheel also jumps (`bind_jump_wheel_up`, `bind_jump_wheel_down`): two extra rows on `dot_fps_jump`. A game that cycles weapons calls [method add_wheel_weapons] instead.
## Not part of [method add_movement]: half the family puts the wheel on weapons, and a forgotten opt-in is a wheel that does nothing, which is visible.
## A wheel tick is a press and release in one event pair; `DotFpsSampler` latches presses so each tick reaches jump once.
func add_wheel_jump(group: String = "") -> DotMenuBindings:
	add_extra(JUMP_ACTION, WHEEL_JUMP_UP_SETTING, "Jump (wheel up)", "Wheel up", group)
	add_extra(JUMP_ACTION, WHEEL_JUMP_DOWN_SETTING, "Jump (wheel down)", "Wheel down", group)
	return self


## Takes the wheel's jump rows off again ([method add_wheel_jump]). True if there were any.
func remove_wheel_jump() -> bool:
	var a := remove_setting(WHEEL_JUMP_UP_SETTING)
	var b := remove_setting(WHEEL_JUMP_DOWN_SETTING)
	return a or b


## The wheel goes through the weapons ("Previous weapon" up, "Next weapon" down) as the action's own rows, and the wheel's jump rows are taken off.
## The defaults are [constant WEAPON_PREVIOUS_ACTION] and [constant WEAPON_NEXT_ACTION]; the game still does the cycling from its own input handler.
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


## The three avatar action keys (emote, pose, gesture), on [param group] or the help card.
func add_avatar_actions(group: String = "") -> DotMenuBindings:
	var where := group if group != "" else help_group()
	var _e := add(AVATAR_EMOTE_ACTION, AVATAR_EMOTE_SETTING, "Emote", "Comma", where)
	var _p := add(AVATAR_POSE_ACTION, AVATAR_POSE_SETTING, "Pose", "Period", where)
	return add(AVATAR_GESTURE_ACTION, AVATAR_GESTURE_SETTING, "Gesture", "Slash", where)


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
## Empty falls back to the default rather than unbinding: a settings file cleared by hand must not leave Forward on nothing.
## An extra row adds its one event instead, and [constant NONE] takes it off.
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


## Puts right any key two rows are stored on: the row whose default it is keeps it, others go back to their default (logged). Returns `"label: old -> new"` per move.
## Rebinding swaps so a player cannot make a conflict, but a moved default can; [method renamed] catches declared moves, this the rest.
## Rows that all default to the key are left alone; where none does, the first row keeps it.
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


## The binding a row is on: the stored one, or the default where the stored one names nothing. An extra row set to nothing is [constant NONE].
## The effective binding, not the stored text (a document cleared by hand stores "" for a default key), in dot-ui's current spelling
## ("Mouse 4" in an old document must read as the wheel).
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


## Puts [param text] on [param row]; whatever already had that key gets this row's old one. Returns what to tell the player, or a [DotResult] failure.
## A swap, not a refusal and not a steal: refusing makes a player unbind one thing to bind another, and stealing leaves a control on nothing.
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
