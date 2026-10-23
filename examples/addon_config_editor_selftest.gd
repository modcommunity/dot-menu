extends Node

## Exercises [DotAddonConfigEditorScreen]: open, apply to the user tier, reset, tier off, unknown file.
##
## [codeblock]
## godot --headless --path . res://examples/addon_config_editor_selftest.tscn
## [/codeblock]

const SECTIONS := 6
const CHECKS := 29
const ADDON := "solo-demo"

var _passed := 0
var _failed := 0
var _section_count := 0


func _ready() -> void:
	DotLog.set_level(DotLog.Level.FATAL)
	_run.call_deferred()


func _run() -> void:
	_line("dot-menu addon config editor self-test")
	await _test_open_and_apply()
	await _test_reset()
	await _test_tier_off()
	await _test_failures()
	await _test_undo()
	await _test_escape_port()
	clean()
	DotAddonConfig.set_user_tier(false)
	_line("")
	_line("%d sections, %d passed, %d failed" % [_section_count, _passed, _failed])
	if _section_count != SECTIONS or _passed + _failed != CHECKS:
		_line("ERROR: %d sections, %d checks ran; expected %d and %d." % [_section_count, _passed + _failed, SECTIONS, CHECKS])
		get_tree().quit(1)
		return
	get_tree().quit(1 if _failed > 0 else 0)


static func schema() -> Array:
	return [
		DotProfileSet.field("volume", "float", 1.0, {"min": 0.0, "max": 2.0, "group": "Sound", "unit": "x", "description": "Master gain of the demo."}),
		DotProfileSet.field("voices", "int", 8, {"min": 1, "max": 64, "group": "Sound"}),
		DotProfileSet.field("mode", "string", "normal", {"enum": ["quiet", "normal", "loud"], "group": "Sound"}),
		DotProfileSet.field("subtitles", "bool", false, {"group": "Accessibility", "description": "Draw captions."}),
		DotProfileSet.field("caption_size", "int", 18, {"min": 10, "max": 48, "group": "Accessibility", "unit": "px"}),
	]


static func write_files() -> void:
	clean()
	var dir := DotAddonConfig.write_dir_for(ADDON)
	DirAccess.make_dir_recursive_absolute(dir)
	var f := FileAccess.open(dir.path_join("tuning.yml"), FileAccess.WRITE)
	f.store_string("volume: 0.8\nvoices: 16\n")
	f.close()


static func clean() -> void:
	for dir in [DotAddonConfig.write_dir_for(ADDON), DotAddonConfig.user_dir_for(ADDON)]:
		if DirAccess.dir_exists_absolute(dir):
			for f in DirAccess.get_files_at(dir):
				DirAccess.remove_absolute(dir.path_join(f))
			DirAccess.remove_absolute(dir)


func _editor() -> DotAddonConfigEditorScreen:
	write_files()
	DotAddonConfig.set_user_tier(true)
	var ed := DotAddonConfigEditorScreen.new()
	ed.tokens.animate = false
	ed.custom_minimum_size = Vector2(1000, 600)
	ed.size = Vector2(1000, 600)
	add_child(ed)
	ed.add_file(ADDON, "tuning.yml", schema(), "Sound and captions")
	return ed


func _test_open_and_apply() -> void:
	_section("Open and apply")
	var ed := _editor()
	await get_tree().process_frame
	_check(ed.open(ADDON, "tuning.yml").ok, "opening an added file works")
	_check(ed.form != null and ed.form.values()["voices"] == 16, "the form shows the shipped value")
	_check(ed.form.values()["subtitles"] == false, "a key the file lacks shows the schema default")
	var _a := ed.form.set_value("volume", 1.5)
	var _b := ed.form.set_value("subtitles", true)
	var res := ed.apply()
	await get_tree().process_frame
	_check(res.ok, "apply succeeds")
	var paths := DotAddonConfig.user_paths(ADDON, "tuning.yml")
	_check(paths.get("volume") == 1.5 and paths.get("subtitles") == true, "only the changes reach the user file")
	_check(not paths.has("voices"), "an untouched key is not copied into the user file")
	var cfg := DotAddonConfig.load_dir(ADDON, {})
	_check(cfg.ok and cfg.value["volume"] == 1.5 and cfg.value["voices"] == 16, "the game's loader sees the override over the shipped file")
	ed.queue_free()


