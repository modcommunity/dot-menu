extends RefCounted

const Selftest := preload("res://examples/menu_selftest.gd")

## The Video page's Quality presets, the letterbox switch and the remembered window size, run from menu_selftest.

static func run(host: Selftest) -> void:
	host._section("Video presets, aspect and window size")
	var st := host._manager(host._schema(DotMenuStock.ALL_GROUPS))
	var applier := DotMenuApplier.new()
	applier.settings = st
	host.add_child(applier)
	var _s := applier.setup()

	var missing: Array = []
	for preset in DotMenuGraphicsPresets.TABLE:
		for k in (DotMenuGraphicsPresets.TABLE[preset] as Dictionary):
			if not st.schema.has(k):
				missing.append(k)
	host._check(missing.is_empty() and st.get_string(DotMenuGraphicsPresets.KEY) == String(DotMenuGraphicsPresets.DEFAULT), "every key a preset sets is declared, and High is the default (%s)" % [missing])
	var differs: Array = []
	for k in (DotMenuGraphicsPresets.TABLE[DotMenuGraphicsPresets.DEFAULT] as Dictionary):
		if not DotMenuGraphicsPresets.same(st.get_value(k), DotMenuGraphicsPresets.TABLE[DotMenuGraphicsPresets.DEFAULT][k]):
			differs.append(k)
	host._check(differs.is_empty(), "High is every key's own default, so an untouched player sees no change (%s)" % [differs])

	var _l := st.set_value(DotMenuGraphicsPresets.KEY, &"low")
	host._check(st.get_int(&"shadow_quality", -1) == 1 and is_equal_approx(st.get_float(&"render_scale", 0.0), 0.75) and st.get_int(&"aa", -1) == 1
		and not st.get_bool(&"glow", true) and st.get_string(DotMenuGraphicsPresets.KEY) == "low", "choosing Low writes Low's values and stays Low")
	var _m := st.set_value(DotMenuGraphicsPresets.KEY, &"medium")
	var _q := st.set_value(&"shadow_quality", 2)
	host._check(st.get_string(DotMenuGraphicsPresets.KEY) == "medium", "setting a key to the preset's own value keeps the preset")
	var _h := st.set_value(&"shadow_quality", 4)
	host._check(st.get_string(DotMenuGraphicsPresets.KEY) == "custom" and st.get_int(&"shadow_quality", -1) == 4, "changing a preset key by hand makes it Custom")
	var _u := st.set_value(DotMenuGraphicsPresets.KEY, &"ultra")
	host._check(st.get_int(&"aa", -1) == 5 and is_equal_approx(st.get_float(&"lod_bias", 0.0), 2.0) and st.get_string(DotMenuGraphicsPresets.KEY) == "ultra",
		"choosing Ultra from Custom writes Ultra's values")
	var _c := st.set_value(DotMenuGraphicsPresets.KEY, DotMenuGraphicsPresets.CUSTOM)
	host._check(st.get_int(&"aa", -1) == 5, "choosing Custom keeps the values the player has")

	var root := host.get_tree().root
	var mode := root.content_scale_mode
	var aspect := root.content_scale_aspect
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	applier.apply_all()
	host._check(root.content_scale_aspect == Window.CONTENT_SCALE_ASPECT_EXPAND, "keep_aspect off (the default) fills the window: a project's keep becomes expand")
	var _k := st.set_value(&"keep_aspect", true)
	host._check(root.content_scale_aspect == Window.CONTENT_SCALE_ASPECT_KEEP, "keep_aspect on letterboxes")
	var _k2 := st.set_value(&"keep_aspect", false)
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	root.size_changed.emit()
	host._check(root.content_scale_aspect == Window.CONTENT_SCALE_ASPECT_EXPAND, "a resize puts expand back over a menu that restored keep")
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	var _k3 := st.set_value(&"keep_aspect", true)
	host._check(root.content_scale_aspect == Window.CONTENT_SCALE_ASPECT_EXPAND, "a window without stretch is left alone")
	var _k4 := st.set_value(&"keep_aspect", false)
	root.content_scale_mode = mode
	root.content_scale_aspect = aspect

	host._check(DotMenuApplier.parse_size("1600x900") == Vector2i(1600, 900) and DotMenuApplier.parse_size(" 2560 X 1080 ") == Vector2i(2560, 1080)
		and DotMenuApplier.parse_size("") == Vector2i.ZERO and DotMenuApplier.parse_size("100x50") == Vector2i.ZERO
		and DotMenuApplier.parse_size("big") == Vector2i.ZERO, "a window size reads as WxH; empty, tiny or junk is the project's own")
	host._check(DotMenuStock.resolution_options().size() >= 1 and DotMenuStock.resolution_options()[0][0] == "",
		"the size list starts with the project's own size")
	host._check(applier.remember_window_after > 0.0 and st.schema.find(&"window_size").default_value == "", "a window size is remembered after a resize settles, empty by default")

	applier.queue_free()
	st.queue_free()
	await host.get_tree().process_frame
