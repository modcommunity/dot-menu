class_name DotMenuScoreboard
extends Control

## The scoreboard a player holds Tab for: the server, the teams, and a row per player with
## their name, score, time connected and ping, plus whatever columns the game adds.
##
## [codeblock]
## var board := menu.scoreboard                      # DotMenu builds one; Tab holds it open
## board.columns = DotMenuScoreboard.default_columns()
## board.add_column({"key": &"kills", "title": "K"}, &"score")   # before Score
## board.feed_from(link)                             # the server's roster, while held
## # or, offline / for a game's own numbers:
## board.source = func() -> Dictionary: return {"server": {...}, "players": [...]}
## board.decorate = func(row): row["avatar"] = faces.get(row["id"])
## [/codeblock]
##
## [b]A snapshot in, a picture out.[/b] Everything it draws is one dictionary, the shape
## dot-server's `scoreboard_snapshot` sends:
## [codeblock]
## {"server": {"name", "game", "map", "players", "max"}, "you": <id>,
##  "players": [{"id", "name", "score", "ping", "seconds", "bot", "team", ...}],
##  "teams": [{"id", "name", "color", "score"}], "header": {"Time left": "4:12", ...}}
## [/codeblock]
## so the server's numbers (which only the server has for everybody), a game's own numbers
## and an offline game's local ones are drawn by the same code. dot-menu does not depend on
## dot-server: [method feed_from] takes anything with `want_scoreboard(open)` and a
## `scoreboard_received` signal.
##
## [b]Customising it, from a column to the whole thing.[/b] [member columns] are data —
## `{key, title, kind, width, align, format, build}` — and a `kind` is text, number, ping,
## duration, avatar or custom. [member decorate] edits each row before it is drawn (a face
## from a client-side cache, a colour). [member group_by] and [member sort_by] decide teams
## and order. And [member build_header], [member build_team_header] and [member build_row]
## replace the default pieces outright, each given the kit, so a game whose board looks
## nothing like this one still gets the feed, the hold key and the theme.
##
## [b]Held, not opened.[/b] It never takes the mouse or the keyboard and never stops the
## player moving — a scoreboard is glanced at mid-round — so it is not one of [DotMenu]'s
## overlays: it does not free the pointer or suspend a sampler, and Escape still opens the
## menu over it.

const CHANNEL := "menu.scoreboard"

signal opened()
signal closed()

## How a column's value is drawn.
const KIND_TEXT := &"text"
const KIND_NUMBER := &"number"
## Milliseconds, coloured by how bad they are; -1 is "-".
const KIND_PING := &"ping"
## Seconds, as 4:05 or 1:02:09.
const KIND_DURATION := &"duration"
## A Texture2D in the row; nothing when there is none.
const KIND_AVATAR := &"avatar"
## `build: func(kit, row) -> Control`.
const KIND_CUSTOM := &"custom"

## Inside a row, each side: room for the highlight's outline, which a number set flush
## right otherwise touches.
const ROW_PAD := 8

var kit: DotMenuKit = null

var columns: Array[Dictionary] = default_columns()

## `func() -> Dictionary`: a snapshot to draw, asked for on open and every
## [member refresh_sec]. Wins over a feed when set — for offline play, or a game whose board
## is entirely its own numbers.
var source: Callable = Callable()

## `func(row: Dictionary) -> void`: edits each row before it is drawn.
var decorate: Callable = Callable()

## The row field rows are grouped into teams by. Empty draws one list.
var group_by: StringName = &"team"

## The row field rows are ordered by, highest first, then by name.
var sort_by: StringName = &"score"

## `func(a: Dictionary, b: Dictionary) -> bool`, when one field is not enough.
var sort_with: Callable = Callable()

## Overrides, each given the kit: `func(kit, snapshot) -> Control`,
## `func(kit, team: Dictionary, rows: Array) -> Control`, `func(kit, row, columns) -> Control`.
var build_header: Callable = Callable()
var build_team_header: Callable = Callable()
var build_row: Callable = Callable()

