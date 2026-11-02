class_name DotMenuStats
extends Node

## Puts a game's per-player statistics on its Tab board: one lifetime column per stat the server lists in the snapshot's `stat_columns` (dot-game's `DotGameStatsBoard` builds them), the optional ones hidden until the player turns them on.
## Child of a [DotMenuScoreboard]; it follows the snapshot, so a game that replaces `board.columns` afterwards keeps the stat columns. [member enabled] is what the `cl_stats_ui` cvar sets.


## Row field prefixes: this session's figure, and the lifetime total. Text, already formatted by the server.
const SESSION := "st_"
const LIFETIME := "lt_"
const COLUMNS_KEY := "stat_columns"

var board: DotMenuScoreboard = null

## Off removes the columns and hides the panel.
var enabled: bool = true:
	set(v):
		enabled = v
		_sync()

var _signature := ""
var _keys: Array[StringName] = []
var _seen: Dictionary = {}


## Adds a [DotMenuStats] under [param on] and returns it.
static func install(on: DotMenuScoreboard) -> DotMenuStats:
	var existing := on.get_node_or_null("Stats") as DotMenuStats
	if existing != null:
		return existing
	var made := DotMenuStats.new()
	made.name = "Stats"
	made.board = on
	on.add_child(made)
	return made


func _process(_delta: float) -> void:
	if board != null and board.visible and (not is_same(board.snapshot, _seen) or not _intact()):
		# By name: the rebuild runs only on a change, not every frame.
		call_deferred(&"_sync")


## Brings the board's columns in line with the latest snapshot.
func _sync() -> void:
	if board == null:
		return
	_seen = board.snapshot
	var listed: Array = [] if not enabled else board.snapshot.get(COLUMNS_KEY, [])
	var signature := str(listed)
	if signature == _signature and _intact():
		return
	for key in _keys:
		var _removed := board.remove_column(key)
	_keys.clear()
	_signature = signature
	for entry: Variant in listed:
		if not (entry is Dictionary) or str((entry as Dictionary).get("column", "")) == "hidden":
			continue
		var key := StringName(LIFETIME + str((entry as Dictionary).get("key", "")))
		board.add_column({
			"key": key, "title": str((entry as Dictionary).get("title", key)),
			"kind": DotMenuScoreboard.KIND_TEXT,
			"hidden": str((entry as Dictionary).get("column", "")) != "default",
		}, &"ping")
		_keys.append(key)
	if board.visible:
		board.redraw()


func _intact() -> bool:
	for key in _keys:
		if not _has_column(key):
			return false
	return true


func _has_column(key: StringName) -> bool:
	for column in board.columns:
		if column.get("key") == key:
			return true
	return false
