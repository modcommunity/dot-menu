extends Node

## The yml layout of dot-menu's admin_menu.yml: new path, flat shim, operator layer.

const FOLDER := "dot_menu"
const LEGACY := "user://dot_menu_cfg_selftest_legacy"

var _passed := 0
var _failed := 0


func _ready() -> void:
	DotLog.set_level(DotLog.Level.ERROR)
	_run.call_deferred()


func _run() -> void:
	print("dot-menu cfg self-test")
	var addon_dir := "user://cfg/addons/" + FOLDER
	var server_dir := "user://cfg/server/addons/" + FOLDER
	_clean(addon_dir, server_dir)
	DotCfgLegacy.reset()

	_write(LEGACY.path_join("admin_menu.yml"), "title: old\n")
	var res := DotMenuCfg.load_admin_menu(LEGACY)
	_check(res.ok and (res.value as Dictionary).get("title") == "old", "only the flat file: it is still read")
	_check(DotCfgLegacy.warned_count() == 1, "and warned once")
	DotMenuCfg.load_admin_menu(LEGACY)
	_check(DotCfgLegacy.warned_count() == 1, "a second load does not warn again")

	_write(addon_dir.path_join("admin_menu.yml"), "title: new\nitems:\n  a: 1\n  b: 2\n")
	var tree: Dictionary = DotMenuCfg.load_admin_menu(LEGACY).value
	_check(tree.get("title") == "new", "the new path wins over the flat file")

	_write(server_dir.path_join("admin_menu.yml"), "items:\n  b: 9\n")
	tree = DotMenuCfg.load_admin_menu(LEGACY).value
	_check(tree["items"]["b"] == 9 and tree["items"]["a"] == 1, "the operator's server layer wins, key by key")

	_write(server_dir.path_join("admin_menu.yml"), "items: [broken\n")
	_check(not DotMenuCfg.load_admin_menu(LEGACY).ok, "a bad file fails")

	_clean(addon_dir, server_dir)
	DotCfgLegacy.reset()
	print("%d passed, %d failed" % [_passed, _failed])
	get_tree().quit(1 if _failed > 0 else 0)


func _clean(addon_dir: String, server_dir: String) -> void:
	DotPaths.remove_tree(addon_dir)
	DotPaths.remove_tree(server_dir)
	DotPaths.remove_tree(LEGACY)


func _write(path: String, text: String) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()


func _check(condition: bool, what: String) -> void:
	if condition:
		_passed += 1
		print("   ok   ", what)
	else:
		_failed += 1
		print("  FAIL  ", what)
