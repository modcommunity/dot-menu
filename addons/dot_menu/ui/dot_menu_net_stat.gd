class_name DotMenuNetStat
extends Control

## `net_stat`: what the connection is doing, drawn over the game in a corner.
##
## [codeblock]
## net_stat 1    # numbers: frame rate, ping and jitter, in and out, loss
## net_stat 2    # and a graph of what arrives, by channel, with ping drawn across it
## net_stat 3    # and what leaves, where each frame went, prediction, the server's frame
## net_stat 0    # off
## [/codeblock]
##
## [DotMenu] builds one and drives it from three settings — `net_stat`, `net_stat_height`
## and `net_stat_position` — so the console command and the Advanced page are one value.
##
## [b]Where the numbers come from.[/b] [method sample_source] returns a [DotMeteredPeer]:
## by default the one this node's own [member Node.multiplayer] runs through, which is the
## client link's (dot-server wraps its peer in one). Nothing here names dot-server; a
## game with its own link assigns [member source]. With no meter the panel still shows
## the frame, and says it is not connected rather than drawing a flat line that looks like
## a connection carrying nothing.
##
## [b]Rates are drawn as rates.[/b] A bar is one [member bucket_sec] of arrivals, scaled to
## bytes a second, so the scale label means the same thing at every bucket length and
## matches the "in" figure under it. A bar per FRAME (which is what the classic graphs
## draw) changes width with the frame rate: the same connection is a different picture at
## 60 and at 240 fps.
##
## [b]A browser's arrivals have no channels.[/b] Godot's WebSocket peer is one stream and
## reports every packet on channel 0 (dot-core's dual_transport_selftest pins that down), so
## over WebSocket the incoming bars are one colour and the legend says why. What a client
## SENDS is split on both, because the channel is known at the send.
##
## [b]Frame times are wall-clock times.[/b] [DotMenuFrameClock] reads the clock at four
## points of every engine iteration, so the frame strip shows what the player waited and
## where it went (physics, script, render, and the wait for the next frame), and fps is the
## frames actually drawn in the last second. The process delta it used before is smoothed
## and clamped, and drew a steadier game than the one being played.
##
## [b]Prediction, read duck-typed.[/b] Where a client's dot-net manager is published in
## [DotRegistry] (as [code]dot_net_manager[/code], any scope), the FULL level shows what its
## [code]perf_counters()[/code] say the last second cost: snapshots applied, ticks
## re-simulated, and the lead those replays run over. Nothing here names dot-net.
##
## [b]One draw call, no child nodes, redrawn when a bar closes.[/b] Everything drawn changes
## once a bucket, so redrawing every frame was twenty times the canvas work for the same
## picture — on a browser client, a measurable part of the frame it was measuring.

enum Level { OFF = 0, NUMBERS = 1, GRAPH = 2, FULL = 3 }

## The first is the default: the corner the frame counter uses, which net_stat replaces
## while it is up — and the one game HUDs here leave free (their round state is along the
## top centre and the bottom, their chat bottom left).
const POSITIONS: Array[StringName] = [&"top_right", &"bottom_right", &"top_left", &"bottom_left"]

const MIN_HEIGHT := 32
const MAX_HEIGHT := 320

## What is shown. See the class note.
var level: int = Level.OFF:
	set(v):
		var was := level
		level = clampi(v, Level.OFF, Level.FULL)
		visible = level != Level.OFF
		if was == Level.OFF and level != Level.OFF:
			reset()
		_sync_clock()
		_relayout()

## The height of the arrivals graph, in pixels.
var graph_height: int = 96:
	set(v):
		graph_height = clampi(v, MIN_HEIGHT, MAX_HEIGHT)
		_relayout()

## Which corner. One of [constant POSITIONS]; anything else is the first.
var corner: StringName = &"top_right":
	set(v):
		corner = v if POSITIONS.has(v) else POSITIONS[0]
		_relayout()

## The panel's width in pixels. The graph holds as many bars as fit.
var panel_width: float = 392.0:
	set(v):
		panel_width = maxf(240.0, v)
		_relayout()

## Distance from the corner's two edges. Top corners leave room for the frame counter's
## row and a HUD's status line.
var margin := Vector2(14.0, 14.0)

## Seconds each bar covers.
var bucket_sec: float = 0.05

## `func() -> Object`: the meter to read. Unset is this node's own multiplayer peer when it
## is a [DotMeteredPeer].
var source: Callable = Callable()

## What each channel is called and drawn in. The family's four (dot-core's
## [enum DotTransport.Channel]): channel 2 also carries the games' voice.
var channel_names := PackedStringArray(["control", "state", "events · voice", "content"])

var kit: DotMenuKit = null

## Blue, green, amber, violet: apart from each other, and from the HUD's own ahead/behind
## green and red, on every stock theme's plate.
static var STOCK_CHANNEL_COLOURS: Array[Color] = [
	Color("#6ea8fe"), Color("#5fd38d"), Color("#f2b45a"), Color("#c58af9"),
]

## The column left of the graphs that holds their names and scales.
const GUTTER := 50.0

const BAR_W := 3.0
const BAR_GAP := 1.0
const PAD := 10.0
const STRIP_H := 30.0
const GAP := 6.0

