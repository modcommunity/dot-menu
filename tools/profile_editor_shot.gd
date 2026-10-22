extends SceneTree

## Renders DotProfileEditorScreen to screenshots/: desktop dark and light, phone.
##
##   xvfb-run -a godot --path . --resolution 1280x800 --script tools/profile_editor_shot.gd

const OUT := "res://screenshots"


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_run.call_deferred()


func _run() -> void:
	DotProfileEditorDemo.write_files()
	DotProfileSet.set_user_tier(true)
	await _scene("profile_editor_dark", Vector2i(1280, 800), DotFormTokens.dark())
	await _scene("profile_editor_light", Vector2i(1280, 800), DotFormTokens.light())
	await _scene("profile_editor_phone", Vector2i(420, 860), DotFormTokens.dark())
	DotProfileEditorDemo.clean()
	quit(0)


func _scene(name: String, size: Vector2i, tokens: DotFormTokens) -> void:
	root.get_window().size = size
	await _frames(3)
	tokens.animate = false
	var ed := DotProfileEditorScreen.new()
	ed.tokens = tokens
	ed.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(ed)
	for s in DotProfileEditorDemo.sets():
		ed.add_set(s, "NPCs" if s.rel_path == "npc" else "Weapons")
	await _frames(3)
	var _o := ed.open("npc", "zombie")
	await _frames(2)
	var _a := ed.form.set_value("health", 420)
	var _b := ed.apply()
	await _frames(1)
	var _c := ed.form.set_value("speed", 4.5)
	await _frames(4)
	var img := root.get_texture().get_image()
	img.save_png(ProjectSettings.globalize_path(OUT.path_join(name + ".png")))
	ed.queue_free()
	await _frames(2)


func _frames(n: int) -> void:
	for i in n:
		await process_frame
