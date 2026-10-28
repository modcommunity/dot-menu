class_name DotMenuLoadout
extends RefCounted

## The loadout menu: B opens [DotMenuLoadoutScreen] on what the player may carry, and closing it with changes saves them. Solo the game is asked directly; on a server the SERVER decides. Example: docs/examples.md.
## Connected, B sends `/loadout` through the client link's chat and opens on the `loadout_menu` notice; closing sends `/loadout slot=item ...` and the answer is a toast.
## Remembered per account on the client ([method remember_as], [method restore]) because a server forgets loadouts on restart. Nothing here names dot-loadout or dot-server.

const CHANNEL := "menu.loadout"

const TOPIC := &"loadout_menu"
const COMMAND := "loadout"

## Where remembered choices live: one file, keyed by game and account.
const REMEMBER_FILE := "user://dot_menu/loadouts.json"

## A choice was saved. [param result] is `{ok, text, now}`.
signal saved(picks: Dictionary, result: Dictionary)

## A line for the player, also shown as [method DotMenu.toast] unless [member toast] is off.
signal said(text: String)

## `func() -> Variant` (may await): the offer, solo. A [Dictionary], or a DotResult holding one.
var offer_fn: Callable = Callable()

## `func(picks: Dictionary) -> Variant` (may await): save [param picks] (slot id to item id), solo.
## A DotResult, a `{ok, text, now}` dictionary, or anything else for "saved".
var choose_fn: Callable = Callable()

## `func(slot_id: String, choice: Dictionary) -> Dictionary`: what to add to a choice: `icon` (a
## texture or a `res://` path), `detail`, `kind`, `stats` (`[{label, value 0..1, text}]`), `tags`.
var decorate_fn: Callable = Callable()

## Whether B opens anything. A game whose mode hands out the weapons (gun game) turns it off.
var enabled: bool = true

## The menu it draws in. Set by [method DotMenu.use_loadout].
var menu: DotMenu = null

## What is asked when connected: anything with `send_chat(text)` and `notice_received`. Null looks
## up [member link_service] in [DotRegistry] when B is pressed.
var link: Object = null
var link_service: StringName = &"dot_client_link"
var command_prefix: String = "/"

## The screen's heading.
var title: String = "Loadout"

var toast: bool = true

## Seconds to wait for a server that never answers (one with no loadout command) before saying so.
var answer_timeout_sec: float = 4.0

## Remembering: the game and account a choice is filed under; "" game is off.
var remember_game: String = ""
var remember_account: String = "local"

var last_offer: Dictionary = {}
var last_result: Dictionary = {}
var last_said: String = ""

var _waiting_since_msec: int = -1
var _bound_link: Object = null
var _quiet_until_msec: int = 0


## Opens the menu: the solo offer now, or asks the server and opens on its answer.
func open() -> void:
	if not enabled or menu == null:
		return
	var l := _link()
	if _connected(l):
		_ask(l, "")
		return
	if not offer_fn.is_valid():
		_say("This game has no loadouts.")
		return
	var got: Variant = await offer_fn.call()
	var data := _dictionary(got)
	if data.is_empty():
		_say(_failure_text(got, "No loadout to show."))
		return
	open_offer(data)


## Opens the screen on [param data] (`DotLoadoutManager.offer_for`'s shape), decorated. Public so a
## game with its own wire for the offer, or a suite, can open it.
func open_offer(data: Dictionary) -> void:
	if menu == null:
		return
	last_offer = decorate(data)
	var screen := menu.loadout_screen
	if screen == null:
		return
	screen.title_text = title
	screen.toggle_action = menu.loadout_action
	menu.open_loadout_screen(last_offer)


## [param data] with [member decorate_fn]'s additions on every choice. A copy.
func decorate(data: Dictionary) -> Dictionary:
	var out := data.duplicate(true)
	if not decorate_fn.is_valid():
		return out
	for s: Variant in out.get("slots", []):
		var slot := s as Dictionary
		for c: Variant in slot.get("choices", []):
			var choice := c as Dictionary
			var extra: Variant = decorate_fn.call(str(slot.get("id", "")), choice)
			if extra is Dictionary:
				for k: Variant in (extra as Dictionary).keys():
					choice[k] = (extra as Dictionary)[k]
	return out