## Per bucket: {"in": PackedInt64Array per channel, "out": PackedInt64Array per channel,
## "pin": packets, "pout": packets, "frame_ms": the slowest frame in it, "rtt": ms or -1}.
var _buckets: Array[Dictionary] = []
var _capacity := 96
var _meter: Object = null
var _base_in := PackedInt64Array()
var _base_out := PackedInt64Array()
var _base_pin := 0
var _base_pout := 0
var _in_scale := 2048.0
var _out_scale := 1024.0
var _rtt_scale := 100.0

## Wall-clock frame timing; runs only while the panel is shown.
var frames := DotMenuFrameClock.new()

## `func() -> Object`: the client's dot-net manager, or null. Unset looks one up in
## [DotRegistry]; see the class note.
var net_source: Callable = Callable()

## When the open bucket closes, in microseconds.
var _bucket_due := 0
## The slowest frame of the open bucket, as [wall, physics, script, render] microseconds.
var _bucket_worst := PackedInt32Array([0, 0, 0, 0])
## [usec, perf_counters()] per bucket, to difference over the last second.
var _net_marks: Array = []
var _plate: StyleBoxFlat = null

# The figures under the graph, recomputed once per bucket rather than once per frame,
# so the text holds still long enough to be read.
var _fig := {}


func _init() -> void:
	name = "NetStat"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	frames.on_frame = _on_frame


func _ready() -> void:
	_relayout()
	_sync_clock()


func _exit_tree() -> void:
	frames.stop()


func _enter_tree() -> void:
	_sync_clock()


## The frame clock runs while there is something to show it on.
func _sync_clock() -> void:
	if level != Level.OFF and is_inside_tree():
		frames.start(get_tree())
	else:
		frames.stop()


func _on_frame(wall_us: int, physics_us: int, script_us: int, render_us: int, _steps: int) -> void:
	if wall_us > _bucket_worst[0]:
		_bucket_worst = PackedInt32Array([wall_us, physics_us, script_us, render_us])


## The overlay on a layer of its own under [param host], following the three `net_stat*`
## settings of [param settings] — for a game with its own settings and no [DotMenu] (which
## builds and drives one itself). Declare the settings with
## [method DotMenuStock.declare_net_stat] first. Layer 120 by default: over a HUD and the
## menu (110), under the console (128) — a diagnostic is read over everything but the line
## that set it.
static func follow(host: Node, settings: DotSettingsManager, layer: int = 120, p_kit: DotMenuKit = null) -> DotMenuNetStat:
	var canvas := CanvasLayer.new()
	canvas.name = "NetStatLayer"
	canvas.layer = layer
	host.add_child(canvas)
	var overlay := DotMenuNetStat.new()
	overlay.kit = p_kit if p_kit != null else DotMenuKit.new(DotMenuPalette.new())
	canvas.add_child(overlay)
	var _level := overlay.read_settings(settings)
	if settings != null:
		overlay._followed = settings
		# A method, not a lambda capturing the overlay: a host may free the overlay before
		# its settings, and an engine-owned connection to a method goes with the object,
		# where a lambda's capture is left pointing at nothing and errors on the next change.
		settings.changed.connect(overlay._on_followed_changed)
	return overlay


var _followed: DotSettingsManager = null


func _on_followed_changed(key: StringName, _value: Variant, _why: StringName) -> void:
	if String(key).begins_with("net_stat"):
		var _l := read_settings(_followed)


## Takes level, height and corner from [param settings], each only where its schema
## declares it. Returns the level. The one place the three settings are read, for
## [DotMenu] and [method follow] alike.
func read_settings(settings: DotSettingsManager) -> int:
	if settings == null or settings.schema == null or not settings.schema.has(&"net_stat"):
		level = Level.OFF
		return level
	if settings.schema.has(&"net_stat_height"):
		graph_height = settings.get_int(&"net_stat_height", graph_height)
	if settings.schema.has(&"net_stat_position"):
		corner = StringName(settings.get_string(&"net_stat_position", String(corner)))
	level = settings.get_int(&"net_stat", 0)
	return level


## Forgets the history. The next bars start from now.
func reset() -> void:
	_buckets.clear()
	_meter = null
	_fig = {}
	_bucket_due = 0
	_bucket_worst = PackedInt32Array([0, 0, 0, 0])
	_net_marks.clear()
	frames.reset()


## The meter this panel reads now, or null.
func sample_source() -> Object:
	if source.is_valid():
		return source.call()
	if not is_inside_tree() or multiplayer == null:
		return null
	return DotMeteredPeer.of(multiplayer.multiplayer_peer)


## Redraws in [param p_kit]'s palette.
func restyle(p_kit: DotMenuKit) -> void:
	kit = p_kit
	_plate = null
	queue_redraw()


## The client's dot-net manager, or null: [member net_source], else the one published in
## [DotRegistry] under [code]dot_net_manager[/code] (any scope) that is not a server's.
func net_manager() -> Object:
	if net_source.is_valid():
		return net_source.call()
	for n in DotRegistry.names():
		if not n.begins_with("dot_net_manager"):
			continue
		var m := DotRegistry.get_service(StringName(n))
		if m != null and m.has_method(&"perf_counters") and not bool(m.get(&"is_server")):
			return m
	return null


