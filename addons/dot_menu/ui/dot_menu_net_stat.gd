class_name DotMenuNetStat
extends Control

## `net_stat`: what the connection is doing, drawn over the game in a corner. Levels 0 (off) to 3; [DotMenu] drives it from `net_stat`, `net_stat_height` and `net_stat_position`. Example: docs/examples.md.
## Numbers come from [method sample_source], a [DotMeteredPeer] (this node's own multiplayer peer, or [member source]); a browser's WebSocket reports every arrival on channel 0, so those bars are one colour. Rates are drawn as rates, per [member bucket_sec], so the scale means the same at every frame rate.
## Frame times are wall-clock ([DotMenuFrameClock]); prediction is read duck-typed from `dot_net_manager`. One draw call, no children, redrawn when a bar closes, so the overlay is not a cost of its own.

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

var _painter := DotMenuNetStatPainter.new(self)

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


## The overlay on a layer of its own under [param host], following the three `net_stat*` settings of [param settings], for a game with no [DotMenu].
## Declare the settings with [method DotMenuStock.declare_net_stat] first. Layer 120: over a HUD and the menu (110),
## under the console (128).
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

	# The scale is the 90th percentile with headroom, not the peak: one content download is one tall bar and would flatten every other.
	# Taller bars are clipped and capped brighter ("more than this"). Up at once, down slowly, so the scale does not breathe.
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

	_painter.paint()

## Pixels the 3D world is drawn at: the window in device pixels (a high-density browser canvas is drawn at the device's)
## times the 3D scale. A frame whose time is in the wait column with few draws is usually this.
func _pixels_3d() -> int:
	var vp := get_viewport()
	if vp == null:
		return 0
	var size := Vector2(vp.get_window().size) if vp.get_window() != null else vp.get_visible_rect().size
	var k := vp.scaling_3d_scale
	return int(size.x * k * size.y * k)


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