## The screen closed with changes. Solo: [member choose_fn]; connected: the server.
func commit(picks: Dictionary) -> void:
	if picks.is_empty():
		return
	var whole := _whole(picks)
	var l := _link()
	if _connected(l):
		_ask(l, _choice_text(picks))
		_remember(whole)
		return
	if not choose_fn.is_valid():
		_say("This game cannot change your loadout.")
		return
	var got: Variant = await choose_fn.call(picks)
	var result := _result_of(got)
	last_result = result
	if bool(result.get("ok", false)):
		_remember(whole)
	saved.emit(picks, result)
	_say(str(result.get("text", "")))


## The whole loadout after [param picks]: what the screen opened with, changed.
func _whole(picks: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for s: Variant in last_offer.get("slots", []):
		var slot := s as Dictionary
		if bool(slot.get("fixed", false)):
			continue
		var cur := str(slot.get("current", ""))
		if cur != "":
			out[str(slot.get("id", ""))] = cur
	for k: Variant in picks.keys():
		out[str(k)] = str(picks[k])
	return out


## `slot=item ...` in text order: the command's argument.
static func _choice_text(picks: Dictionary) -> String:
	var keys: Array = picks.keys()
	keys.sort_custom(func(a: Variant, b: Variant) -> bool: return str(a) < str(b))
	var parts := PackedStringArray()
	for k: Variant in keys:
		parts.append("%s=%s" % [k, str(picks[k]) if str(picks[k]) != "" else "none"])
	return " ".join(parts)


static func _result_of(got: Variant) -> Dictionary:
	if got is Dictionary:
		var d := got as Dictionary
		return {"ok": bool(d.get("ok", true)), "text": str(d.get("text", "Loadout saved.")), "now": bool(d.get("now", false))}
	if got is Object and (got as Object).get("ok") != null:
		var ok := bool((got as Object).get("ok"))
		if ok:
			var v: Variant = (got as Object).get("value")
			if v is Dictionary:
				return _result_of(v)
			return {"ok": true, "text": "Loadout saved.", "now": false}
		return {"ok": false, "text": _failure_text(got, "That loadout was refused."), "now": false}
	return {"ok": true, "text": "Loadout saved.", "now": false}


static func _dictionary(got: Variant) -> Dictionary:
	if got is Dictionary:
		return got as Dictionary
	if got is Object and bool((got as Object).get("ok")) and (got as Object).get("value") is Dictionary:
		return (got as Object).get("value") as Dictionary
	return {}


static func _failure_text(got: Variant, fallback: String) -> String:
	if got is Object:
		var err: Variant = (got as Object).get("error")
		if err is Object and str((err as Object).get("message")) != "":
			return str((err as Object).get("message"))
	return fallback


## Files choices under [param game] and [param account] from now on. "" game turns it off.
func remember_as(game: String, account: String = "local") -> void:
	remember_game = game
	remember_account = account if account != "" else "local"


## What this account chose last time in this game: slot id to item id, or empty.
func remembered() -> Dictionary:
	if remember_game == "":
		return {}
	var all := _read_file()
	var games: Variant = all.get(remember_game, {})
	if not (games is Dictionary):
		return {}
	var picks: Variant = (games as Dictionary).get(remember_account, {})
	return (picks as Dictionary).duplicate() if picks is Dictionary else {}


## Sends the remembered choice again (solo to [member choose_fn], connected to the server), quietly:
## only a refusal is said. What a game calls once the player is in.
func restore() -> bool:
	var picks := remembered()
	if picks.is_empty() or not enabled:
		return false
	var l := _link()
	if _connected(l):
		_quiet_until_msec = Time.get_ticks_msec() + int(answer_timeout_sec * 1000.0)
		_ask(l, _choice_text(picks))
		return true
	if not choose_fn.is_valid():
		return false
	var got: Variant = await choose_fn.call(picks)
	var result := _result_of(got)
	last_result = result
	if not bool(result.get("ok", false)):
		_say("Your saved loadout: " + str(result.get("text", "")))
	DotLog.debug(CHANNEL, "remembered loadout restored", {"picks": _choice_text(picks), "ok": result.get("ok", false)})
	return bool(result.get("ok", false))


func _remember(picks: Dictionary) -> void:
	if remember_game == "" or picks.is_empty():
		return
	var all := _read_file()
	var games: Dictionary = all.get(remember_game, {}) if all.get(remember_game) is Dictionary else {}
	games[remember_account] = picks.duplicate()
	all[remember_game] = games
	var dir := REMEMBER_FILE.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir):
		var _made := DirAccess.make_dir_recursive_absolute(dir)
	var f := FileAccess.open(REMEMBER_FILE, FileAccess.WRITE)
	if f == null:
		DotLog.warn(CHANNEL, "could not remember the loadout", {"path": REMEMBER_FILE, "error": FileAccess.get_open_error()})
		return
	f.store_string(JSON.stringify(all, "\t", true))
	f.close()
	DotWeb.sync_filesystem()


