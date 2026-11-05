extends RefCounted

const Selftest := preload("res://examples/menu_selftest.gd")

## Screens watch their viewport's size_changed only while in the tree.

static func run(host: Selftest) -> void:
	host._section("screens stop listening to size_changed when they leave the tree")
	var vp := SubViewport.new()
	vp.size = Vector2i(800, 600)
	host.add_child(vp)
	var screens := {
		"help": DotMenuHelp.new(),
		"loadout": DotMenuLoadoutScreen.new(),
		"team": DotMenuTeamScreen.new(),
	}
	for key in screens:
		var s := screens[key] as Control
		vp.add_child(s)
		await host.get_tree().process_frame
		var cb := Callable(s, "_on_size_changed" if key == "team" else "_fit")
		host._check(vp.size_changed.is_connected(cb), "%s listens while in the tree" % key)
		vp.remove_child(s)
		host._check(not vp.size_changed.is_connected(cb), "%s stops listening once removed" % key)
		vp.add_child(s)
		host._check(vp.size_changed.is_connected(cb), "%s listens again when re-added" % key)
		vp.remove_child(s)
		vp.size = Vector2i(640, 480)
		await host.get_tree().process_frame
		s.free()
		vp.size = Vector2i(700, 500)
		await host.get_tree().process_frame
	vp.queue_free()