# --- Sampling ------------------------------------------------------------------

func _process(_delta: float) -> void:
	if level == Level.OFF:
		return
	# On the wall clock, like the frames: the process delta is smoothed.
	var now := Time.get_ticks_usec()
	var period := int(bucket_sec * 1e6)
	if _bucket_due == 0:
		_bucket_due = now + period
	if now >= _bucket_due:
		# A long hitch closes one bucket, not a burst of empty ones: the frame strip shows
		# the hitch, and a run of zero-byte bars would read as the connection stalling.
		_bucket_due = _bucket_due + period if now < _bucket_due + period * 4 else now + period
		_push(sample_source())
		queue_redraw()


## Closes a bucket: what moved through [param m] since the last one.
func _push(m: Object) -> void:
	# The bucket's slowest frame, and where its time went. A frame still running when the
	# bucket closes is in the next one.
	var worst := _bucket_worst
	_bucket_worst = PackedInt32Array([0, 0, 0, 0])
	var b := {"in": PackedInt64Array(), "out": PackedInt64Array(), "pin": 0, "pout": 0,
		"frame_ms": float(worst[0]) / 1000.0, "parts": worst, "rtt": -1.0}

	if m != _meter:
		# A new connection (or the first): its totals are not arrivals since the last bar.
		_meter = m
		_rebase(m)
	elif m != null:
		var now_in: PackedInt64Array = m.get(&"bytes_in_by_channel")
		var now_out: PackedInt64Array = m.get(&"bytes_out_by_channel")
		b["in"] = _diff(now_in, _base_in)
		b["out"] = _diff(now_out, _base_out)
		b["pin"] = int(m.get(&"packets_in")) - _base_pin
		b["pout"] = int(m.get(&"packets_out")) - _base_pout
		b["rtt"] = float(m.call(&"rtt"))
		# Over WebSocket the ping is one heartbeat every couple of seconds, held between
		# them. Marking the buckets where it moved lets the line show where it was measured
		# instead of drawing a held number as if it were a reading every bucket.
		var prev := float(_buckets[_buckets.size() - 1].get("rtt", -1.0)) if not _buckets.is_empty() else -1.0
		b["fresh"] = float(b["rtt"]) >= 0.0 and not is_equal_approx(float(b["rtt"]), prev)
		_rebase(m)

	_buckets.append(b)
	while _buckets.size() > _capacity:
		_buckets.pop_front()
	_refigure(m)


func _rebase(m: Object) -> void:
	if m == null:
		return
	_base_in = (m.get(&"bytes_in_by_channel") as PackedInt64Array).duplicate()
	_base_out = (m.get(&"bytes_out_by_channel") as PackedInt64Array).duplicate()
	_base_pin = int(m.get(&"packets_in"))
	_base_pout = int(m.get(&"packets_out"))


static func _diff(now: PackedInt64Array, base: PackedInt64Array) -> PackedInt64Array:
	var out := PackedInt64Array()
	var _r := out.resize(now.size())
	for i in now.size():
		out[i] = maxi(0, now[i] - (base[i] if i < base.size() else 0))
	return out


static func _sum(a: Variant) -> int:
	var t := 0
	for v in a:
		t += int(v)
	return t


## The figures, over the last second of buckets, and the graph's scales.
func _refigure(m: Object) -> void:
	var window := mini(_buckets.size(), maxi(1, roundi(1.0 / bucket_sec)))
	var secs := float(window) * bucket_sec
	var bin := 0
	var bout := 0
	var pin := 0
	var pout := 0
	var frame_sum := 0.0
	for i in range(_buckets.size() - window, _buckets.size()):
		var b: Dictionary = _buckets[i]
		bin += _sum(b["in"])
		bout += _sum(b["out"])
		pin += int(b["pin"])
		pout += int(b["pout"])
		frame_sum += float(b["frame_ms"])

	var clock := frames.summary(1.0)
	var f := {
		"connected": m != null,
		"fps": float(clock["fps"]),
		"frame_ms": float(clock["mean_ms"]),
		"clock": clock,
		"draw_calls": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
		"objects": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME),
		"primitives": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME),
		"pixels_3d": _pixels_3d(),
		"in_rate": float(bin) / secs, "out_rate": float(bout) / secs,
		"in_pps": float(pin) / secs, "out_pps": float(pout) / secs,
	}
	_refigure_net(f)
	if m != null:
		f["transport"] = str(m.call(&"transport_name"))
		f["rtt"] = float(m.call(&"rtt"))
		f["link"] = m.call(&"transport_stats")
		# ENet's own variance where there is one: it times every acknowledged packet, where
		# the heartbeat is one sample every two seconds and carries the frame it waited for.
		f["jitter"] = float((f["link"] as Dictionary).get("rtt_var_ms", m.get(&"rtt_jitter_ms")))
		f["remote"] = m.get(&"remote")
		f["largest"] = int(m.get(&"largest_in"))
	var was_connected := bool(_fig.get("connected", false))
	_fig = f
	if was_connected != (m != null):
		_relayout()

	# The scale is set by the 90th percentile, not the peak, with headroom: a content
	# download or a map change is one tall bar, and scaling to it flattens every ordinary
	# bar for as long as it stays on the graph. Taller bars are clipped and capped in a
	# brighter colour, which says "more than this" without spending the graph on it.
	# Up at once, down slowly, so the scale does not breathe with every packet.
	var ins := PackedFloat32Array()
	var outs := PackedFloat32Array()
	var peak_rtt := 0.0
	for b in _buckets:
		ins.append(float(_sum(b["in"])) / bucket_sec)
		outs.append(float(_sum(b["out"])) / bucket_sec)
		peak_rtt = maxf(peak_rtt, float(b["rtt"]))
	_in_scale = _settle(_in_scale, _nice(maxf(_percentile(ins, 0.9) * 1.6, 1024.0)))
	_out_scale = _settle(_out_scale, _nice(maxf(_percentile(outs, 0.9) * 1.6, 512.0)))
	_rtt_scale = _settle(_rtt_scale, _nice(maxf(peak_rtt * 1.2, 50.0)))


