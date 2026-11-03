extends RefCounted

const Selftest := preload("res://examples/menu_selftest.gd")

## The net_stat overlay, run from menu_selftest.

## What net_stat reads from a dot-net manager, and nothing else.
class FakeNetManager extends RefCounted:
	var is_server := false
	var counters := {&"snapshots": 0, &"snapshot_usec": 0, &"reconciles": 0, &"reconcile_usec": 0,
		&"replayed_ticks": 0, &"client_ticks": 0, &"predict_usec": 0, &"lead_ticks": 0}

	func perf_counters() -> Dictionary:
		return counters.duplicate()

## net_stat is three settings, one overlay and a meter. What is asserted is the wiring and
## the arithmetic; how it LOOKS is tools/screenshot.sh's (shot net_stat_*).
static func run(host: Selftest) -> void:
	host._section("net_stat: three settings, one overlay, a meter")

	var menu := host._menu()
	var st := menu.settings
	var ns := menu.net_stat
	host._check(st.schema.has(&"net_stat") and st.schema.has(&"net_stat_height") and st.schema.has(&"net_stat_position"),
		"the interface group declares net_stat and its height and corner")
	host._check(ns != null and not ns.visible and st.get_int(&"net_stat") == 0, "and it starts off")

	menu.open(&"advanced")
	await host.get_tree().process_frame
	host._check(host._row_control(menu, "net_stat") != null and host._row_control(menu, "net_stat_height") != null,
		"the Advanced page shows the level and the height")
	host._check(menu.find_child("Performance", true, false) == null, "and no Performance card without a profiler placed")
	menu.close()
	var profiler := Selftest.FakeProfiler.new()
	DotRegistry.register(DotMenuStock.PROFILER_SERVICE, profiler)
	menu.open(&"advanced")
	await host.get_tree().process_frame
	var perf := menu.find_child("Performance", true, false)
	host._check(perf != null and perf.find_child("FakeProfilerPanel", true, false) != null,
		"a placed profiler's panel is drawn in a Performance card, built with the menu's kit")
	menu.close()
	DotRegistry.unregister_instance(DotMenuStock.PROFILER_SERVICE, profiler)

	await _settings(host, menu, st, ns)
	_meter(host, ns)
	await _frame_clock(host, ns)
	await _prediction(host, ns)

	var _off := st.set_value(&"net_stat", 0)
	host._check(not ns.visible and menu._fps_label.visible, "net_stat 0 hides it, and the counter comes back")

	host._free_menu(menu)

	await host._test_net_stat_own()


static func _settings(host: Selftest, menu: DotMenu, st: DotSettingsManager, ns: DotMenuNetStat) -> void:
	var _fps := st.set_value(&"show_fps", true)
	var _two := st.set_value(&"net_stat", 2)
	host._check(ns.visible and ns.level == DotMenuNetStat.Level.GRAPH, "net_stat 2 draws the graph")
	host._check(not menu._fps_label.visible, "and the frame counter steps aside: net_stat shows the frame rate itself")

	# What a console sends: the line's argument, as text.
	var three := st.set_value(&"net_stat", "3")
	host._check(three.ok and ns.level == DotMenuNetStat.Level.FULL, "\"3\" typed at a console is level 3")

	var _h := st.set_value(&"net_stat_height", 160)
	await host.get_tree().process_frame
	host._check(ns.graph_height == 160 and is_equal_approx(ns.size.y, ns.panel_height()) and ns.size.y > 160.0,
		"the height setting is the graph's, and the panel grows around it (%.0f px)" % ns.size.y)
	host._check(ns.size.x > 200.0, "and it has a width: anchors alone draw nothing")

	var _c := st.set_value(&"net_stat_position", &"top_left")
	host._check(is_zero_approx(ns.anchor_left) and is_zero_approx(ns.anchor_top) and ns.offset_left > 0.0,
		"the corner setting moves it")
	var bad := st.set_value(&"net_stat_position", &"middle")
	host._check(not bad.ok or ns.corner == &"top_left", "a corner that is not one is refused")


