class_name DotMenuNetStatPainter
extends RefCounted

## Draws a [DotMenuNetStat]'s graphs and text. Split out so the overlay stays under the size cap; it only calls the host's draw methods, so it must run inside the host's `_draw`.

var ns: DotMenuNetStat


func _init(p_host: DotMenuNetStat) -> void:
	ns = p_host


func paint() -> void:
	var y := ns.PAD + 2.0
	var graph_w := ns.size.x - ns.PAD * 2.0 - ns.GUTTER
	var gx := ns.PAD + ns.GUTTER
	if ns.level >= ns.Level.GRAPH:
		_draw_arrivals(Rect2(gx, y, graph_w, float(ns.graph_height)))
		y += float(ns.graph_height) + ns.GAP
	if ns.level >= ns.Level.FULL:
		_draw_departures(Rect2(gx, y, graph_w, ns.STRIP_H))
		y += ns.STRIP_H + ns.GAP
		_draw_frames(Rect2(gx, y, graph_w, ns.STRIP_H))
		y += ns.STRIP_H + ns.GAP
	_draw_text(Rect2(ns.PAD, y, ns.size.x - ns.PAD * 2.0, ns.size.y - y - ns.PAD))


func _bar_x(rect: Rect2, i: int) -> float:
	# Newest on the right, so the eye reads time the way it reads text.
	return rect.end.x - float(ns._buckets.size() - i) * (ns.BAR_W + ns.BAR_GAP)