static func _read_file() -> Dictionary:
	if not FileAccess.file_exists(REMEMBER_FILE):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(REMEMBER_FILE))
	return parsed as Dictionary if parsed is Dictionary else {}


func _ask(l: Object, args: String) -> void:
	_bind(l)
	_waiting_since_msec = Time.get_ticks_msec()
	l.call(&"send_chat", "%s%s%s" % [command_prefix, COMMAND, (" " + args) if args != "" else ""])
	if menu != null and menu.is_inside_tree() and answer_timeout_sec > 0.0:
		var asked := _waiting_since_msec
		menu.get_tree().create_timer(answer_timeout_sec).timeout.connect(func() -> void:
			if _waiting_since_msec == asked:
				_waiting_since_msec = -1
				if Time.get_ticks_msec() > _quiet_until_msec:
					_say("The server did not answer: it may not have loadouts."))


func _bind(l: Object) -> void:
	if l == _bound_link or not l.has_signal(&"notice_received"):
		return
	if _bound_link != null and is_instance_valid(_bound_link) and _bound_link.is_connected(&"notice_received", _on_notice):
		_bound_link.disconnect(&"notice_received", _on_notice)
	l.connect(&"notice_received", _on_notice)
	_bound_link = l


func _on_notice(notice: Object) -> void:
	if notice == null or StringName(str(notice.get("topic"))) != TOPIC:
		return
	var data: Variant = notice.get("data")
	if data is Dictionary:
		receive(data as Dictionary)


## The server's answer, as the notice's data: `{slots: [...], ...}` opens the screen;
## `{result: {ok, text, now}}` is the outcome of a choice. Public for a suite.
func receive(data: Dictionary) -> void:
	_waiting_since_msec = -1
	if data.has("slots"):
		open_offer(data)
	elif data.get("result") is Dictionary:
		var result := data["result"] as Dictionary
		last_result = result
		var quiet := Time.get_ticks_msec() <= _quiet_until_msec
		_quiet_until_msec = 0
		saved.emit({}, result)
		if not quiet or not bool(result.get("ok", false)):
			_say(str(result.get("text", "")))


func _say(text: String) -> void:
	if text == "":
		return
	last_said = text
	said.emit(text)
	if toast and menu != null:
		menu.toast(text)


func _link() -> Object:
	if link != null and is_instance_valid(link):
		return link
	if link_service == &"":
		return null
	return DotRegistry.get_node_service(link_service)


static func _connected(l: Object) -> bool:
	if l == null or not is_instance_valid(l) or not l.has_method(&"send_chat"):
		return false
	return not l.has_method(&"is_connected_to_server") or bool(l.call(&"is_connected_to_server"))


func is_online() -> bool:
	return _connected(_link())


func describe() -> Dictionary:
	return {
		"enabled": enabled, "solo": offer_fn.is_valid() and choose_fn.is_valid(), "online": is_online(),
		"remember": "%s/%s" % [remember_game, remember_account] if remember_game != "" else "",
		"last_result": last_result.get("text", ""), "last_said": last_said,
		"slots": (last_offer.get("slots", []) as Array).size() if last_offer.get("slots") is Array else 0,
	}
