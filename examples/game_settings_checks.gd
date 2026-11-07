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
	spec.gore_text = "Blood."
	spec.open_on_pointer_release = false
	spec.not_applied = [&"ui_volume", &"voice_volume"] as Array[StringName]
	spec.bindings_maker = func() -> DotMenuBindings: return DotMenuBindings.new().add_movement()
	spec.help_hint = &"off"
	spec.menu_button_corner = &"top_left"
	spec.help_about = "Get across."
	spec.help_cards = [["Rules", "First across wins."]]
	spec.help_sections = [["Mouse", [["Left", "Fire"]], &"keys"]]
	return spec


static func run(host: Selftest) -> void:
	await run_hooks(host)
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
	host._check(schema.has(&"gore") and schema.find(&"gore").default_value == true, "gore is declared when the spec has blood")
	spec.gore_text = ""
	host._check(not spec.make_schema().has(&"gore"), "and not when it has none")
	spec.gore_text = "Blood."

	var node := DotMenuGameSettings.new(spec)
	host._check(node.name == "Settings" and node.directory == "user://spec_run_settings" and node.app_namespace == &"spec_run",
		"the node takes its name, directory and namespace from the spec")
	host._check(node.config.brand_name == "Spec Run" and node.config.help_hint == &"off", "and the brand and help hint")
	host._check(node.config.menu_button_corner == &"top_left", "and the corner of the menu button")
	host._check(not node.config.open_on_pointer_release, "and whether a lost pointer lock opens the menu")
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


## The hooks: extra settings and rows, a page, a migration, a view transform, a pre-setup hook, a config override.
static func run_hooks(host: Selftest) -> void:
	host._section("A spec's hooks")
	var spec := _spec()
	spec.schema_version = 2
	spec.extra_defs = [DotSettingsDef.integer(&"crowd", 1, 0, 2, &"video")]
	spec.late_defs = [DotSettingsDef.number(&"ambient_rate", 1.0, 0.0, 2.0, &"audio")]
	spec.extra_rows = [[&"video", "Image", DotMenuRow.select(&"crowd", "Crowd detail", "How many.", [[0, "Low"], [1, "Normal"], [2, "High"]])]]
	spec.page_makers = [[func() -> DotMenuPage: return DotMenuPage.make(&"extra", "Extra", "Its own page."), &"video"]]
	spec.migrations = {1: func(doc: Dictionary) -> Dictionary:
		doc.erase("field_of_view")
		return doc}
	spec.fov_transform = DotMenuApplier.vertical_from_horizontal_4_3
	spec.config_settings = {"master_volume": {"default": 0.4}}
	spec.manage_pointer = true
	var seen: Array = []
	var swapped := DotSettingsStoreMemory.new()
	spec.before_setup = func(_node: DotMenuGameSettings, _store: DotSettingsStore) -> DotSettingsStore:
		seen.append(true)
		return swapped
	var keys: Array = spec.make_schema().keys()
	var at := func(k: StringName) -> int: return keys.find(k)
	host._check(at.call(&"gore") < at.call(&"crowd") and at.call(&"crowd") < at.call(&"ambient") \
		and at.call(&"ambient_volume") < at.call(&"ambient_rate"), "extra settings go after gore, late ones after the ambient pair")
	spec.has_fov = false
	spec.not_applied = [&"field_of_view"] as Array[StringName]
	host._check(not spec.make_schema().has(&"field_of_view"), "a game with no field of view declares none")
	spec.has_fov = true
	spec.not_applied = [&"ui_volume", &"voice_volume"] as Array[StringName]
	spec.base_schema = func() -> DotSettingsSchema:
		var base := DotSettingsSchema.new()
		base.add(DotSettingsDef.boolean(&"from_base", true, &"video"))
		return base
	host._check(spec.make_schema().has(&"from_base"), "base_schema is where the settings start")
	spec.base_schema = Callable()

	var old := DotSettingsStoreMemory.new()
	var _s := swapped.save_document(&"spec_run", &"local", {"version": 1, "values": {"field_of_view": 100, "sfx_volume": 0.5}})
	var node := DotMenuGameSettings.new(spec)
	host._check(node.manage_pointer and node.config.settings.get("master_volume", {}).get("default", 0) == 0.4,
		"manage_pointer and the config override come from the spec")
	host.add_child(node)
	var res := node.setup(old)
	host._check(res.ok and seen.size() == 1, "before_setup runs once, and the store it returns is the one used")
	var fov: Variant = node.settings.get_value(&"field_of_view")
	host._check(int(fov) == 80, "a version-1 document is migrated: the stale field of view is dropped for the default (%s)" % [fov])
	host._check(absf(float(node.settings.get_value(&"sfx_volume")) - 0.5) < 0.001, "and the rest of the old values are kept")
	host._check(node.applier.fov_transform.is_valid(), "the view transform reaches the applier")
	host._check(node.menu.page(&"extra") != null, "the game's own page is in the menu")
	var order: Array = []
	for pg in node.menu.pages:
		order.append(pg.id)
	host._check(order.find(&"extra") == order.find(&"video") - 1, "before the page it names")
	node.open()
	await host.get_tree().process_frame
	host._check(node.menu.page(&"video").section("Image").rows.any(func(r): return r.key == &"crowd"),
		"the extra row is on the Image section")
	node.close()
	node.queue_free()
	await host.get_tree().process_frame