## The prediction's cost over the last second, from the manager's running totals.
func _refigure_net(f: Dictionary) -> void:
	var nm := net_manager() if level >= Level.FULL else null
	if nm == null:
		_net_marks.clear()
		return
	var now := Time.get_ticks_usec()
	var counters: Dictionary = nm.call(&"perf_counters")
	_net_marks.append([now, counters])
	while _net_marks.size() > 2 and int(_net_marks[1][0]) <= now - 1000000:
		_net_marks.pop_front()
	var then: Array = _net_marks[0]
	var secs := float(now - int(then[0])) / 1e6
	if secs <= 0.0:
		return
	var was: Dictionary = then[1]
	var per := func(key: StringName) -> float:
		return float(int(counters.get(key, 0)) - int(was.get(key, 0))) / secs
	f["net"] = {
		"snapshots": per.call(&"snapshots"),
		"snapshot_ms": per.call(&"snapshot_usec") / 1000.0,
		"reconciles": per.call(&"reconciles"),
		"reconcile_ms": per.call(&"reconcile_usec") / 1000.0,
		"replayed": per.call(&"replayed_ticks"),
		"predict_ms": per.call(&"predict_usec") / 1000.0,
		"lead": int(counters.get(&"lead_ticks", 0)),
	}


static func _percentile(values: PackedFloat32Array, q: float) -> float:
	if values.is_empty():
		return 0.0
	var sorted := values.duplicate()
	sorted.sort()
	return sorted[clampi(int(float(sorted.size() - 1) * q), 0, sorted.size() - 1)]


static func _settle(current: float, target: float) -> float:
	return target if target >= current else lerpf(current, target, 0.04)


## The next 1, 2 or 5 times a power of ten.
static func _nice(v: float) -> float:
	var p := pow(10.0, floorf(log(maxf(v, 1.0)) / log(10.0)))
	for k: float in [1.0, 2.0, 5.0, 10.0]:
		if v <= k * p:
			return k * p
	return 10.0 * p


# --- Layout --------------------------------------------------------------------

func _line_h() -> float:
	return float(_font_size()) + 6.0


func _font_size() -> int:
	return kit.size_small if kit != null else 13


func _text_lines() -> int:
	# Offline there is one line to say (the frame, and "offline"); the rest would be a
	# block of empty rows under it.
	# FULL keeps its two frame rows offline: where a frame goes matters solo too.
	if level != Level.OFF and not bool(_fig.get("connected", false)):
		return 3 if level == Level.FULL else 1
	match level:
		Level.NUMBERS, Level.GRAPH:
			return 2
		Level.FULL:
			return 8
	return 0


## The panel's height for the current level.
func panel_height() -> float:
	if level == Level.OFF:
		return 0.0
	var h := PAD * 2.0 + float(_text_lines()) * _line_h()
	if level >= Level.GRAPH:
		h += float(graph_height) + GAP + 2.0
	if level >= Level.FULL:
		h += (STRIP_H + GAP) * 2.0
	return h


func _relayout() -> void:
	var w := panel_width
	var h := panel_height()
	var right := corner == &"bottom_right" or corner == &"top_right"
	var bottom := corner == &"bottom_right" or corner == &"bottom_left"
	anchor_left = 1.0 if right else 0.0
	anchor_right = anchor_left
	anchor_top = 1.0 if bottom else 0.0
	anchor_bottom = anchor_top
	offset_left = -w - margin.x if right else margin.x
	offset_right = offset_left + w
	# A top corner sits under the row the frame counter and most status lines use.
	offset_top = -h - margin.y if bottom else margin.y + 30.0
	offset_bottom = offset_top + h
	_capacity = maxi(8, int((w - PAD * 2.0 - GUTTER) / (BAR_W + BAR_GAP)))
	queue_redraw()


# --- Drawing -------------------------------------------------------------------

func _palette() -> DotMenuPalette:
	return kit.palette if kit != null else DotMenuPalette.new()


func _font() -> Font:
	return kit.base_font() if kit != null and kit.base_font() != null else ThemeDB.fallback_font


