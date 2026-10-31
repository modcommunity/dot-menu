class_name DotMenuTeams
extends RefCounted

## The team menu: the period key opens [DotMenuTeamScreen] with a card per team and Spectate. Solo it reads [member offer_fn]; on a server the SERVER decides: this sends `/teams` through the client link's chat, reads the `team_menu` notice, and a choice sends `/teams <id>` (`auto`, `play` or `spectate`).
## Nothing here names dot-server or dot-team; the data is `{teams: [{id, name, colour, count, max, closed, current}], ffa, spectating, spectate_ok, enabled, wait, result}`.

const CHANNEL := "menu.teams"
const TOPIC := &"team_menu"
const COMMAND := "teams"

## A line for the player (a refusal, a switch). Also toasted unless [member toast] is off.
signal said(text: String)

## `func() -> Dictionary`, for solo: the data above.
var offer_fn: Callable = Callable()
## `func(id: String) -> DotResult`, for solo: switch now.
var choose_fn: Callable = Callable()

var enabled: bool = true
var menu: DotMenu = null
var link: Object = null
var link_service: StringName = &"dot_client_link"
var command_prefix: String = "/"
var toast: bool = true
## Seconds between asks while the menu is open, so the counts stay live. 0 turns it off.
var refresh_sec: float = 2.0
var answer_timeout_sec: float = 4.0

var last_offer: Dictionary = {}
var last_said: String = ""

var _bound_link: Object = null
var _waiting_since_msec: int = -1
## Name of the card last chosen, for the toast on success.
var _chosen_name: String = ""


func open() -> void:
	if not enabled or menu == null:
		return
	var l := _link()
	if _connected(l):
		_ask(l, "")
		return
	if not offer_fn.is_valid():
		_say("This game has no teams to choose.")
		return
	show_data(offer_fn.call())


## Draws the menu on [param data]; public for a game with its own wire and for a suite.
func show_data(data: Dictionary) -> void:
	last_offer = data.duplicate(true)
	if menu != null:
		menu.show_teams(data)


## The screen asks again for live counts.
func refresh() -> void:
	var l := _link()
	if _connected(l):
		_ask(l, "")
	elif offer_fn.is_valid() and menu != null and menu.team_screen != null:
		menu.team_screen.refresh(offer_fn.call())


## A card was chosen: `<id>` as text, `play` or `spectate`.
func choose(id: String) -> void:
	_chosen_name = id
	if menu != null and menu.team_screen != null:
		for e: Variant in menu.team_screen.entries:
			if str((e as Dictionary)["id"]) == id:
				_chosen_name = str((e as Dictionary)["name"])
	var l := _link()
	if _connected(l):
		_ask(l, id)
		return
	if not choose_fn.is_valid():
		_say("This game cannot change teams.")
		return
	var res: Variant = choose_fn.call(id)
	var result: DotResult = res if res is DotResult else DotResult.success(id)
	if result.ok:
		_done(true, "")
	else:
		_done(false, result.error.message)


func _ask(l: Object, id: String) -> void:
	_bind(l)
	_waiting_since_msec = Time.get_ticks_msec()
	l.call(&"send_chat", "%s%s%s" % [command_prefix, COMMAND, (" " + id) if id != "" else ""])
	if id == "" and menu != null and menu.is_inside_tree() and answer_timeout_sec > 0.0:
		var asked := _waiting_since_msec
		menu.get_tree().create_timer(answer_timeout_sec).timeout.connect(func() -> void:
			if _waiting_since_msec == asked:
				_waiting_since_msec = -1
				_say("The server did not answer."))


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


## The server's answer. A `result` that is ok closes the menu; a refusal stays up with its reason.
func receive(data: Dictionary) -> void:
	_waiting_since_msec = -1
	var open_now := menu != null and menu.team_screen != null and menu.team_screen.is_open()
	if data.get("result") is Dictionary:
		var res := data["result"] as Dictionary
		_done(bool(res.get("ok", false)), str(res.get("message", "")))
		if bool(res.get("ok", false)):
			return
	last_offer = data.duplicate(true)
	if menu == null:
		return
	if open_now:
		menu.team_screen.refresh(data)
	else:
		menu.show_teams(data)


func _done(ok: bool, message: String) -> void:
	if ok:
		if menu != null and menu.team_screen != null:
			menu.team_screen.close()
		_say(("You are now: %s" % _chosen_name) if _chosen_name != "" and message == "" else message)
	elif message != "":
		if menu != null and menu.team_screen != null:
			menu.team_screen.last_result = message
		_say(message)


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


func describe() -> Dictionary:
	return {"enabled": enabled, "solo": offer_fn.is_valid(), "online": _connected(_link()),
		"last_said": last_said, "teams": (last_offer.get("teams", []) as Array).size(), "ffa": last_offer.get("ffa", null)}