## Used when the snapshot names no server: the game, offline.
var title_text: String = "Scoreboard"

## Two teams side by side, as the team shooters draw them, when there is room. Off stacks
## them.
var side_by_side: bool = true

## Seconds between redraws while it is held.
var refresh_sec: float = 0.5

## The words under the rows for players on no team when there are teams.
var spectators_title: String = "Spectating"

var snapshot: Dictionary = {}

var _feed: Object = null
var _window: PanelContainer = null
var _body: VBoxContainer = null
var _since := 0.0
var _built := false


## Avatar, name, score, time connected and ping. What every game starts from.
static func default_columns() -> Array[Dictionary]:
	return [
		{"key": &"avatar", "kind": KIND_AVATAR, "width": 0.0},
		{"key": &"name", "title": "Player", "width": 3.0},
		{"key": &"score", "title": "Score", "kind": KIND_NUMBER},
		{"key": &"seconds", "title": "Time", "kind": KIND_DURATION},
		{"key": &"ping", "title": "Ping", "kind": KIND_PING},
	]


func _ready() -> void:
	if kit == null:
		kit = DotMenuKit.new()
	DotMenuKit.fill_parent(self)
	# Held over a live game: it must never take a click or a key.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_build()


func restyle(new_kit: DotMenuKit) -> void:
	kit = new_kit
	if not _built:
		return
	DotMenuKit.clear(self)
	_build()
	if visible:
		redraw()


func _build() -> void:
	theme = kit.theme()
	var centre := CenterContainer.new()
	DotMenuKit.fill_parent(centre)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(centre)

	_window = PanelContainer.new()
	_window.name = "Window"
	_window.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var s := kit.surface_box()
	s.bg_color = Color(kit.palette.surface, 0.9)
	s.content_margin_left = 26
	s.content_margin_right = 26
	s.content_margin_top = 20
	s.content_margin_bottom = 20
	_window.add_theme_stylebox_override(&"panel", s)
	centre.add_child(_window)

	_body = VBoxContainer.new()
	_body.name = "Body"
	_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_body.add_theme_constant_override(&"separation", 12)
	_window.add_child(_body)
	_built = true
	_fit()
	if not get_viewport().size_changed.is_connected(_fit):
		get_viewport().size_changed.connect(_fit)


func _fit() -> void:
	if _window == null:
		return
	var view := get_viewport_rect().size
	_window.custom_minimum_size = Vector2(clampf(view.x - 80.0, 360.0, 1080.0), 0)


# --- Columns ----------------------------------------------------------------------

## Adds [param column] before the column keyed [param before], or at the end. A column with
## the same key is replaced in place.
func add_column(column: Dictionary, before: StringName = &"") -> void:
	for i in range(columns.size()):
		if columns[i].get("key") == column.get("key"):
			columns[i] = column
			return
	for i in range(columns.size()):
		if columns[i].get("key") == before:
			columns.insert(i, column)
			return
	columns.append(column)


func remove_column(key: StringName) -> bool:
	for i in range(columns.size()):
		if columns[i].get("key") == key:
			columns.remove_at(i)
			return true
	return false


# --- The feed ---------------------------------------------------------------------

## Draws the server's roster: [param link] is told when the board opens and closes and its
## `scoreboard_received` is drawn. dot-server's `DotClientLink`, or anything shaped like it.
func feed_from(link: Object) -> void:
	if _feed != null and _feed.has_signal(&"scoreboard_received") \
			and _feed.is_connected(&"scoreboard_received", show_snapshot):
		_feed.disconnect(&"scoreboard_received", show_snapshot)
	_feed = link
	if link != null and link.has_signal(&"scoreboard_received"):
		link.connect(&"scoreboard_received", show_snapshot)


## Draws [param snap] now, if held; otherwise keeps it for the next hold.
func show_snapshot(snap: Dictionary) -> void:
	if source.is_valid():
		return
	snapshot = snap
	if visible:
		redraw()


