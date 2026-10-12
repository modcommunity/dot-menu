class_name DotMenuMaps
extends RefCounted

## The map menu: M opens a picker of the game's maps (or courses, layouts, routes, modes), and
## choosing one changes to it. Solo it changes directly; on a server the SERVER decides.
##
## [codeblock]
## var maps := menu.use_maps(
## 	func() -> Array: return [{"id": "dm_atrium", "name": "Atrium", "mode": "Deathmatch",
## 		"thumbnail": "res://maps/atrium.png", "current": true}, ...],
## 	func(id: StringName) -> DotResult: return world.change_map_now(id))
## [/codeblock]
##
## [b]Why solo and online are one key with two halves.[/b] Christian's first play test: games
## booted solo had no way to change the map at all, and the ones that had one (a map list on
## M in one game, "vote for another map" in another) said different things. Solo there is
## nobody to ask, so the player's choice is the change. On a server the change is everybody's,
## so it is the server's to allow: this sends `/mapmenu` through the client link's chat (a
## prefixed line is a command and is never shown to anyone), and dot-vote's [code]DotVoteMapMenu[/code]
## answers with a notice on the `map_menu` topic carrying the list, whether this player may
## change it directly (the flag the owner named in `sv_map_menu_flag`, staff by default) and
## whether a vote can be started instead. Choosing sends `/mapmenu <id>`; the server changes
## the map (every peer follows through the game's own change path), or nominates the map and
## rocks the vote for a player without the flag, and says which in a `map_menu` result.
##
## [b]Nothing here names dot-server or dot-vote.[/b] The link is found as `dot_client_link`
## in [DotRegistry] when M is pressed (a link made after the menu is still the one asked, as
## for Leave), and a notice is read by its `topic` and `data`, duck-typed.
##
## A row is `{id, name, mode, detail, thumbnail, current, tags}`. `mode` is drawn as the second
## line (or `detail` when there is no mode); `tags` as on any picker row.

const CHANNEL := "menu.maps"

## The notice topic the server answers on, and the command it answers.
const TOPIC := &"map_menu"
const COMMAND := "mapmenu"

## Solo: the map changed. [param result] is what the change returned.
signal changed(id: StringName, result: DotResult)

## A line for the player: a refusal, a vote started, a change made. Also drawn by
## [method DotMenu.toast] unless [member toast] is off.
signal said(text: String)

## `func() -> Array` of rows, for solo. Read every time M is pressed: a delivered map pack
## that arrives later is in the next list.
var rows_fn: Callable = Callable()

## `func(id: StringName) -> DotResult` (may await), for solo: change now.
var change_fn: Callable = Callable()

## Whether M opens anything. A game whose server is the only judge (no solo world) still
## sets this; one with a single map leaves the menu unwired instead.
var enabled: bool = true

## The menu it draws in. Set by [method DotMenu.use_maps].
var menu: DotMenu = null

## What is asked when connected: anything with `send_chat(text)` and `notice_received`.
## Null looks up [member link_service] in [DotRegistry] when M is pressed.
var link: Object = null
var link_service: StringName = &"dot_client_link"

## The command prefix sent to the server. `/` is a command on every dot-server by default
## (`chat_command_prefixes`), and a command line is never broadcast.
var command_prefix: String = "/"

## The picker's heading, and the word for one row ("maps", "courses", "layouts").
var title: String = "Change map"
var noun: String = "maps"

## Draw [signal said] lines as a toast on the menu's layer.
var toast: bool = true

## Seconds to wait for a server that never answers (one from before the map menu) before
## saying so.
var answer_timeout_sec: float = 4.0

## The last server answer: `{allowed, flag, vote, maps, where}`. For a suite and describe().
var last_offer: Dictionary = {}
## The last result line, solo or from the server.
var last_said: String = ""
## Whether the picker that is open (or was last) changes directly or starts a vote.
var direct: bool = true

var _waiting_since_msec: int = -1
## A long list arrives in parts (`part` of `parts`, a notice carries 8 KB): rows by part,
## until every one is here.
var _parts: Dictionary = {}
var _bound_link: Object = null


## Opens the menu: the solo list now, or asks the server and opens on its answer.
func open() -> void:
	if not enabled or menu == null:
		return
	var l := _link()
	if _connected(l):
		_ask(l, "")
		return
	if not rows_fn.is_valid():
		_say("This game has no map list.")
		return
	open_rows(rows_fn.call(), true, "solo")


## Opens the picker on [param rows]. [param allowed] false is the vote fallback: the heading
## and instructions say so, and choosing asks for a vote. Public so a game with its own wire
## for the list (or a suite) can open it.
func open_rows(rows: Array, allowed: bool, where: String = "", flag: String = "", vote: bool = true) -> void:
	if menu == null:
		return
	direct = allowed
	var items := items_for(rows)
	var p := menu.picker
	p.noun = noun
	p.footer_extra = Callable()
	var key := menu.bindings.key_for(menu.maps_action) if menu.bindings != null and not menu.bindings.row_for_action(menu.maps_action).is_empty() \
		else DotInputBinding.describe_action(menu.maps_action)
	var heading := title
	if allowed:
		p.instructions = "1–7 or click to change to it. 8 and 9 turn the page. 0, %s or Esc closes." % key
	elif vote:
		heading = "Vote for a map"
		p.instructions = "Changing the map here needs the '%s' permission. Choosing one nominates it and rocks the vote. 0, %s or Esc closes." % [flag, key]
	else:
		p.instructions = "Changing the map here needs the '%s' permission, and voting is off on this server." % flag
	if where != "":
		heading += " — " + where
	menu.open_picker(items, heading, menu.maps_action, _chosen)


