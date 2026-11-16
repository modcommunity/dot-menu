extends SceneTree

## Renders the pause menu and a settings page in the Gamespice theme at desktop (1280x720) and phone
## sizes (390x844, 844x390, as a touch screen) to screenshots/gamespice_*.png. Run under xvfb-run, as screenshot.gd.

const OUT := "res://screenshots"
const SIZES: Array[Vector2i] = [Vector2i(1280, 720), Vector2i(390, 844), Vector2i(844, 390)]


func _initialize() -> void:
	root.size = SIZES[0]
	_run.call_deferred()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var demo := (load("res://examples/menu_demo.tscn") as PackedScene).instantiate()
	root.add_child(demo)
	await _frames(6)
	var menu: DotMenu = demo.get("menu")
	var settings: DotSettingsManager = demo.get("settings")
	settings.reset_all()
	var _t := settings.set_value(&"ui_theme", &"gamespice")
	for s in SIZES:
		# A phone is a touch screen; the desktop frame is drawn for keyboard and gamepad.
		DotPlatform.touch_override = 1 if s.x < 1000 else 0
		root.size = s
		await _frames(3)
		menu.open(&"general")
		await _shot("gamespice_pause_%dx%d" % [s.x, s.y])
		menu.open(&"video")
		# Keyboard focus on a slider, to show the ring a gamepad player follows.
		var row := menu.screen.find_child("Row_field_of_view", true, false)
		var sliders: Array[Node] = row.find_children("*", "HSlider", true, false) if row != null else []
		if not sliders.is_empty() and s.x >= 1000:
			(sliders[0] as Control).grab_focus()
		await _shot("gamespice_settings_%dx%d" % [s.x, s.y])
		menu.close()
	settings.reset_all()
	quit(0)


func _shot(name: String) -> void:
	await _frames(4)
	var err := root.get_texture().get_image().save_png(ProjectSettings.globalize_path("%s/%s.png" % [OUT, name]))
	print("%s %s" % ["wrote" if err == OK else "FAILED", name])


func _frames(n: int) -> void:
	for i in n:
		await process_frame
