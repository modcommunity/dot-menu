class_name DotProfileEditorDemo
extends RefCounted

## Profile sets with a few files on disk, for the editor's self-test and screenshots.

const BASE := "user://profile_editor_demo"


static func sets() -> Array:
	return [_npc(), _weapon()]


static func _npc() -> DotProfileSet:
	var s := DotProfileSet.create("demo", "demogame", "npc", [
		DotProfileSet.field("health", "int", 100, {"min": 1, "max": 1000, "group": "Body", "unit": "hp", "description": "Hit points at spawn."}),
		DotProfileSet.field("speed", "float", 3.0, {"min": 0.0, "max": 12.0, "group": "Body", "unit": "m/s", "description": "Walking speed."}),
		DotProfileSet.field("mode", "string", "melee", {"enum": ["melee", "ranged"], "group": "Behaviour"}),
		DotProfileSet.field("boss", "bool", false, {"group": "Behaviour", "description": "Draws a health bar for everyone."}),
		DotProfileSet.field("name", "string", "Unnamed", {"group": "Behaviour"}),
		DotProfileSet.field("tint", "string", "#a04040", {"group": "Look"}),
	])
	s.roots = PackedStringArray([BASE])
	s.user_root = BASE
	return s


static func _weapon() -> DotProfileSet:
	var s := DotProfileSet.create("demo", "demogame", "weapon", [
		DotProfileSet.field("damage", "float", 20.0, {"min": 0.0, "max": 500.0, "group": "Damage", "unit": "hp"}),
		DotProfileSet.field("rate", "float", 6.0, {"min": 0.1, "max": 30.0, "group": "Damage", "unit": "/s"}),
		DotProfileSet.field("magazine", "int", 12, {"min": 1, "max": 200, "group": "Ammo"}),
		DotProfileSet.field("automatic", "bool", false, {"group": "Ammo"}),
	])
	s.roots = PackedStringArray([BASE])
	s.user_root = BASE
	return s


static func write_files() -> void:
	clean()
	var files := {
		"addons/demo/npc/zombie.yml": "health: 150\nspeed: 2.5\nname: Zombie\n",
		"addons/demo/npc/runner.yml": "health: 60\nspeed: 7\n",
		"addons/demo/npc/spitter.yml": "health: 90\nmode: ranged\n",
		"addons/demo/weapon/pistol.yml": "damage: 24\nmagazine: 15\n",
		"addons/demo/weapon/rifle.yml": "damage: 18\nrate: 11\nmagazine: 30\nautomatic: true\n",
	}
	for f in files:
		var path := BASE.path_join(f)
		DirAccess.make_dir_recursive_absolute(path.get_base_dir())
		var fa := FileAccess.open(path, FileAccess.WRITE)
		fa.store_string(files[f])
		fa.close()


static func clean() -> void:
	_rm(BASE)


static func _rm(dir: String) -> void:
	if not DirAccess.dir_exists_absolute(dir):
		return
	for f in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir.path_join(f))
	for d in DirAccess.get_directories_at(dir):
		_rm(dir.path_join(d))
	DirAccess.remove_absolute(dir)
