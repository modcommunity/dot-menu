extends SceneTree

## Renders the touch menu at phone size (390x844) to screenshots/touch_*.png. Run under xvfb-run, as screenshot.gd.

const OUT := "res://screenshots"


func _initialize() -> void:
	DotPlatform.touch_override = 1
	root.size = Vector2i(390, 844)
	_run.call_deferred()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var demo := (load("res://examples/menu_demo.tscn") as PackedScene).instantiate()
	root.add_child(demo)
	await _frames(6)
	var menu: DotMenu = demo.get("menu")
	(demo.get("settings") as DotSettingsManager).reset_all()
	await _shot("touch_hud")
	menu.open(&"video")
	await _shot("touch_video")
	root.size = Vector2i(844, 390)
	await _shot("touch_video_landscape")
	quit(0)


func _shot(name: String) -> void:
	await _frames(4)
	var err := root.get_texture().get_image().save_png(ProjectSettings.globalize_path("%s/%s.png" % [OUT, name]))
	print("%s %s" % ["wrote" if err == OK else "FAILED", name])


func _frames(n: int) -> void:
	for i in n:
		await process_frame
