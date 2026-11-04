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
	menu.open(&"video")
	await host.get_tree().process_frame
	host._check(menu.menu_button != null and not menu.menu_button.visible, "the Menu button hides while a screen is open")
	host._check(menu.find_child("Close", true, false) != null, "the screen has a Close button")
	menu.close_all()
	host._free_menu(menu)

	DotPlatform.touch_override = 0
	var desk := host._menu()
	host._check(desk.menu_button == null, "no touch, no Menu button")
	host._free_menu(desk)
	DotPlatform.touch_override = -1