## A channel's colour: the theme's `net_<n>` extra when it names one, else the stock four,
## which were picked to stay apart on every stock theme's dark HUD plate.
func channel_colour(ch: int) -> Color:
	var fallback: Color = STOCK_CHANNEL_COLOURS[ch % STOCK_CHANNEL_COLOURS.size()]
	if ch >= STOCK_CHANNEL_COLOURS.size():
		fallback = fallback.lightened(0.35)
	return _palette().color(StringName("net_%d" % ch), fallback)


func _draw() -> void:
	if level == Level.OFF:
		return
	var p := _palette()

	if _plate == null:
		# Built once per theme ([method restyle] drops it), not once per draw.
		_plate = StyleBoxFlat.new()
		# The HUD plate, made nearly solid: this sits over the world and the HUD for minutes
		# at a time and is read in a glance. At 0.68 a HUD's message feed read straight
		# through the graph, which is two things in one place and neither legible.
		_plate.bg_color = Color(p.hud_plate, maxf(p.hud_plate.a, 0.85))
		_plate.border_color = p.line
		_plate.set_border_width_all(1)
		_plate.set_corner_radius_all(kit.radius_small if kit != null else 9)
	draw_style_box(_plate, Rect2(Vector2.ZERO, size))

	var y := PAD + 2.0
	var graph_w := size.x - PAD * 2.0 - GUTTER
	var gx := PAD + GUTTER
	if level >= Level.GRAPH:
		_draw_arrivals(Rect2(gx, y, graph_w, float(graph_height)))
		y += float(graph_height) + GAP
	if level >= Level.FULL:
		_draw_departures(Rect2(gx, y, graph_w, STRIP_H))
		y += STRIP_H + GAP
		_draw_frames(Rect2(gx, y, graph_w, STRIP_H))
		y += STRIP_H + GAP
	_draw_text(Rect2(PAD, y, size.x - PAD * 2.0, size.y - y - PAD))


func _bar_x(rect: Rect2, i: int) -> float:
	# Newest on the right, so the eye reads time the way it reads text.
	return rect.end.x - float(_buckets.size() - i) * (BAR_W + BAR_GAP)


