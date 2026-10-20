extends SceneTree

## Renders the demo's every screen to screenshots/, in several themes.
##
##   tools/screenshot.sh
##
## Run under xvfb-run, not --headless: a headless run has a null renderer and every frame it
## saves is empty, which is worse than no picture because it looks like one.

const OUT := "res://screenshots"

var _demo: Node = null


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_run.call_deferred()


func _run() -> void:
	_demo = (load("res://examples/menu_demo.tscn") as PackedScene).instantiate()
	root.add_child(_demo)
	await _frames(6)

	var menu: DotMenu = _demo.get("menu")
	var settings: DotSettingsManager = _demo.get("settings")
	# Fresh every run, so the pictures do not depend on what the last one left on disk.
	settings.reset_all()
	await _frames(2)

	await _shot("hud")

	for page in [&"general", &"gameplay", &"video", &"audio", &"controls", &"advanced"]:
		menu.open(page)
		await _shot("menu_%s" % page)

	for theme_id in [&"ember", &"violet", &"classic", &"paper", &"contrast"]:
		var _t := settings.set_value(&"ui_theme", theme_id)
		menu.open(&"video")
		await _shot("theme_%s" % theme_id)
		if theme_id == &"paper":
			menu.close()
			menu.open_help(null, false)
			await _shot("help_paper")
			menu.help.close()
	var _m := settings.set_value(&"ui_theme", &"midnight")

	# A server that caps the view, hides a row and turns the flashlight off.
	_demo.set("server_allows_flashlight", false)
	var _fov := settings.set_value(&"field_of_view", 110)
	var _rules := menu.apply_server_rules({"clamps": {"field_of_view": 95}, "rows_hidden": ["render_scale"], "leave_text": "Disconnect"})
	menu.open(&"video")
	await _shot("server_video")
	menu.open(&"gameplay")
	await _shot("server_gameplay")
	menu.release_server_rules()
	_demo.set("server_allows_flashlight", true)

	# A key listening for its next press.
	menu.open(&"controls")
	await _frames(2)
	var listen := menu.screen.find_child("Row_bind_jump", true, false) as DotMenuKeyButton
	if listen != null:
		listen.listen()
	await _shot("controls_listening")
	if listen != null:
		listen.listening = false
	menu.close()

	menu.help.show_browser_tips = true
	menu.open_help([["rtv", "Vote to change the map"], ["nominate", "Put a map on the next vote"], ["r", "Restart your run"], ["spec", "Watch somebody"]], true)
	await _shot("help")
	menu.help.close()

	menu.open_maps()
	await _shot("picker")
	menu.picker.close()
	menu.maps.open_rows(_demo.call("maps"), false, "this server", "generic", true)
	await _shot("maps_vote")
	menu.picker.close()
	menu.toast("Nominated Foundry. Rocked: 1 of 3.")
	await _shot("maps_toast")

	var offer: Dictionary = _demo.call("loadout_offer")
	var _lo := menu.use_loadout(func() -> Dictionary: return offer, func(_p: Dictionary) -> Dictionary:
		return {"ok": true, "text": "Loadout saved: you get it when you next spawn."})
	menu.open_loadout()
	await _shot("loadout")
	menu.loadout_screen.card_index = 5
	var _over := menu.loadout_screen.pick(7)
	await _shot("loadout_budget")
	var _pt := settings.set_value(&"ui_theme", &"paper")
	await _frames(2)
	menu.loadout_screen.show_slot(1)
	await _shot("loadout_paper")
	var _mt := settings.set_value(&"ui_theme", &"midnight")
	menu.loadout_screen.close()
	await _shot("loadout_toast")
	root.get_window().size = Vector2i(854, 480)
	menu.open_loadout()
	await _frames(3)
	await _shot("loadout_854x480")
	menu.loadout_screen.cancel()
	root.get_window().size = Vector2i(1600, 900)
	await _frames(3)

	menu.scoreboard.open()
	await _shot("scoreboard_teams")
	menu.scoreboard.close()
	menu.scoreboard.source = func() -> Dictionary:
		var r: Dictionary = _demo.call("roster")
		r.erase("teams")
		r["server"]["name"] = "Surf Timer  |  Tier 1-3"
		r["header"] = {"Next map": "surf_intro"}
		return r
	var _p := settings.set_value(&"ui_theme", &"paper")
	menu.scoreboard.open()
	await _shot("scoreboard_paper")
	menu.scoreboard.close()
	var _m2 := settings.set_value(&"ui_theme", &"midnight")
	menu.scoreboard.source = Callable(_demo.get_script(), &"roster")
	var _hide := settings.set_value(&"scoreboard_hidden", "deaths,seconds")
	menu.open(&"general")
	await _frames(2)
	await _shot("menu_scoreboard_columns")
	menu.close()
	menu.scoreboard.open()
	await _shot("scoreboard_columns_hidden")
	menu.scoreboard.close()
	var _show := settings.set_value(&"scoreboard_hidden", "")

	var hud: Control = _demo.get("hud")
	menu.open_layout_editor(hud, {&"clock": "Clock", &"speed": "Speed"})
	menu.layout_editor.drag(&"clock", hud.call("element_rect", &"clock").get_center(), Vector2(260, 140))
	await _shot("layout_editor")
	menu.layout_editor.reset_all()
	menu.layout_editor.close()

	await _net_stat_shots(menu, settings)

	settings.reset_all()
	quit(0)