## The rules behind a graph, and its name and scale in the gutter to its left — never over
## the bars, which is where the first draw put them and where they could not be read.
func _frame(rect: Rect2, title: String, scale: String, scale_colour: Color) -> void:
	var p := ns._palette()
	var font := ns._font()
	var fs := ns._font_size() - 2
	var top := rect.position.y
	ns.draw_line(Vector2(rect.position.x, top), Vector2(rect.end.x, top), Color(p.line, minf(1.0, p.line.a * 2.0)), 1.0)
	if rect.size.y >= 40.0:
		var mid := top + rect.size.y * 0.5
		ns.draw_dashed_line(Vector2(rect.position.x, mid), Vector2(rect.end.x, mid), p.line, 1.0, 2.0)
	ns.draw_line(Vector2(rect.position.x, rect.end.y), Vector2(rect.end.x, rect.end.y), Color(p.hud_detail, 0.4), 1.0)
	var lx := rect.position.x - ns.GUTTER
	ns.draw_string(font, Vector2(lx, top + float(fs) + 1.0), title, HORIZONTAL_ALIGNMENT_LEFT, ns.GUTTER - 6.0, fs, p.hud_text)
	if scale != "":
		var sy := top + float(fs) * 2.0 + 3.0 if rect.size.y >= float(fs) * 2.0 + 4.0 else top + float(fs) + 1.0
		var sx := lx if rect.size.y >= float(fs) * 2.0 + 4.0 else lx + font.get_string_size(title + " ", HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		ns.draw_string(font, Vector2(sx, sy), scale, HORIZONTAL_ALIGNMENT_LEFT, ns.GUTTER - 4.0, fs - 1, scale_colour)


## Stacked bars by channel, clipped at the top with a bright cap when a bar is more than
## the scale holds.
func _bars(rect: Rect2, key: String, scale: float, one_colour: Variant, alpha: float) -> void:
	for i in ns._buckets.size():
		var chans: PackedInt64Array = ns._buckets[i][key]
		var x := _bar_x(rect, i)
		var base := rect.end.y
		var clipped := false
		for ch in chans.size():
			if chans[ch] <= 0:
				continue
			var h := float(chans[ch]) / ns.bucket_sec / scale * rect.size.y
			if h > base - rect.position.y:
				h = base - rect.position.y
				clipped = true
			if h <= 0.0:
				continue
			var c: Color = one_colour if one_colour is Color else ns.channel_colour(ch)
			ns.draw_rect(Rect2(x, base - h, ns.BAR_W, h), Color(c, alpha))
			base -= h
		if clipped:
			ns.draw_rect(Rect2(x - 0.5, rect.position.y, ns.BAR_W + 1.0, 2.0), ns._palette().hud_text)
		elif base < rect.end.y - 1.0:
			# A lit top on each bar, so a dense graph still reads as bars.
			ns.draw_rect(Rect2(x, base, ns.BAR_W, 1.0), Color(1, 1, 1, 0.4 * alpha))


func _draw_arrivals(rect: Rect2) -> void:
	var p := ns._palette()
	var websocket := str(ns._fig.get("transport", "")) == "websocket"
	_frame(rect, "in", "%s/s" % DotMenuNetStat._bytes(ns._in_scale), p.hud_detail)
	if not bool(ns._fig.get("connected", false)):
		ns.draw_string(ns._font(), Vector2(rect.position.x, rect.get_center().y + 5.0), "not connected",
			HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, ns._font_size(), Color(p.hud_detail, 0.85))
		return
	_bars(rect, "in", ns._in_scale, p.accent if websocket else null, 0.9)
	_draw_ping(rect)


## Ping across the arrivals graph, on its own scale, labelled in the gutter in its colour.
## The gutter's bottom row is the current ping and the scale is written on the dashed midline as half of it; labelling the scale's top
## next to a low line read as a 200 ms ping while the readout said far less.
func _draw_ping(rect: Rect2) -> void:
	var points := PackedVector2Array()
	var samples := PackedVector2Array()
	for i in ns._buckets.size():
		var rtt := float(ns._buckets[i]["rtt"])
		if rtt < 0.0:
			continue
		var at := Vector2(_bar_x(rect, i) + ns.BAR_W * 0.5, rect.end.y - clampf(rtt / ns._rtt_scale, 0.0, 1.0) * rect.size.y)
		points.append(at)
		if bool(ns._buckets[i].get("fresh", false)):
			samples.append(at)
	var now := float(ns._fig.get("rtt", -1.0))
	var colour := _ping_colour(now)
	var fs := ns._font_size() - 2
	var lx := rect.position.x - ns.GUTTER
	if rect.size.y >= float(fs) * 4.0 + 8.0:
		ns.draw_string(ns._font(), Vector2(lx, rect.end.y - float(fs) - 4.0), "ping", HORIZONTAL_ALIGNMENT_LEFT, ns.GUTTER - 6.0, fs, colour)
		ns.draw_string(ns._font(), Vector2(lx, rect.end.y - 3.0), ("%d ms" % roundi(now)) if now >= 0.0 else "—", HORIZONTAL_ALIGNMENT_LEFT, ns.GUTTER - 4.0, fs - 1, Color(colour, 0.8))
	if rect.size.y >= float(fs) * 6.0 + 8.0:
		# Right-aligned against the graph, on the dashed rule it names.
		ns.draw_string(ns._font(), Vector2(lx, rect.get_center().y + float(fs) * 0.5 - 1.0), "%d ms" % roundi(ns._rtt_scale * 0.5),
			HORIZONTAL_ALIGNMENT_RIGHT, ns.GUTTER - 6.0, fs - 1, Color(colour, 0.7))
	if points.size() >= 2:
		ns.draw_polyline(points, Color(0, 0, 0, 0.5), 3.5, true)
		ns.draw_polyline(points, colour, 1.6, true)
	for at in samples:
		ns.draw_circle(at, 2.5, colour)
	if not points.is_empty():
		ns.draw_circle(points[points.size() - 1], 3.0, colour)


func _draw_departures(rect: Rect2) -> void:
	var p := ns._palette()
	_frame(rect, "out", "%s/s" % DotMenuNetStat._bytes(ns._out_scale), p.hud_detail)
	_bars(rect, "out", ns._out_scale, null, 0.75)


## What a part of the frame is drawn in: physics, script, render. The wait is the bar's
## own colour, by the frame's total, so the bar's height still reads at a glance.
const PART_COLOURS: Array[Color] = [Color("#c58af9"), Color("#6ea8fe"), Color("#5fd38d")]


## Each bucket's slowest frame on the wall clock, stacked by where it went (physics violet, script blue, render green, the wait on top
## in the frame's grade). Guides at 16.7 and 33.3 ms, the two vsync steps a browser frame lands on; a frame past the top is capped bright.
func _draw_frames(rect: Rect2) -> void:
	var p := ns._palette()
	var top_ms := 50.0
	_frame(rect, "frame", "%d ms" % roundi(top_ms), p.hud_detail)
	for guide_ms: float in [1000.0 / 60.0, 1000.0 / 30.0]:
		var gy := rect.end.y - guide_ms / top_ms * rect.size.y
		ns.draw_dashed_line(Vector2(rect.position.x, gy), Vector2(rect.end.x, gy),
			Color(p.hud_ahead if guide_ms < 20.0 else p.warn, 0.5), 1.0, 3.0)
	var px := rect.size.y / top_ms
	for i in ns._buckets.size():
		var ms := float(ns._buckets[i]["frame_ms"])
		if ms <= 0.0:
			continue
		var x := _bar_x(rect, i)
		var parts: PackedInt32Array = ns._buckets[i].get("parts", PackedInt32Array([0, 0, 0, 0]))
		var base := rect.end.y
		var room := rect.size.y
		for k in 3:
			var h := minf(float(parts[k + 1]) / 1000.0 * px, room)
			if h > 0.0:
				ns.draw_rect(Rect2(x, base - h, ns.BAR_W, h), Color(PART_COLOURS[k], 0.85))
				base -= h
				room -= h
		var total_h := minf(ms * px, rect.size.y)
		var wait_h := total_h - (rect.end.y - base)
		var c := p.hud_ahead if ms <= 17.5 else (p.warn if ms <= 34.0 else p.danger)
		if wait_h > 0.0:
			ns.draw_rect(Rect2(x, base - wait_h, ns.BAR_W, wait_h), Color(c, 0.45))
		if ms > top_ms:
			ns.draw_rect(Rect2(x - 0.5, rect.position.y, ns.BAR_W + 1.0, 2.0), p.danger)


func _draw_text(rect: Rect2) -> void:
	var p := ns._palette()
	var font := ns._font()
	var fs := ns._font_size()
	var lh := ns._line_h()
	var col := rect.size.x / 3.0
	var y := rect.position.y + float(fs)
	var x := rect.position.x

	var fps := roundi(float(ns._fig.get("fps", 0.0)))
	var fps_colour := p.hud_ahead if fps >= 55 else (p.warn if fps >= 30 else p.danger)
	_cell(x, y, col, "%d" % fps, fps_colour, " fps  %.1f ms" % float(ns._fig.get("frame_ms", 0.0)))

	if not bool(ns._fig.get("connected", false)):
		_cell(x + col, y, col * 2.0, "offline", p.hud_detail, "")
		if ns.level >= ns.Level.FULL:
			_draw_frame_rows(x, y + lh, rect.size.x, col)
		return

	var rtt := float(ns._fig.get("rtt", -1.0))
	_cell(x + col, y, col, "%d" % roundi(rtt) if rtt >= 0.0 else "—", _ping_colour(rtt),
		" ms ±%d" % roundi(float(ns._fig.get("jitter", 0.0))) if rtt >= 0.0 else " ms")
	var link: Dictionary = ns._fig.get("link", {})
	var transport := str(ns._fig.get("transport", ""))
	ns.draw_string(font, Vector2(x, y), transport, HORIZONTAL_ALIGNMENT_RIGHT, rect.size.x, fs - 2, p.hud_detail)

	y += lh
	_cell(x, y, col, DotMenuNetStat._bytes(float(ns._fig.get("in_rate", 0.0))), p.hud_text, "/s in")
	_cell(x + col, y, col, DotMenuNetStat._bytes(float(ns._fig.get("out_rate", 0.0))), p.hud_text, "/s out")
	if link.has("loss"):
		var loss := float(link["loss"]) * 100.0
		_cell(x + col * 2.0, y, col, "%.1f%%" % loss, p.hud_ahead if loss < 1.0 else (p.warn if loss < 5.0 else p.danger), " loss")
	elif link.has("queued"):
		var queued := int(link["queued"])
		_cell(x + col * 2.0, y, col, DotMenuNetStat._bytes(float(queued)), p.hud_ahead if queued < 4096 else p.warn, " queued")

	if ns.level < ns.Level.FULL:
		return

	y += lh
	_cell(x, y, col, "%d" % roundi(float(ns._fig.get("in_pps", 0.0))), p.hud_text, " pkt/s in")
	_cell(x + col, y, col, "%d" % roundi(float(ns._fig.get("out_pps", 0.0))), p.hud_text, " pkt/s out")
	_cell(x + col * 2.0, y, col, DotMenuNetStat._bytes(float(ns._fig.get("largest", 0))), p.hud_text, " largest")

	y += lh
	y = _draw_frame_rows(x, y, rect.size.x, col)

	var net: Dictionary = ns._fig.get("net", {})
	if not net.is_empty():
		var replayed := float(net["replayed"])
		var per_frame := replayed / maxf(1.0, float(ns._fig.get("fps", 1.0)))
		_cell(x, y, col, "%.1f" % float(net["snapshot_ms"]), p.hud_text, " ms/s snap")
		_cell(x + col, y, col, "%.0f" % per_frame, p.hud_ahead if per_frame < 6.0 else (p.warn if per_frame < 15.0 else p.danger),
			" resim/fr %.0f ms/s" % float(net["reconcile_ms"]))
		_cell(x + col * 2.0, y, col, "%d" % int(net["lead"]), p.hud_text, " lead  %.0f ms/s pred" % float(net["predict_ms"]))
	else:
		_cell(x, y, rect.size.x, "", p.hud_detail, "prediction: not published")
	y += lh

	var sv: Dictionary = ns._fig.get("remote", {})
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


## The two frame rows: where the last second's frames went on average (physics with its
## steps a frame, script, render, the wait), then the renderer's counts and the hitches.
## Returns the y of the row after them.
func _draw_frame_rows(x: float, y: float, width: float, col: float) -> float:
	var p := ns._palette()
	var c: Dictionary = ns._fig.get("clock", {})
	var w4 := width / 4.0
	_cell(x, y, w4, "%.1f" % float(c.get("physics_ms", 0.0)), PART_COLOURS[0], " phys ×%.1f" % float(c.get("steps", 0.0)))
	_cell(x + w4, y, w4, "%.1f" % float(c.get("script_ms", 0.0)), PART_COLOURS[1], " script")
	_cell(x + w4 * 2.0, y, w4, "%.1f" % float(c.get("render_ms", 0.0)), PART_COLOURS[2], " render")
	_cell(x + w4 * 3.0, y, w4, "%.1f" % float(c.get("wait_ms", 0.0)), p.hud_text, " ms wait")
	y += ns._line_h()
	_cell(x, y, col, "%d" % int(ns._fig.get("draw_calls", 0)), p.hud_text, " draws  %d obj" % int(ns._fig.get("objects", 0)))
	_cell(x + col, y, col, "%.1fM" % (float(ns._fig.get("pixels_3d", 0)) / 1.0e6), p.hud_text, " px  %dk prims" % roundi(float(ns._fig.get("primitives", 0)) / 1000.0))
	var hitches := int(c.get("hitches", 0))
	_cell(x + col * 2.0, y, col, "%d" % hitches, p.hud_ahead if hitches == 0 else (p.warn if hitches < 5 else p.danger),
		" hitch/min, worst %.0f ms" % float(c.get("worst_ms", 0.0)))
	return y + ns._line_h()


## A swatch and a name per channel. Over WebSocket the arrivals are one stream, which is
## said in place of pretending they were split.
func _legend(at: Vector2, width: float, websocket: bool) -> void:
	var p := ns._palette()
	var font := ns._font()
	var fs := ns._font_size() - 2
	var x := at.x
	var sw := 8.0
	var y := at.y - float(fs) * 0.5 - sw * 0.5 + 1.0
	if websocket:
		ns.draw_rect(Rect2(x, y, sw, sw), p.accent)
		x += sw + 4.0
		var note := "in: one stream (WebSocket has no channels)   out:"
		ns.draw_string(font, Vector2(x, at.y), note, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, p.hud_detail)
		x += font.get_string_size(note, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 6.0
		for ch in mini(4, ns.channel_names.size()):
			ns.draw_rect(Rect2(x, y, sw, sw), ns.channel_colour(ch))
			x += sw + 3.0
		return
	for ch in mini(4, ns.channel_names.size()):
		var label := ns.channel_names[ch]
		var w := sw + 4.0 + font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 12.0
		if x + w > at.x + width + 12.0:
			break
		ns.draw_rect(Rect2(x, y, sw, sw), ns.channel_colour(ch))
		ns.draw_string(font, Vector2(x + sw + 4.0, at.y), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, p.hud_detail)
		x += w


## A figure in [param colour] followed by its unit, smaller, in the detail colour.
func _cell(x: float, y: float, width: float, figure: String, colour: Color, unit: String) -> void:
	var p := ns._palette()
	var font := ns._font()
	var fs := ns._font_size()
	var w := 0.0
	if figure != "":
		ns.draw_string(font, Vector2(x, y), figure, HORIZONTAL_ALIGNMENT_LEFT, width, fs, colour)
		w = font.get_string_size(figure, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	if unit != "":
		ns.draw_string(font, Vector2(x + w, y), unit, HORIZONTAL_ALIGNMENT_LEFT, maxf(0.0, width - w), fs - 2, p.hud_detail)


func _ping_colour(rtt: float) -> Color:
	var p := ns._palette()
	if rtt < 0.0:
		return p.hud_detail
	return p.hud_ahead if rtt < 80.0 else (p.warn if rtt < 160.0 else p.danger)