## The rules behind a graph, and its name and scale in the gutter to its left — never over
## the bars, which is where the first draw put them and where they could not be read.
func _frame(rect: Rect2, title: String, scale: String, scale_colour: Color) -> void:
	var p := _palette()
	var font := _font()
	var fs := _font_size() - 2
	var top := rect.position.y
	draw_line(Vector2(rect.position.x, top), Vector2(rect.end.x, top), Color(p.line, minf(1.0, p.line.a * 2.0)), 1.0)
	if rect.size.y >= 40.0:
		var mid := top + rect.size.y * 0.5
		draw_dashed_line(Vector2(rect.position.x, mid), Vector2(rect.end.x, mid), p.line, 1.0, 2.0)
	draw_line(Vector2(rect.position.x, rect.end.y), Vector2(rect.end.x, rect.end.y), Color(p.hud_detail, 0.4), 1.0)
	var lx := rect.position.x - GUTTER
	draw_string(font, Vector2(lx, top + float(fs) + 1.0), title, HORIZONTAL_ALIGNMENT_LEFT, GUTTER - 6.0, fs, p.hud_text)
	if scale != "":
		var sy := top + float(fs) * 2.0 + 3.0 if rect.size.y >= float(fs) * 2.0 + 4.0 else top + float(fs) + 1.0
		var sx := lx if rect.size.y >= float(fs) * 2.0 + 4.0 else lx + font.get_string_size(title + " ", HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(font, Vector2(sx, sy), scale, HORIZONTAL_ALIGNMENT_LEFT, GUTTER - 4.0, fs - 1, scale_colour)


## Stacked bars by channel, clipped at the top with a bright cap when a bar is more than
## the scale holds.
func _bars(rect: Rect2, key: String, scale: float, one_colour: Variant, alpha: float) -> void:
	for i in _buckets.size():
		var chans: PackedInt64Array = _buckets[i][key]
		var x := _bar_x(rect, i)
		var base := rect.end.y
		var clipped := false
		for ch in chans.size():
			if chans[ch] <= 0:
				continue
			var h := float(chans[ch]) / bucket_sec / scale * rect.size.y
			if h > base - rect.position.y:
				h = base - rect.position.y
				clipped = true
			if h <= 0.0:
				continue
			var c: Color = one_colour if one_colour is Color else channel_colour(ch)
			draw_rect(Rect2(x, base - h, BAR_W, h), Color(c, alpha))
			base -= h
		if clipped:
			draw_rect(Rect2(x - 0.5, rect.position.y, BAR_W + 1.0, 2.0), _palette().hud_text)
		elif base < rect.end.y - 1.0:
			# A lit top on each bar, so a dense graph still reads as bars.
			draw_rect(Rect2(x, base, BAR_W, 1.0), Color(1, 1, 1, 0.4 * alpha))


func _draw_arrivals(rect: Rect2) -> void:
	var p := _palette()
	var websocket := str(_fig.get("transport", "")) == "websocket"
	_frame(rect, "in", "%s/s" % _bytes(_in_scale), p.hud_detail)
	if not bool(_fig.get("connected", false)):
		draw_string(_font(), Vector2(rect.position.x, rect.get_center().y + 5.0), "not connected",
			HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, _font_size(), Color(p.hud_detail, 0.85))
		return
	_bars(rect, "in", _in_scale, p.accent if websocket else null, 0.9)
	_draw_ping(rect)


## Ping across the arrivals graph, on its own scale, labelled in the gutter in its colour.
##
## The gutter's bottom row is the [i]current[/i] ping, the number the line ends on, and the
## scale is written on the dashed midline as half of it. The first draw wrote the scale's top
## at the bottom of the gutter, right beside a line that sits low on its own scale (the scale
## is at least 1.2x the window's peak), so "200 ms" next to a flat line read as a 200 ms ping
## while the readout said far less.
func _draw_ping(rect: Rect2) -> void:
	var points := PackedVector2Array()
	var samples := PackedVector2Array()
	for i in _buckets.size():
		var rtt := float(_buckets[i]["rtt"])
		if rtt < 0.0:
			continue
		var at := Vector2(_bar_x(rect, i) + BAR_W * 0.5, rect.end.y - clampf(rtt / _rtt_scale, 0.0, 1.0) * rect.size.y)
		points.append(at)
		if bool(_buckets[i].get("fresh", false)):
			samples.append(at)
	var now := float(_fig.get("rtt", -1.0))
	var colour := _ping_colour(now)
	var fs := _font_size() - 2
	var lx := rect.position.x - GUTTER
	if rect.size.y >= float(fs) * 4.0 + 8.0:
		draw_string(_font(), Vector2(lx, rect.end.y - float(fs) - 4.0), "ping", HORIZONTAL_ALIGNMENT_LEFT, GUTTER - 6.0, fs, colour)
		draw_string(_font(), Vector2(lx, rect.end.y - 3.0), ("%d ms" % roundi(now)) if now >= 0.0 else "—", HORIZONTAL_ALIGNMENT_LEFT, GUTTER - 4.0, fs - 1, Color(colour, 0.8))
	if rect.size.y >= float(fs) * 6.0 + 8.0:
		# Right-aligned against the graph, on the dashed rule it names.
		draw_string(_font(), Vector2(lx, rect.get_center().y + float(fs) * 0.5 - 1.0), "%d ms" % roundi(_rtt_scale * 0.5),
			HORIZONTAL_ALIGNMENT_RIGHT, GUTTER - 6.0, fs - 1, Color(colour, 0.7))
	if points.size() >= 2:
		draw_polyline(points, Color(0, 0, 0, 0.5), 3.5, true)
		draw_polyline(points, colour, 1.6, true)
	for at in samples:
		draw_circle(at, 2.5, colour)
	if not points.is_empty():
		draw_circle(points[points.size() - 1], 3.0, colour)


func _draw_departures(rect: Rect2) -> void:
	var p := _palette()
	_frame(rect, "out", "%s/s" % _bytes(_out_scale), p.hud_detail)
	_bars(rect, "out", _out_scale, null, 0.75)


## What a part of the frame is drawn in: physics, script, render. The wait is the bar's
## own colour, by the frame's total, so the bar's height still reads at a glance.
const PART_COLOURS: Array[Color] = [Color("#c58af9"), Color("#6ea8fe"), Color("#5fd38d")]


## Each bucket's slowest frame on the wall clock, stacked by where it went: physics
## (violet), script (blue), render (green), and the wait to the next frame on top in the
## frame's own grade (green to 60 fps, amber to 30, red beyond). Guides at 16.7 and 33.3 ms,
## the two vsync steps a browser frame lands on; a frame past the top is capped bright.
func _draw_frames(rect: Rect2) -> void:
	var p := _palette()
	var top_ms := 50.0
	_frame(rect, "frame", "%d ms" % roundi(top_ms), p.hud_detail)
	for guide_ms: float in [1000.0 / 60.0, 1000.0 / 30.0]:
		var gy := rect.end.y - guide_ms / top_ms * rect.size.y
		draw_dashed_line(Vector2(rect.position.x, gy), Vector2(rect.end.x, gy),
			Color(p.hud_ahead if guide_ms < 20.0 else p.warn, 0.5), 1.0, 3.0)
	var px := rect.size.y / top_ms
	for i in _buckets.size():
		var ms := float(_buckets[i]["frame_ms"])
		if ms <= 0.0:
			continue
		var x := _bar_x(rect, i)
		var parts: PackedInt32Array = _buckets[i].get("parts", PackedInt32Array([0, 0, 0, 0]))
		var base := rect.end.y
		var room := rect.size.y
		for k in 3:
			var h := minf(float(parts[k + 1]) / 1000.0 * px, room)
			if h > 0.0:
				draw_rect(Rect2(x, base - h, BAR_W, h), Color(PART_COLOURS[k], 0.85))
				base -= h
				room -= h
		var total_h := minf(ms * px, rect.size.y)
		var wait_h := total_h - (rect.end.y - base)
		var c := p.hud_ahead if ms <= 17.5 else (p.warn if ms <= 34.0 else p.danger)
		if wait_h > 0.0:
			draw_rect(Rect2(x, base - wait_h, BAR_W, wait_h), Color(c, 0.45))
		if ms > top_ms:
			draw_rect(Rect2(x - 0.5, rect.position.y, BAR_W + 1.0, 2.0), p.danger)


func _draw_text(rect: Rect2) -> void:
	var p := _palette()
	var font := _font()
	var fs := _font_size()
	var lh := _line_h()
	var col := rect.size.x / 3.0
	var y := rect.position.y + float(fs)
	var x := rect.position.x

	var fps := roundi(float(_fig.get("fps", 0.0)))
	var fps_colour := p.hud_ahead if fps >= 55 else (p.warn if fps >= 30 else p.danger)
	_cell(x, y, col, "%d" % fps, fps_colour, " fps  %.1f ms" % float(_fig.get("frame_ms", 0.0)))

	if not bool(_fig.get("connected", false)):
		_cell(x + col, y, col * 2.0, "offline", p.hud_detail, "")
		if level >= Level.FULL:
			_draw_frame_rows(x, y + lh, rect.size.x, col)
		return

	var rtt := float(_fig.get("rtt", -1.0))
	_cell(x + col, y, col, "%d" % roundi(rtt) if rtt >= 0.0 else "—", _ping_colour(rtt),
		" ms ±%d" % roundi(float(_fig.get("jitter", 0.0))) if rtt >= 0.0 else " ms")
	var link: Dictionary = _fig.get("link", {})
	var transport := str(_fig.get("transport", ""))
	draw_string(font, Vector2(x, y), transport, HORIZONTAL_ALIGNMENT_RIGHT, rect.size.x, fs - 2, p.hud_detail)

	y += lh
	_cell(x, y, col, _bytes(float(_fig.get("in_rate", 0.0))), p.hud_text, "/s in")
	_cell(x + col, y, col, _bytes(float(_fig.get("out_rate", 0.0))), p.hud_text, "/s out")
	if link.has("loss"):
		var loss := float(link["loss"]) * 100.0
		_cell(x + col * 2.0, y, col, "%.1f%%" % loss, p.hud_ahead if loss < 1.0 else (p.warn if loss < 5.0 else p.danger), " loss")
	elif link.has("queued"):
		var queued := int(link["queued"])
		_cell(x + col * 2.0, y, col, _bytes(float(queued)), p.hud_ahead if queued < 4096 else p.warn, " queued")

	if level < Level.FULL:
		return

	y += lh
	_cell(x, y, col, "%d" % roundi(float(_fig.get("in_pps", 0.0))), p.hud_text, " pkt/s in")
	_cell(x + col, y, col, "%d" % roundi(float(_fig.get("out_pps", 0.0))), p.hud_text, " pkt/s out")
	_cell(x + col * 2.0, y, col, _bytes(float(_fig.get("largest", 0))), p.hud_text, " largest")

	y += lh
	y = _draw_frame_rows(x, y, rect.size.x, col)

	var net: Dictionary = _fig.get("net", {})
	if not net.is_empty():
		var replayed := float(net["replayed"])
		var per_frame := replayed / maxf(1.0, float(_fig.get("fps", 1.0)))
		_cell(x, y, col, "%.1f" % float(net["snapshot_ms"]), p.hud_text, " ms/s snap")
		_cell(x + col, y, col, "%.0f" % per_frame, p.hud_ahead if per_frame < 6.0 else (p.warn if per_frame < 15.0 else p.danger),
			" resim/fr %.0f ms/s" % float(net["reconcile_ms"]))
		_cell(x + col * 2.0, y, col, "%d" % int(net["lead"]), p.hud_text, " lead  %.0f ms/s pred" % float(net["predict_ms"]))
	else:
		_cell(x, y, rect.size.x, "", p.hud_detail, "prediction: not published")
	y += lh

	var sv: Dictionary = _fig.get("remote", {})
	if sv.has("tick"):
		var tick := int(sv["tick"])
		var sv_fps := float(sv.get("fps", 0.0))
		_cell(x, y, col, "%d" % tick, p.hud_text, " tick")
		_cell(x + col, y, col, "%.0f" % sv_fps, p.hud_ahead if sv_fps >= float(tick) * 0.9 else p.warn, " sv fps")
		_cell(x + col * 2.0, y, col, "±%.1f" % float(sv.get("var_ms", 0.0)), p.hud_text, " ms sv var")
	else:
		_cell(x, y, rect.size.x, "", p.hud_detail, "server: not reported")

	y += lh
	_legend(Vector2(x, y), rect.size.x, transport == "websocket")


## Pixels the 3D world is drawn at: the window in device pixels (a browser on a high-density
## screen draws its canvas at the device's pixels, not the page's) times the 3D scale. A
## frame whose time is in the wait column with few draws is usually this: the GPU filling
## four times the pixels anybody expected.
func _pixels_3d() -> int:
	var vp := get_viewport()
	if vp == null:
		return 0
	var size := Vector2(vp.get_window().size) if vp.get_window() != null else vp.get_visible_rect().size
	var k := vp.scaling_3d_scale
	return int(size.x * k * size.y * k)


## The two frame rows: where the last second's frames went on average (physics with its
## steps a frame, script, render, the wait), then the renderer's counts and the hitches.
## Returns the y of the row after them.
func _draw_frame_rows(x: float, y: float, width: float, col: float) -> float:
	var p := _palette()
	var c: Dictionary = _fig.get("clock", {})
	var w4 := width / 4.0
	_cell(x, y, w4, "%.1f" % float(c.get("physics_ms", 0.0)), PART_COLOURS[0], " phys ×%.1f" % float(c.get("steps", 0.0)))
	_cell(x + w4, y, w4, "%.1f" % float(c.get("script_ms", 0.0)), PART_COLOURS[1], " script")
	_cell(x + w4 * 2.0, y, w4, "%.1f" % float(c.get("render_ms", 0.0)), PART_COLOURS[2], " render")
	_cell(x + w4 * 3.0, y, w4, "%.1f" % float(c.get("wait_ms", 0.0)), p.hud_text, " ms wait")
	y += _line_h()
	_cell(x, y, col, "%d" % int(_fig.get("draw_calls", 0)), p.hud_text, " draws  %d obj" % int(_fig.get("objects", 0)))
	_cell(x + col, y, col, "%.1fM" % (float(_fig.get("pixels_3d", 0)) / 1.0e6), p.hud_text, " px  %dk prims" % roundi(float(_fig.get("primitives", 0)) / 1000.0))
	var hitches := int(c.get("hitches", 0))
	_cell(x + col * 2.0, y, col, "%d" % hitches, p.hud_ahead if hitches == 0 else (p.warn if hitches < 5 else p.danger),
		" hitch/min, worst %.0f ms" % float(c.get("worst_ms", 0.0)))
	return y + _line_h()


## A swatch and a name per channel. Over WebSocket the arrivals are one stream, which is
## said in place of pretending they were split.
func _legend(at: Vector2, width: float, websocket: bool) -> void:
	var p := _palette()
	var font := _font()
	var fs := _font_size() - 2
	var x := at.x
	var sw := 8.0
	var y := at.y - float(fs) * 0.5 - sw * 0.5 + 1.0
	if websocket:
		draw_rect(Rect2(x, y, sw, sw), p.accent)
		x += sw + 4.0
		var note := "in: one stream (WebSocket has no channels)   out:"
		draw_string(font, Vector2(x, at.y), note, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, p.hud_detail)
		x += font.get_string_size(note, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 6.0
		for ch in mini(4, channel_names.size()):
			draw_rect(Rect2(x, y, sw, sw), channel_colour(ch))
			x += sw + 3.0
		return
	for ch in mini(4, channel_names.size()):
		var label := channel_names[ch]
		var w := sw + 4.0 + font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 12.0
		if x + w > at.x + width + 12.0:
			break
		draw_rect(Rect2(x, y, sw, sw), channel_colour(ch))
		draw_string(font, Vector2(x + sw + 4.0, at.y), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, p.hud_detail)
		x += w


## A figure in [param colour] followed by its unit, smaller, in the detail colour.
func _cell(x: float, y: float, width: float, figure: String, colour: Color, unit: String) -> void:
	var p := _palette()
	var font := _font()
	var fs := _font_size()
	var w := 0.0
	if figure != "":
		draw_string(font, Vector2(x, y), figure, HORIZONTAL_ALIGNMENT_LEFT, width, fs, colour)
		w = font.get_string_size(figure, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	if unit != "":
		draw_string(font, Vector2(x + w, y), unit, HORIZONTAL_ALIGNMENT_LEFT, maxf(0.0, width - w), fs - 2, p.hud_detail)


func _ping_colour(rtt: float) -> Color:
	var p := _palette()
	if rtt < 0.0:
		return p.hud_detail
	return p.hud_ahead if rtt < 80.0 else (p.warn if rtt < 160.0 else p.danger)


## 812 B, 18.3 KB, 2.41 MB. Binary multiples, as every byte count in this family is.
static func _bytes(n: float) -> String:
	if n < 1024.0:
		return "%d B" % roundi(n)
	if n < 1024.0 * 1024.0:
		return ("%.1f KB" if n < 10240.0 else "%.0f KB") % (n / 1024.0)
	return "%.2f MB" % (n / 1048576.0)


func describe() -> Dictionary:
	return {
		"level": level, "graph_height": graph_height, "corner": String(corner),
		"buckets": _buckets.size(), "capacity": _capacity,
		"connected": bool(_fig.get("connected", false)),
		"transport": str(_fig.get("transport", "")),
		"in_rate": float(_fig.get("in_rate", 0.0)), "out_rate": float(_fig.get("out_rate", 0.0)),
		"rtt": float(_fig.get("rtt", -1.0)),
		"fps": float(_fig.get("fps", 0.0)), "frame_ms": float(_fig.get("frame_ms", 0.0)),
		"frames": frames.describe(), "net": _fig.get("net", {}),
		"draw_calls": int(_fig.get("draw_calls", 0)),
		"pixels_3d": int(_fig.get("pixels_3d", 0)),
	}