## net_stat over three seconds of made-up traffic shaped like a real client's: a snapshot
## on the state channel every other frame, the odd control and event packet, a content
## burst, and a ping that wanders and spikes once. Real time, because the overlay buckets
## by the clock.
func _net_stat_shots(menu: DotMenu, settings: DotSettingsManager) -> void:
	var meter := ShotMeter.new()
	menu.net_stat.source = func() -> Object: return meter
	var net := ShotNet.new()
	meter.net = net
	menu.net_stat.net_source = func() -> Object: return net
	var _two := settings.set_value(&"net_stat", 2)
	await _traffic(meter, 3.2)
	await _shot("net_stat_2")

	var _three := settings.set_value(&"net_stat", 3)
	await _traffic(meter, 1.0)
	await _shot("net_stat_3")

	var _h := settings.set_value(&"net_stat_height", 200)
	var _c := settings.set_value(&"net_stat_position", &"bottom_left")
	var _p := settings.set_value(&"ui_theme", &"paper")
	meter.transport = "websocket"
	await _traffic(meter, 1.0)
	await _shot("net_stat_3_tall_paper_websocket")

	var _one := settings.set_value(&"net_stat", 1)
	var _tr := settings.set_value(&"net_stat_position", &"bottom_right")
	var _m := settings.set_value(&"ui_theme", &"midnight")
	await _shot("net_stat_1")
	var _off := settings.set_value(&"net_stat", 0)


func _traffic(meter: ShotMeter, seconds: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var until := Time.get_ticks_msec() + int(seconds * 1000.0)
	var n := 0
	while Time.get_ticks_msec() < until:
		n += 1
		var ch := 0 if meter.transport == "websocket" else 1
		if n % 2 == 0:
			meter.arrive(ch, rng.randi_range(380, 1100))
		if n % 9 == 0:
			meter.arrive(0, rng.randi_range(40, 160))
		if n % 23 == 0:
			meter.arrive(0 if meter.transport == "websocket" else 2, rng.randi_range(200, 900))
		if n % 70 == 35:
			for k in 6:
				meter.arrive(0 if meter.transport == "websocket" else 3, 1200)
		meter.leave(rng.randi_range(0, 1), rng.randi_range(60, 140))
		# Over WebSocket the ping is a heartbeat, a sample every so often held between, which
		# is what the line's sample dots are for; ENet's is fresh every frame.
		if meter.transport != "websocket" or n % 45 == 0:
			meter.note_rtt(42.0 + 9.0 * sin(float(n) * 0.07) + (70.0 if n % 120 > 110 else 0.0))
		if meter.net != null:
			meter.net.frame(n)
		# The odd slow frame, so the frame strip has something to stack.
		if n % 40 == 20:
			var held := Time.get_ticks_usec() + 22000
			while Time.get_ticks_usec() < held:
				pass
		await process_frame


## A meter with a transport to name, for a picture: the real one asks the peer under it.
class ShotMeter extends DotMeteredPeer:
	var transport := "enet"
	var net: ShotNet = null

	func transport_name() -> String:
		return transport

	func transport_stats() -> Dictionary:
		return {"rtt_ms": rtt_ms, "rtt_var_ms": 4.0, "loss": 0.006, "throttle": 1.0} if transport == "enet" else {"queued": 0}

	func arrive(ch: int, n: int) -> void:
		bytes_in_by_channel[ch] += n
		bytes_in += n
		packets_in += 1
		largest_in = maxi(largest_in, n)

	func leave(ch: int, n: int) -> void:
		bytes_out_by_channel[ch] += n
		bytes_out += n
		packets_out += 1


func _shot(name: String) -> void:
	await _frames(4)
	var img := root.get_texture().get_image()
	var path := "%s/%s.png" % [OUT, name]
	var err := img.save_png(ProjectSettings.globalize_path(path))
	print("%s %s" % ["wrote" if err == OK else "FAILED", path])


func _frames(n: int) -> void:
	for i in n:
		await process_frame


## A dot-net manager's running totals, advanced a frame at a time like a client at 60 Hz
## with a four-tick lead.
class ShotNet extends RefCounted:
	var is_server := false
	var c := {&"snapshots": 0, &"snapshot_usec": 0, &"reconciles": 0, &"reconcile_usec": 0,
		&"replayed_ticks": 0, &"client_ticks": 0, &"predict_usec": 0, &"lead_ticks": 4}

	func frame(n: int) -> void:
		c[&"client_ticks"] += 1
		c[&"predict_usec"] += 90
		if n % 2 == 0:
			c[&"snapshots"] += 1
			c[&"snapshot_usec"] += 160
			c[&"reconciles"] += 1
			c[&"reconcile_usec"] += 420
			c[&"replayed_ticks"] += 4

	func perf_counters() -> Dictionary:
		return c.duplicate()