static func _meter(host: Selftest, ns: DotMenuNetStat) -> void:
	# A meter fed by hand: 4 KB on the state channel and 512 B of control a bucket, 40 ms ping.
	var meter := DotMeteredPeer.new()
	meter.note_rtt(40.0)
	ns.source = func() -> Object: return meter
	ns.reset()
	for i in 25:
		meter.bytes_in_by_channel[1] += 4096
		meter.bytes_in_by_channel[0] += 512
		meter.bytes_in += 4608
		meter.packets_in += 2
		meter.bytes_out_by_channel[0] += 100
		meter.packets_out += 1
		ns._push(meter)
	var d := ns.describe()
	host._check(bool(d["connected"]) and is_equal_approx(float(d["rtt"]), 40.0), "it reads the meter it is given (%s)" % [d])
	# A held ping is one sample, not one a bar: the line marks where it was measured.
	var fresh := 0
	for b: Dictionary in ns._buckets:
		fresh += 1 if bool(b.get("fresh", false)) else 0
	host._check(fresh == 1, "a ping held across bars is marked as one sample (%d)" % fresh)
	# Twenty-five bars, so the last second (twenty) is all traffic: the first only takes the
	# baseline, because a meter's totals are not arrivals since a bar.
	host._check(is_equal_approx(float(d["in_rate"]), 4608.0 / ns.bucket_sec) and is_equal_approx(float(d["out_rate"]), 100.0 / ns.bucket_sec),
		"in and out are bytes a second over the last second's bars (%.0f, %.0f)" % [d["in_rate"], d["out_rate"]])
	var last: Dictionary = ns._buckets[ns._buckets.size() - 1]
	host._check((last["in"] as PackedInt64Array)[1] == 4096 and (last["in"] as PackedInt64Array)[0] == 512,
		"and each bar keeps its channels apart")

	ns.source = func() -> Object: return null
	ns._push(null)
	host._check(not bool(ns.describe()["connected"]), "with no meter it says so, not a flat line")


static func _frame_clock(host: Selftest, ns: DotMenuNetStat) -> void:
	# The frame clock on the wall clock: frames held to 25 ms by a busy wait read as 25 ms or
	# more, whatever the smoothed process delta says. Headless, so render is 0 and the busy
	# wait lands in the script part.
	host._check(ns.frames.is_running(), "the frame clock runs while the panel is shown")
	var burn := func() -> void:
		var until := Time.get_ticks_usec() + 25000
		while Time.get_ticks_usec() < until:
			pass
	host.get_tree().process_frame.connect(burn)
	for _f in 12:
		await host.get_tree().process_frame
	host.get_tree().process_frame.disconnect(burn)
	var fc := ns.frames.summary(0.2)
	host._check(int(fc["frames"]) >= 3 and float(fc["mean_ms"]) >= 24.0 and float(fc["fps"]) <= 41.0,
		"frame times are wall-clock times (%d frames, %.1f ms, %.1f fps)" % [fc["frames"], fc["mean_ms"], fc["fps"]])
	host._check(float(fc["script_ms"]) >= 20.0 and float(fc["script_ms"]) <= float(fc["mean_ms"]) + 0.5,
		"and the busy wait is in the script part, inside the frame (%.1f of %.1f ms)" % [fc["script_ms"], fc["mean_ms"]])
	var held := Time.get_ticks_usec() + 60000
	while Time.get_ticks_usec() < held:
		pass
	await host.get_tree().process_frame
	await host.get_tree().process_frame
	host._check(int(ns.frames.summary(1.0)["hitches"]) >= 1, "a 60 ms frame is counted as a hitch")


static func _prediction(host: Selftest, ns: DotMenuNetStat) -> void:
	# Prediction counters, from whatever the net source returns, per second.
	var fake := FakeNetManager.new()
	ns.net_source = func() -> Object: return fake
	ns._net_marks.clear()
	ns._push(null)
	fake.counters[&"replayed_ticks"] = 600
	fake.counters[&"snapshots"] = 20
	fake.counters[&"lead_ticks"] = 4
	await host.get_tree().create_timer(0.25).timeout
	ns._push(null)
	var net: Dictionary = ns.describe()["net"]
	host._check(not net.is_empty() and float(net["replayed"]) > 600.0 and int(net["lead"]) == 4,
		"prediction cost is read from the manager's running totals, per second (%s)" % [net])
	ns.net_source = Callable()
	var px := int(ns.describe()["pixels_3d"])
	var win := host.get_window().size
	host._check(px == win.x * win.y, "the 3D pixel count is the window's device pixels at scale 1 (%d)" % px)
