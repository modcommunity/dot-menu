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

	for page in [&"general", &"gameplay", &"video", &"audio", &"controls"]:
		menu.open(page)
		await _shot("menu_%s" % page)

	for theme_id in [&"ember", &"violet", &"classic", &"paper", &"contrast"]:
		var _t := settings.set_value(&"ui_theme", theme_id)
		menu.open(&"video")
		await _shot("theme_%s" % theme_id)
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

	menu.open_picker(_demo.call("maps"), "Change map — offline")
	await _shot("picker")
	menu.picker.close()

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

	var hud: Control = _demo.get("hud")
	menu.open_layout_editor(hud, {&"clock": "Clock", &"speed": "Speed"})
	menu.layout_editor.drag(&"clock", hud.call("element_rect", &"clock").get_center(), Vector2(260, 140))
	await _shot("layout_editor")
	menu.layout_editor.reset_all()
	menu.layout_editor.close()

	settings.reset_all()
	quit(0)


func _shot(name: String) -> void:
	await _frames(4)
	var img := root.get_texture().get_image()
	var path := "%s/%s.png" % [OUT, name]
	var err := img.save_png(ProjectSettings.globalize_path(path))
	print("%s %s" % ["wrote" if err == OK else "FAILED", path])


func _frames(n: int) -> void:
	for i in n:
		await process_frame
