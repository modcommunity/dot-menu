extends RefCounted

const Selftest := preload("res://examples/menu_selftest.gd")

## A game's settings as a [DotMenuGameSpec]: the document, key table, Comfort row and help screen it declares, run from menu_selftest.

static func _spec() -> DotMenuGameSpec:
	var spec := DotMenuGameSpec.new()
	spec.brand_name = "Spec Run"
	spec.settings_dir = "user://spec_run_settings"
	spec.app_namespace = &"spec_run"
	spec.default_fov = 80
	spec.fov_min = 60
	spec.reduce_motion_text = "Nothing slides."
	spec.comfort_row_text = "Nothing slides in."
	spec.ambient_text = "Quiet sounds."
	spec.not_applied = [&"ui_volume", &"voice_volume"] as Array[StringName]
	spec.bindings_maker = func() -> DotMenuBindings: return DotMenuBindings.new().add_movement()
	spec.help_hint = &"off"
	spec.help_about = "Get across."
	spec.help_cards = [["Rules", "First across wins."]]
	spec.help_sections = [["Mouse", [["Left", "Fire"]], &"keys"]]
	return spec


static func run(host: Selftest) -> void:
	host._section("A game's settings menu is a spec")

	var spec := _spec()
	var schema := spec.make_schema()
	var fov := schema.find(&"field_of_view")
	host._check(fov != null and fov.default_value == 80 and fov.min_value == 60 and fov.scope == DotSettingsDef.Scope.SERVER_CLAMPED,
		"the field of view keeps the game's default and range, and a server may only clamp it")
	host._check(schema.has(&"reduce_motion") and schema.find(&"reduce_motion").scope == DotSettingsDef.Scope.ACCOUNT,
		"reduce_motion is the game's own, per account")
	host._check(schema.has(&"ambient") and schema.has(&"ambient_volume") and schema.has(&"sfx_volume"),
		"the ambient pair and the stock volumes are there")
	host._check(not schema.has(&"ui_volume") and not schema.has(&"voice_volume"), "and the stock keys the game leaves out are not")
	spec.ambient_text = ""
	host._check(not spec.make_schema().has(&"ambient"), "no ambient text, no ambient settings")
	spec.ambient_text = "Quiet sounds."

	var node := DotMenuGameSettings.new(spec)
	host._check(node.name == "Settings" and node.directory == "user://spec_run_settings" and node.app_namespace == &"spec_run",
		"the node takes its name, directory and namespace from the spec")
	host._check(node.config.brand_name == "Spec Run" and node.config.help_hint == &"off", "and the brand and help hint")
	host._check(node.bindings.groups().size() > 0, "and the key table the spec makes")
	host.add_child(node)
	var res := node.setup(DotSettingsStoreMemory.new())
	host._check(res.ok and node.menu != null, "it sets up like the base class")
	host._check(not node.bindings.row_for_action(DotMenuBindings.HELP_ACTION).is_empty(), "with the stock help key added to the spec's table")
	node.open()
	await host.get_tree().process_frame
	host._check(host._texts(node.menu.screen).has("Nothing slides in."),
		"the Comfort row is on the General page")
	node.close()
	node.menu.help.open()
	await host.get_tree().process_frame
	var texts := host._texts(node.menu.help)
	host._check(texts.has("Get across.") and texts.has("RULES") and texts.has("First across wins.") and texts.has("MOUSE"),
		"the help screen has the goal, the card and the section")
	node.menu.help.close()
	node.queue_free()
	await host.get_tree().process_frame

	var bare := DotMenuGameSettings.new()
	host._check(bare.spec == null and bare.schema == null, "with no spec it is the base class, ready to be configured by hand")
	bare.free()