func open() -> void:
	if visible:
		return
	visible = true
	if _feed != null and _feed.has_method(&"want_scoreboard"):
		var _asked: Variant = _feed.call(&"want_scoreboard", true)
		var last: Variant = _feed.get(&"scoreboard")
		if last is Dictionary and not (last as Dictionary).is_empty() and not source.is_valid():
			snapshot = last
	_pull()
	redraw()
	opened.emit()


func close() -> void:
	if not visible:
		return
	visible = false
	if _feed != null and _feed.has_method(&"want_scoreboard"):
		var _told: Variant = _feed.call(&"want_scoreboard", false)
	closed.emit()


func is_open() -> bool:
	return visible


func _process(delta: float) -> void:
	if not visible or not source.is_valid():
		return
	_since += delta
	if _since >= refresh_sec:
		_since = 0.0
		_pull()
		redraw()


func _pull() -> void:
	if source.is_valid():
		var snap: Variant = source.call()
		if snap is Dictionary:
			snapshot = snap


# --- Drawing ----------------------------------------------------------------------

## The rows, decorated and sorted, as they will be drawn. Public so a suite can read them.
func rows() -> Array:
	var out: Array = []
	var you: Variant = snapshot.get("you", null)
	for raw in (snapshot.get("players", []) as Array):
		if not (raw is Dictionary):
			continue
		var row := (raw as Dictionary).duplicate()
		if not row.has("you"):
			row["you"] = you != null and str(row.get("id", "")) == str(you)
		if decorate.is_valid():
			decorate.call(row)
		out.append(row)
	out.sort_custom(_before)
	return out


func _before(a: Dictionary, b: Dictionary) -> bool:
	if sort_with.is_valid():
		return bool(sort_with.call(a, b))
	var sa: Variant = a.get(sort_by, 0)
	var sb: Variant = b.get(sort_by, 0)
	if (sa is int or sa is float) and (sb is int or sb is float) and float(sa) != float(sb):
		return float(sa) > float(sb)
	return str(a.get("name", "")).naturalnocasecmp_to(str(b.get("name", ""))) < 0


func teams() -> Array:
	var out: Array = []
	for t in (snapshot.get("teams", []) as Array):
		if t is Dictionary:
			out.append(t)
	return out


func redraw() -> void:
	if not _built:
		return
	DotMenuKit.clear(_body)

	var header: Control = build_header.call(kit, snapshot) if build_header.is_valid() else _header()
	if header != null:
		_body.add_child(header)

	var all := rows()
	var team_list := teams()
	if team_list.is_empty() or group_by == &"":
		_body.add_child(_team_block({}, all))
		return

	var placed: Array[bool] = []
	placed.resize(all.size())
	var blocks: Array[Control] = []
	for t in team_list:
		var members: Array = []
		for i in range(all.size()):
			if str(all[i].get(group_by, "")) == str(t.get("id", "")):
				members.append(all[i])
				placed[i] = true
		blocks.append(_team_block(t, members))

	if side_by_side and blocks.size() == 2:
		var pair := HBoxContainer.new()
		pair.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pair.add_theme_constant_override(&"separation", 18)
		for b in blocks:
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			pair.add_child(b)
		_body.add_child(pair)
	else:
		for b in blocks:
			_body.add_child(b)

	var rest: Array = []
	for i in range(all.size()):
		if not placed[i]:
			rest.append(all[i])
	if not rest.is_empty():
		var names := PackedStringArray()
		for r in rest:
			names.append(str(r.get("name", "?")))
		var line := kit.paragraph("%s:  %s" % [spectators_title, ", ".join(names)], kit.size_small, kit.palette.dim)
		line.name = "Spectators"
		_body.add_child(line)


