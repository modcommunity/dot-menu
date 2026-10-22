extends SceneTree

## Renders DotAddonConfigEditorScreen to screenshots/: desktop dark and phone.
##
##   xvfb-run -a godot --path . --resolution 1280x800 --script tools/addon_config_editor_shot.gd

const OUT := "res://screenshots"
const Selftest := preload("res://examples/addon_config_editor_selftest.gd")


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_run.call_deferred()


func _run() -> void:
	Selftest.write_files()
	DotAddonConfig.set_user_tier(true)
	await _scene("addon_config_editor_dark", Vector2i(1280, 800), DotFormTokens.dark())
	await _scene("addon_config_editor_phone", Vector2i(420, 860), DotFormTokens.dark())
	Selftest.clean()
	quit(0)


func _scene(name: String, size: Vector2i, tokens: DotFormTokens) -> void:
	root.get_window().size = size
	await _frames(3)
	tokens.animate = false
	var ed := DotAddonConfigEditorScreen.new()
	ed.tokens = tokens
	ed.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(ed)
	ed.add_file(Selftest.ADDON, "tuning.yml", Selftest.schema(), "Sound and captions")
	await _frames(3)
	var _o := ed.open(Selftest.ADDON, "tuning.yml")
	await _frames(2)
	var _a := ed.form.set_value("volume", 1.5)
	var _b := ed.apply()
	await _frames(1)
	var _c := ed.form.set_value("caption_size", 24)
	await _frames(4)
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT.path_join(name + ".png")))
	ed.queue_free()
	await _frames(2)


func _frames(n: int) -> void:
	for i in n:
		await process_frame
