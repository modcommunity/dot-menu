extends RefCounted

const Selftest := preload("res://examples/menu_selftest.gd")

## The touch layout, run from menu_selftest. How it LOOKS is tools/touch_shot.gd's.
static func run(host: Selftest) -> void:
	host._section("touch: a Menu button, a Close button, finger-sized rows")

	var cfg := DotMenuConfig.new()
	cfg.touch = &"off"
	host._check(not cfg.touch_ui(), "touch off draws for the pointer")
	cfg.touch = &"on"
	host._check(cfg.touch_ui(), "touch on draws for fingers")
	DotPlatform.touch_override = 0
	cfg.touch = &"auto"
	host._check(not cfg.touch_ui(), "auto follows DotPlatform.has_touch (none)")
	DotPlatform.touch_override = 1
	host._check(cfg.touch_ui(), "auto follows DotPlatform.has_touch (touch)")

	var menu := host._menu(DotMenuStock.DEFAULT_GROUPS, cfg)
	await host.get_tree().process_frame
	host._check(menu.menu_button != null and menu.menu_button.visible, "touch shows the Menu button on the HUD")
	host._check(menu.menu_button != null and menu.menu_button.custom_minimum_size.y >= 52, "the Menu button is finger-sized")
	host._check(menu.menu_button != null and menu.menu_button.anchor_left == 1.0 and menu.menu_button.offset_right < 0.0, "the Menu button sits top right, clear of a HUD title top left")
	menu.open(&"video")
	await host.get_tree().process_frame
	host._check(menu.menu_button != null and not menu.menu_button.visible, "the Menu button hides while a screen is open")
	host._check(menu.find_child("Close", true, false) != null, "the screen has a Close button")
	menu.close_all()
	host._free_menu(menu)

	# The harness window is 64 px square, smaller than the button itself.
	var win := host.get_window()
	var old_size := win.size
	win.size = Vector2i(800, 480)
	for corner in [&"top_right", &"top_left", &"bottom_right", &"bottom_left"]:
		var ccfg := DotMenuConfig.new()
		ccfg.touch = &"on"
		ccfg.menu_button_corner = corner
		var cm := host._menu(DotMenuStock.DEFAULT_GROUPS, ccfg)
		await host.get_tree().process_frame
		await host.get_tree().process_frame
		var b := cm.menu_button
		var vp := cm.get_viewport().get_visible_rect()
		var r := b.get_global_rect() if b != null else Rect2()
		var right := String(corner).ends_with("right")
		var top := String(corner).begins_with("top")
		host._check(b != null and vp.encloses(r), "%s: the Menu button is inside the viewport (%s in %s)" % [corner, r, vp])
		var gap_x := (vp.end.x - r.end.x) if right else (r.position.x - vp.position.x)
		var gap_y := (r.position.y - vp.position.y) if top else (vp.end.y - r.end.y)
		host._check(b != null and absf(gap_x - 14.0) < 1.0 and absf(gap_y - 14.0) < 1.0, "%s: 14 px clear of both edges (%s, %s)" % [corner, gap_x, gap_y])
		host._check(b != null and b.grow_horizontal == (Control.GROW_DIRECTION_BEGIN if right else Control.GROW_DIRECTION_END) \
			and b.grow_vertical == (Control.GROW_DIRECTION_END if top else Control.GROW_DIRECTION_BEGIN), "%s: grows away from its corner" % corner)
		host._free_menu(cm)
	win.size = old_size

	DotPlatform.touch_override = 0
	var desk := host._menu()
	host._check(desk.menu_button == null, "no touch, no Menu button")
	host._free_menu(desk)
	DotPlatform.touch_override = -1
