extends Node

## Exercises [DotProfileEditorScreen]: listing, opening, applying to the user tier, reset, a custom target.

const SECTIONS := 5
const CHECKS := 27

var _passed := 0
var _failed := 0
var _section_count := 0


func _ready() -> void:
	DotLog.set_level(DotLog.Level.FATAL)
	_run.call_deferred()


func _run() -> void:
	_line("dot-menu profile editor self-test")
	await _test_listing()
	await _test_open_and_apply()
	await _test_reset()
	await _test_custom_target()
	await _test_failures()
	DotProfileEditorDemo.clean()
	DotProfileSet.set_user_tier(false)
	_line("")
	_line("%d sections, %d passed, %d failed" % [_section_count, _passed, _failed])
	if _section_count != SECTIONS or _passed + _failed != CHECKS:
		_line("ERROR: %d sections, %d checks ran; expected %d and %d." % [_section_count, _passed + _failed, SECTIONS, CHECKS])
		get_tree().quit(1)
		return
	get_tree().quit(1 if _failed > 0 else 0)


func _editor(width: float = 1000.0) -> DotProfileEditorScreen:
	DotProfileEditorDemo.write_files()
	DotProfileSet.set_user_tier(true)
	var ed := DotProfileEditorScreen.new()
	ed.tokens.animate = false
	ed.custom_minimum_size = Vector2(width, 600)
	ed.size = Vector2(width, 600)
	add_child(ed)
	for s in DotProfileEditorDemo.sets():
		ed.add_set(s, "NPCs" if s.rel_path == "npc" else "Weapons")
	return ed


func _test_listing() -> void:
	_section("Listing kinds and ids")
	var ed := _editor()
	await get_tree().process_frame
	_check(ed.kinds() == PackedStringArray(["npc", "weapon"]), "kinds in the order added")
	_check(ed.ids("npc") == PackedStringArray(["runner", "spitter", "zombie"]), "npc ids are sorted from the set")
	_check(ed.ids("weapon").size() == 2 and ed.ids("nothing").is_empty(), "weapon ids; an unknown kind is empty")
	_check(_count_buttons(ed) >= 5, "the sidebar has a button per id")
	_check(not ed.open("ghost", "x").ok and not ed.open("npc", "ghost").ok, "unknown kind and id fail")
	ed.queue_free()


func _test_open_and_apply() -> void:
	_section("Open, edit, apply to the user tier")
	var ed := _editor()
	await get_tree().process_frame
	var saved: Array = []
	ed.saved.connect(func(k: String, i: String, c: Dictionary) -> void: saved.append([k, i, c]))
	_check(ed.open("npc", "zombie").ok and ed.form != null, "a profile opens in a form")
	_check(ed.form.values()["health"] == 150 and ed.form.values()["name"] == "Zombie", "the form holds the effective values")
	_check(not ed.form.is_dirty(), "nothing is dirty at first")
	var _r := ed.form.set_value("health", 420)
	_check(ed.form.is_dirty() and ed.form.changes() == {"health": 420}, "an edit is a change")
	_check(ed.apply().ok, "apply passes")
	_check(saved.size() == 1 and saved[0][2] == {"health": 420}, "saved is emitted with the changes")
	var set: DotProfileSet = ed._sets["npc"]
	_check(FileAccess.file_exists(set.user_file("zombie")) and set.user_paths("zombie") == {"health": 420}, "the user file holds just that key")
	_check(set.load_profile("zombie").value.get_value("health") == 420, "the profile now reads it")
	ed.queue_free()


func _test_reset() -> void:
	_section("Reset to defaults removes the user file")
	var ed := _editor()
	await get_tree().process_frame
	ed.open("npc", "zombie")
	_check(ed._reset_btn.disabled, "reset is off while there is nothing saved")
	var _r := ed.form.set_value("speed", 6.5)
	ed.apply()
	_check(not ed._reset_btn.disabled, "reset turns on once something is saved")
	var set: DotProfileSet = ed._sets["npc"]
	_check(ed.reset_profile().ok and not FileAccess.file_exists(set.user_file("zombie")), "reset deletes the file")
	_check(ed.form.values()["speed"] == 2.5 and not ed.form.is_dirty(), "the form shows the lower tiers again")
	ed.queue_free()


func _test_custom_target() -> void:
	_section("The save target is a callable")
	var ed := _editor()
	await get_tree().process_frame
	var log: Array = []
	ed.save_target = func(set: DotProfileSet, id: String, changes: Dictionary) -> DotResult:
		log.append([set.rel_path, id, changes])
		return DotResult.success(null)
	ed.reset_target = func(_s: DotProfileSet, id: String) -> DotResult:
		log.append(["reset", id])
		return DotResult.success(null)
	ed.has_override = func(_s: DotProfileSet, _i: String) -> bool: return true
	ed.open("weapon", "rifle")
	var _r := ed.form.set_value("damage", 31.0)
	ed.apply()
	_check(log.size() == 1 and log[0] == ["weapon", "rifle", {"damage": 31.0}], "apply calls the callable, not the user tier")
	_check(not FileAccess.file_exists((ed._sets["weapon"] as DotProfileSet).user_file("rifle")), "so no user file was written")
	_check(not ed._reset_btn.disabled, "has_override decides the reset button")
	ed.reset_profile()
	_check(log.size() == 2 and log[1] == ["reset", "rifle"], "reset calls its callable")
	ed.queue_free()


func _test_failures() -> void:
	_section("A refused save keeps the edit; compact layout builds")
	var ed := _editor()
	await get_tree().process_frame
	DotProfileSet.set_user_tier(false)
	ed.open("npc", "runner")
	var _r := ed.form.set_value("health", 77)
	var res := ed.apply()
	_check(res.ok, "the form itself applied")
	_check(ed.form.changes() == {"health": 77} and ed.form.is_dirty(), "a refused save leaves the edit pending")
	_check(ed._note.visible and ed._note.text.contains("off"), "the reason is shown")
	_check(not FileAccess.file_exists((ed._sets["npc"] as DotProfileSet).user_file("runner")), "nothing was written")
	ed.queue_free()
	var small := _editor(420.0)
	await get_tree().process_frame
	await get_tree().process_frame
	_check(small._compact and small._kind_pick != null, "a narrow screen uses dropdowns")
	_check(small.open("weapon", "pistol").ok and small._id_pick.get_item_text(small._id_pick.selected) == "pistol", "and the dropdown follows open")
	small.queue_free()


func _count_buttons(n: Node) -> int:
	var c := 1 if n is Button else 0
	for k in n.get_children():
		c += _count_buttons(k)
	return c


func _section(title: String) -> void:
	_section_count += 1
	_line("")
	_line("== %s ==" % title)


func _check(condition: bool, what: String) -> void:
	if condition:
		_passed += 1
		_line("   ok   %s" % what)
	else:
		_failed += 1
		_line("  FAIL  %s" % what)


func _line(text: String) -> void:
	print(text)