func _test_reset() -> void:
	_section("Reset")
	var ed := _editor()
	await get_tree().process_frame
	var _o := ed.open(ADDON, "tuning.yml")
	var _a := ed.form.set_value("volume", 1.9)
	var _p := ed.apply()
	var btn: Button = ed._reset_btn
	_check(not btn.disabled, "reset is enabled once a user file exists")
	var res := ed.reset_file()
	_check(res.ok and not FileAccess.file_exists(DotAddonConfig.user_file(ADDON, "tuning.yml")), "reset deletes the user file")
	_check(is_equal_approx(ed.form.values()["volume"], 0.8), "the form shows the shipped value again")
	_check(btn.disabled, "reset is disabled with nothing to reset")
	ed.queue_free()


func _test_tier_off() -> void:
	_section("Tier off (a server or a connected client)")
	var ed := _editor()
	await get_tree().process_frame
	var _o := ed.open(ADDON, "tuning.yml")
	DotAddonConfig.set_user_tier(false)
	var _a := ed.form.set_value("voices", 32)
	var res := ed.apply()
	await get_tree().process_frame
	_check(not DotAddonConfig.user_paths(ADDON, "tuning.yml").has("voices"), "nothing is written while the tier is off")
	_check(res.ok, "the form accepts its own apply; the tier refuses the write")
	DotAddonConfig.set_user_tier(true)
	var cfg := DotAddonConfig.load_dir(ADDON, {})
	DotAddonConfig.set_user_tier(false)
	_check(cfg.value["voices"] == 16, "the loader stays on the shipped value")
	ed.queue_free()


func _test_failures() -> void:
	_section("Failures")
	var ed := _editor()
	await get_tree().process_frame
	var res := ed.open("nope", "x.yml")
	_check(not res.ok and res.error.code == DotError.CODE_INVALID, "an unknown file is CODE_INVALID")
	_check(not ed.apply().ok and not ed.reset_file().ok, "apply and reset with nothing open fail")
	_check(ed.describe().contains("1 files"), "describe counts the files")
	ed.queue_free()


func _test_undo() -> void:
	_section("Undo")
	var ed := _editor()
	await get_tree().process_frame
	_check(not ed.undo().ok, "undo with no file open fails")
	var _o := ed.open(ADDON, "tuning.yml")
	_check(not ed.undo().ok and ed._undo_btn.disabled, "undo with no edit fails and the button is off")
	var _a := ed.form.set_value("voices", 32)
	var _b := ed.form.set_value("voices", 40)
	var _c := ed.form.set_value("subtitles", true)
	_check(ed.undo_depth() == 3 and not ed._undo_btn.disabled, "each edit is a step")
	_check(ed.undo().ok and ed.form.values()["subtitles"] == false, "undo takes back the last edit")
	_check(ed.undo().ok and ed.form.values()["voices"] == 32, "undo steps back one edit, not to the file")
	_check(ed.undo().ok and ed.form.values()["voices"] == 16 and not ed.form.is_dirty(), "the first edit undone leaves the form clean")
	_check(ed.undo_depth() == 0 and ed._undo_btn.disabled, "the history is empty")
	ed.queue_free()


func _test_escape_port() -> void:
	_section("Escape menu port")
	var ed := _editor()
	var menu := DotMenu.new()
	add_child(menu)
	menu.settings = null
	var _s := menu.setup()
	menu.use_mods(ed)
	await get_tree().process_frame
	var _o := ed.open(ADDON, "tuning.yml")
	_check(not ed.is_open(), "the editor starts hidden under the menu")
	_check(menu.screen.find_child("Action_mods", true, false) != null, "Escape gets a Mods action")
	menu._on_action(&"mods")
	_check(ed.is_open() and menu.any_open(), "the action opens the editor as an overlay")
	menu.close_all()
	_check(not ed.is_open(), "close_all (Escape) closes it")
	var themed := menu.use_theme(&"contrast")
	_check(themed and ed.get_parent() == menu, "a theme change with the mods editor registered restyles without error")
	menu.open_mods()
	ed._close_btn.pressed.emit()
	_check(not ed.is_open(), "its Close button closes it")
	menu.queue_free()


func _section(title: String) -> void:
	_section_count += 1
	_line("")
	_line("-- %s" % title)


func _check(condition: bool, what: String) -> void:
	if condition:
		_passed += 1
		_line("   ok   %s" % what)
	else:
		_failed += 1
		_line("  FAIL  %s" % what)


func _line(text: String) -> void:
	print(text)
