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
## [b]Escape is in no row and cannot be bound.[/b] It is the menu, it is how a browser
## releases the pointer, and a player who bound it to something else could never leave.
## [method add] refuses it.

const CHANNEL := "menu.bindings"

## The help key's action, setting and default: H in every game of the family (API 4).
const HELP_ACTION := &"dot_menu_help"
const HELP_SETTING := &"bind_help"
const HELP_KEY := "H"

## Rows, in the order the Controls page and the help screen draw them:
## `{action, setting, label, default, group, scope}`.
var rows: Array[Dictionary] = []


## Adds a row. [param scope] is a [enum DotSettingsDef.Scope]. Returns this, to chain.
##
## A second row for the same action or the same setting replaces the first in place, so a
## game can rename a stock row ("Duck" for "Crouch") without moving it.
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
		if rows[i]["action"] == action or rows[i]["setting"] == setting:
			rows[i] = row
			return self
	rows.append(row)
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


func remove(action: StringName) -> bool:
	for i in range(rows.size()):
		if rows[i]["action"] == action:
			rows.remove_at(i)
			return true
	return false


## Declares a binding setting for every row the schema does not already have. A row whose
## setting a game declared itself (with its own scope or description) is left alone.
func add_to_schema(s: DotSettingsSchema) -> void:
	for row in rows:
		var key: StringName = row["setting"]
		if s.has(key):
			continue
		s.add(DotSettingsDef.binding(key, str(row["default"]), &"bindings")
			.with_scope(int(row.get("scope", DotSettingsDef.Scope.DEVICE)) as DotSettingsDef.Scope)
			.with_description(str(row["label"])))


func row_for_setting(key: StringName) -> Dictionary:
	for row in rows:
		if row["setting"] == key:
			return row
	return {}


func row_for_action(action: StringName) -> Dictionary:
	for row in rows:
		if row["action"] == action:
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
func apply_row(row: Dictionary, text: String) -> String:
	var wanted := text if DotInputBinding.is_bound(text) else str(row["default"])
	var bound := DotInputBinding.apply(row["action"], wanted)

	if bound == DotInputBinding.UNBOUND:
		DotLog.warn(CHANNEL, "a key binding names no input; the default is used", {
			"action": String(row["action"]), "binding": text,
		})
		bound = DotInputBinding.apply(row["action"], str(row["default"]))

	return bound


## Every row from [param settings] onto the [InputMap]. Boot, and a reset.
func apply_all(settings: DotSettingsManager) -> void:
	for row in rows:
		apply_row(row, stored(row, settings))


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
func stored(row: Dictionary, settings: DotSettingsManager) -> String:
	var text := settings.get_string(row["setting"], str(row["default"])) if settings != null else str(row["default"])
	var event := DotInputBinding.from_text(text)
	if event == null:
		event = DotInputBinding.from_text(str(row["default"]))
	return DotInputBinding.to_text(event) if event != null else str(row["default"])


## The key a row is on right now, for a button or a help line. "—" for nothing.
static func shown(row: Dictionary) -> String:
	if row.is_empty():
		return "—"
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
		return DotResult.success("%s is on %s now, and %s moved to %s." % [str(row["label"]), text, str(other["label"]), old])
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