## Picker items from rows: the mode (or detail) as the second line, "playing" on the current one.
func items_for(rows: Array) -> Array:
	var out: Array = []
	for r: Variant in rows:
		if not (r is Dictionary):
			continue
		var row := r as Dictionary
		var id := str(row.get("id", ""))
		if id == "":
			continue
		var tags: Array = []
		var current := bool(row.get("current", false))
		if current:
			tags.append("playing")
		for t: Variant in row.get("tags", []):
			tags.append(str(t))
		var detail := str(row.get("mode", ""))
		var extra := str(row.get("detail", ""))
		if extra != "":
			detail = extra if detail == "" else "%s  ·  %s" % [detail, extra]
		var item := {"id": id, "name": str(row.get("name", id)), "tags": tags, "current": current, "detail": detail,
			"warn": bool(row.get("warn", false))}
		if row.get("thumbnail") != null and str(row.get("thumbnail")) != "":
			item["thumbnail"] = row["thumbnail"]
		out.append(item)
	return out


## A row was picked: change it solo, or ask the server.
func _chosen(id: StringName) -> void:
	var l := _link()
	if _connected(l):
		_ask(l, String(id))
		return
	if not change_fn.is_valid():
		_say("This game cannot change the map.")
		return
	var res: Variant = await change_fn.call(id)
	var result: DotResult = res if res is DotResult else DotResult.success(id)
	changed.emit(id, result)
	if result.ok:
		DotLog.info(CHANNEL, "map changed from the menu", {"map": String(id)})
	else:
		_say(result.error.message)


func _ask(l: Object, id: String) -> void:
	_bind(l)
	_waiting_since_msec = Time.get_ticks_msec()
	l.call(&"send_chat", "%s%s%s" % [command_prefix, COMMAND, (" " + id) if id != "" else ""])
	if menu != null and menu.is_inside_tree() and answer_timeout_sec > 0.0:
		var asked := _waiting_since_msec
		menu.get_tree().create_timer(answer_timeout_sec).timeout.connect(func() -> void:
			if _waiting_since_msec == asked:
				_waiting_since_msec = -1
				_say("The server did not answer. Type !rtv to vote for another map."))


func _bind(l: Object) -> void:
	if l == _bound_link or not l.has_signal(&"notice_received"):
		return
	if _bound_link != null and is_instance_valid(_bound_link) and _bound_link.is_connected(&"notice_received", _on_notice):
		_bound_link.disconnect(&"notice_received", _on_notice)
	l.connect(&"notice_received", _on_notice)
	_bound_link = l


## A notice from the server. Only the `map_menu` topic is this file's.
func _on_notice(notice: Object) -> void:
	if notice == null or StringName(str(notice.get("topic"))) != TOPIC:
		return
	var data: Variant = notice.get("data")
	if data is Dictionary:
		receive(data as Dictionary)


## The server's answer, as the notice's data. Public for a game with its own wire and for the
## suite: `{maps: [...], allowed, flag, vote, where}` opens the picker, put back together first
## when it came in `part`s of `parts`; `{result: {ok, text}}` is the outcome of a choice.
func receive(data: Dictionary) -> void:
	if data.has("maps") and int(data.get("parts", 1)) > 1:
		var parts := int(data["parts"])
		if int(data.get("part", 1)) == 1:
			_parts.clear()
		_parts[int(data.get("part", 1))] = data["maps"] if data["maps"] is Array else []
		if _parts.size() < parts:
			return
		var whole: Array = []
		for i in range(1, parts + 1):
			whole.append_array(_parts.get(i, []))
		_parts.clear()
		data = data.duplicate()
		data["maps"] = whole
	_waiting_since_msec = -1
	if data.has("maps"):
		last_offer = data.duplicate(true)
		var allowed := bool(data.get("allowed", false))
		var vote := bool(data.get("vote", false))
		var flag := str(data.get("flag", ""))
		if not allowed and not vote:
			_say("Changing the map here needs the '%s' permission, and voting is off." % flag)
			return
		var rows: Array = data["maps"] if data["maps"] is Array else []
		if rows.is_empty():
			_say("The server has no other map to offer.")
			return
		open_rows(rows, allowed, str(data.get("where", "this server")), flag, vote)
	elif data.get("result") is Dictionary:
		_say(str((data["result"] as Dictionary).get("text", "")))


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


## Connected to a server: the server is asked. Anything else is solo.
static func _connected(l: Object) -> bool:
	if l == null or not is_instance_valid(l) or not l.has_method(&"send_chat"):
		return false
	return not l.has_method(&"is_connected_to_server") or bool(l.call(&"is_connected_to_server"))


func is_online() -> bool:
	return _connected(_link())


func describe() -> Dictionary:
	return {
		"enabled": enabled, "solo_rows": rows_fn.is_valid(), "solo_change": change_fn.is_valid(),
		"online": is_online(), "direct": direct, "last_said": last_said,
		"offer": {"allowed": last_offer.get("allowed", null), "flag": last_offer.get("flag", ""),
			"maps": (last_offer.get("maps", []) as Array).size() if last_offer.get("maps") is Array else 0},
	}