func _header() -> Control:
	var p := kit.palette
	var server: Dictionary = snapshot.get("server", {})
	var col := VBoxContainer.new()
	col.name = "Header"
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override(&"separation", 2)

	var line := HBoxContainer.new()
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var name := str(server.get("name", "")) if str(server.get("name", "")) != "" else title_text
	var title := kit.label(name, kit.size_title - 2, p.text, true)
	title.name = "ServerName"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title.clip_text = true
	line.add_child(title)
	if server.has("players"):
		var count := "%d / %d" % [int(server.get("players", 0)), int(server.get("max", 0))] if int(server.get("max", 0)) > 0 \
			else str(int(server.get("players", 0)))
		line.add_child(kit.label(count + " players", kit.size_small, p.muted))
	col.add_child(line)

	var facts := PackedStringArray()
	for key in ["game", "map"]:
		if str(server.get(key, "")) != "":
			facts.append(str(server[key]))
	var extra: Variant = snapshot.get("header", {})
	if extra is Dictionary:
		for k in (extra as Dictionary):
			facts.append("%s %s" % [str(k), str((extra as Dictionary)[k])])
	if not facts.is_empty():
		var sub := kit.label("  ·  ".join(facts), kit.size_small, p.accent)
		sub.name = "Facts"
		col.add_child(sub)
	return col


func _team_block(team: Dictionary, members: Array) -> Control:
	var block := VBoxContainer.new()
	block.mouse_filter = Control.MOUSE_FILTER_IGNORE
	block.add_theme_constant_override(&"separation", 4)
	block.name = "Team_%s" % str(team.get("id", "all")) if not team.is_empty() else "Players"

	if not team.is_empty():
		var head: Control = build_team_header.call(kit, team, members) if build_team_header.is_valid() \
			else _team_header(team, members)
		if head != null:
			block.add_child(head)

	block.add_child(_column_titles())
	var card := kit.card()
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var list := VBoxContainer.new()
	list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	list.add_theme_constant_override(&"separation", 0)
	card.add_child(list)
	block.add_child(card)
	if members.is_empty():
		list.add_child(kit.paragraph("Nobody yet.", kit.size_small, kit.palette.dim))
	for r in members:
		var drawn: Control = build_row.call(kit, r, columns) if build_row.is_valid() else _row(r)
		if drawn != null:
			list.add_child(drawn)
	return block


func _team_header(team: Dictionary, members: Array) -> Control:
	var p := kit.palette
	var colour: Variant = DotMenuPalette.parse_color(team.get("color", null))
	var tint: Color = colour if colour is Color else p.accent
	var line := HBoxContainer.new()
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_theme_constant_override(&"separation", 10)
	var bar := ColorRect.new()
	bar.color = tint
	bar.custom_minimum_size = Vector2(4, 28)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_child(bar)
	var name := kit.label(str(team.get("name", "Team")), kit.size_heading, tint, true)
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(name)
	line.add_child(kit.label("%d players" % members.size(), kit.size_small, p.muted))
	if team.has("score"):
		line.add_child(kit.label(str(team["score"]), kit.size_title - 4, p.text, true))
	return line


func _column_titles() -> Control:
	var line := HBoxContainer.new()
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_theme_constant_override(&"separation", 12)
	var pad := MarginContainer.new()
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# The card's own margin plus a row's, so a title sits over its column's numbers.
	pad.add_theme_constant_override(&"margin_left", 18 + ROW_PAD)
	pad.add_theme_constant_override(&"margin_right", 18 + ROW_PAD)
	pad.add_child(line)
	for c in columns:
		var l := kit.label(str(c.get("title", "")), kit.size_small - 1, kit.palette.dim, true)
		_size_cell(l, c)
		line.add_child(l)
	return pad


func _row(row: Dictionary) -> Control:
	var p := kit.palette
	var you := bool(row.get("you", false))
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var none := Color(0, 0, 0, 0)
	panel.add_theme_stylebox_override(&"panel",
		kit.box(p.accent_wash() if you else none, kit.radius_small, p.accent if you else none, 1 if you else 0, Vector4(ROW_PAD, 5, ROW_PAD, 5)))
	var line := HBoxContainer.new()
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_theme_constant_override(&"separation", 12)
	panel.add_child(line)
	for c in columns:
		var cell := _cell(c, row)
		_size_cell(cell, c)
		line.add_child(cell)
	return panel


