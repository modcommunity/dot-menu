class_name DotMenuStatsPanel
extends Control

## The local player's statistics as a card: each stat's figure this session and the lifetime total, themed by the kit. Reads the same Tab-board snapshot [DotMenuStats] does (`stat_columns` plus the player's own row), so it needs no stats API of its own.
## [method show_for] opens it for a few seconds (an end-of-round screen); [method toggle] is for a key. It never takes the mouse or keyboard.

const CHANNEL := "menu.stats_panel"

var kit: DotMenuKit = null

## Heading over the table.
var title_text: String = "Your stats"

## Anything with `want_scoreboard(open)` and a `scoreboard_received` signal: the client link. Snapshots only arrive while someone asks.
var feed: Object = null

## Off keeps the card hidden whatever asks (the `cl_stats_ui` cvar).
var enabled: bool = true:
	set(v):
		enabled = v
		if not v:
			close()

var snapshot: Dictionary = {}

var _card: PanelContainer = null
var _until := 0.0


func _ready() -> void:
	if kit == null:
		kit = DotMenuKit.new()
	DotMenuKit.fill_parent(self)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	theme = kit.theme()


## Follows [param link]'s scoreboard snapshots.
func feed_from(link: Object) -> void:
	if feed != null and feed.has_signal(&"scoreboard_received") and feed.is_connected(&"scoreboard_received", show_snapshot):
		feed.disconnect(&"scoreboard_received", show_snapshot)
	feed = link
	if link != null and link.has_signal(&"scoreboard_received"):
		link.connect(&"scoreboard_received", show_snapshot)


func show_snapshot(snap: Dictionary) -> void:
	snapshot = snap
	if visible:
		redraw()


## Opens the card for [param seconds]; 0 keeps it until [method close].
func show_for(seconds: float = 8.0) -> void:
	if not enabled:
		return
	_until = Time.get_ticks_msec() / 1000.0 + seconds if seconds > 0.0 else 0.0
	_ask(true)
	visible = true
	redraw()


func toggle() -> void:
	if visible:
		close()
	else:
		show_for(0.0)


func close() -> void:
	if visible:
		_ask(false)
	visible = false


func _process(_delta: float) -> void:
	if visible and _until > 0.0 and Time.get_ticks_msec() / 1000.0 >= _until:
		close()


func _ask(on: bool) -> void:
	if feed != null and feed.has_method(&"want_scoreboard"):
		var _asked: Variant = feed.call(&"want_scoreboard", on)


## The local player's row of [member snapshot], or empty.
func my_row() -> Dictionary:
	var you := int(snapshot.get("you", 0))
	for row: Variant in snapshot.get("players", []):
		if row is Dictionary and int((row as Dictionary).get("id", -1)) == you:
			return row
	return {}


func redraw() -> void:
	if _card != null:
		_card.queue_free()
		_card = null
	var row := my_row()
	var listed: Array = snapshot.get(DotMenuStats.COLUMNS_KEY, [])
	var p := kit.palette
	_card = PanelContainer.new()
	_card.name = "Card"
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var s := kit.surface_box()
	s.bg_color = Color(p.surface, 0.92)
	s.content_margin_left = 24
	s.content_margin_right = 24
	s.content_margin_top = 18
	s.content_margin_bottom = 18
	_card.add_theme_stylebox_override(&"panel", s)
	var centre := CenterContainer.new()
	DotMenuKit.fill_parent(centre)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	centre.add_child(_card)
	_card.add_child(_body(row, listed))
	add_child(centre)


func _body(row: Dictionary, listed: Array) -> Control:
	var p := kit.palette
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override(&"separation", 6)
	var name := str(row.get("name", ""))
	var heading := kit.label(title_text if name == "" else "%s: %s" % [title_text, name], kit.size_title - 2, p.text, true)
	heading.name = "Title"
	box.add_child(heading)
	if row.is_empty() or listed.is_empty():
		box.add_child(kit.label("No stats yet", kit.size_body, p.muted))
		return box
	var grid := GridContainer.new()
	grid.name = "Table"
	grid.columns = 3
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grid.add_theme_constant_override(&"h_separation", 28)
	grid.add_theme_constant_override(&"v_separation", 4)
	for head in ["", "This game", "Lifetime"]:
		var l := kit.label(head, kit.size_small, p.muted)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if head != "" else HORIZONTAL_ALIGNMENT_LEFT
		grid.add_child(l)
	for entry: Variant in listed:
		if not (entry is Dictionary) or str((entry as Dictionary).get("column", "")) == "hidden":
			continue
		var key := str((entry as Dictionary).get("key", ""))
		grid.add_child(kit.label(str((entry as Dictionary).get("title", key)), kit.size_body, p.text))
		for field in [DotMenuStats.SESSION, DotMenuStats.LIFETIME]:
			var v := kit.label(str(row.get(field + key, "-")), kit.size_body, p.accent if field == DotMenuStats.LIFETIME else p.text)
			v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			grid.add_child(v)
	box.add_child(grid)
	return box