func _size_cell(cell: Control, column: Dictionary) -> void:
	cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var w := float(column.get("width", 1.0))
	if w <= 0.0:
		cell.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		if cell.custom_minimum_size.x < 28.0:
			cell.custom_minimum_size.x = 28.0
		return
	cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cell.size_flags_stretch_ratio = w
	if cell is Label:
		var kind := StringName(str(column.get("kind", KIND_TEXT)))
		var right := kind == KIND_NUMBER or kind == KIND_PING or kind == KIND_DURATION
		(cell as Label).horizontal_alignment = int(column.get("align",
			HORIZONTAL_ALIGNMENT_RIGHT if right else HORIZONTAL_ALIGNMENT_LEFT))
		(cell as Label).clip_text = true
		(cell as Label).text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS


func _cell(column: Dictionary, row: Dictionary) -> Control:
	var p := kit.palette
	var key: StringName = column.get("key", &"")
	var kind := StringName(str(column.get("kind", KIND_TEXT)))
	var value: Variant = row.get(key, row.get(String(key), null))

	match kind:
		KIND_CUSTOM:
			var built: Variant = (column["build"] as Callable).call(kit, row) if column.get("build") is Callable else null
			return built if built is Control else Control.new()
		KIND_AVATAR:
			var holder := Control.new()
			holder.custom_minimum_size = Vector2(28, 28)
			if value is Texture2D:
				var pic := TextureRect.new()
				pic.texture = value
				pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				pic.custom_minimum_size = Vector2(28, 28)
				DotMenuKit.fill_parent(pic)
				holder.add_child(pic)
			return holder

	var text := format_value(column, value, row)
	var colour := p.text
	if kind == KIND_PING:
		colour = ping_colour(int(value) if value != null else -1)
	elif key == &"name" and bool(row.get("you", false)):
		colour = p.accent
	var l := kit.label(text, kit.size_body, colour, key == &"name")
	if key == &"name" and bool(row.get("bot", false)):
		l.text += "  BOT"
	return l


## The words a column shows for [param value]: its `format` Callable, or its kind's.
func format_value(column: Dictionary, value: Variant, row: Dictionary = {}) -> String:
	if column.get("format") is Callable:
		return str((column["format"] as Callable).call(value, row))
	match StringName(str(column.get("kind", KIND_TEXT))):
		KIND_PING:
			return "-" if value == null or int(value) < 0 else "%d" % int(value)
		KIND_DURATION:
			return duration(int(value) if value != null else -1)
		KIND_NUMBER:
			if value == null:
				return "-"
			return "%d" % int(value) if is_equal_approx(float(value), roundf(float(value))) else "%.1f" % float(value)
	return "" if value == null else str(value)


## 245 as "4:05", 3729 as "1:02:09", a negative as "-".
static func duration(seconds: int) -> String:
	if seconds < 0:
		return "-"
	var h := seconds / 3600
	var m := (seconds % 3600) / 60
	var s := seconds % 60
	return "%d:%02d:%02d" % [h, m, s] if h > 0 else "%d:%02d" % [m, s]


## Good, fine, poor, bad: the HUD's ahead colour, the text, the warning, the danger.
func ping_colour(ms: int) -> Color:
	var p := kit.palette
	if ms < 0:
		return p.dim
	if ms < 60:
		return p.hud_ahead
	if ms < 120:
		return p.text
	if ms < 200:
		return p.warn
	return p.danger


func describe() -> Dictionary:
	return {
		"open": visible, "columns": columns.size(), "rows": (snapshot.get("players", []) as Array).size(),
		"teams": teams().size(), "fed": _feed != null, "source": source.is_valid(),
	}
