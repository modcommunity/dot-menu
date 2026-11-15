extends CanvasLayer

## The toast half of [DotMenu] (its base script): the short line at the top of the screen, and the
## kit and loadout screen it is drawn with and placed by. Everything else is in dot_menu.gd.

## The kit everything is drawn with now. Replaced, not changed, on a theme change.
var kit: DotMenuKit = null

## The loadout menu, and its screen. Null until [method use_loadout]. See [DotMenuLoadout].
var loadout: DotMenuLoadout = null
var loadout_screen: DotMenuLoadoutScreen = null

## The short line [method toast] shows; null until the first one.
var toast_plate: PanelContainer = null
## Where the toast's top edge sits, in pixels from the top. A game whose HUD draws a strip
## there (scores, clock, mode label) sets this below it; read each time a toast is shown.
var toast_top := 64.0
var _toast_serial := 0


## A short line at the top of the screen for [param seconds]: the map menu's "Changing the map
## here needs …", "Nominated Atrium. Rocked: 1 of 3." A plate rather than chat, because the
## player pressed a key and is looking at the screen, not at the chat box.
func toast(text: String, seconds: float = 3.5) -> void:
	if text == "" or kit == null:
		return
	if toast_plate == null:
		toast_plate = _make_toast_plate()
		add_child(toast_plate)
	var p := kit.palette
	toast_plate.add_theme_stylebox_override(&"panel", kit.box(Color(p.surface, 0.92), 10, p.accent, 1, Vector4(16, 8, 16, 8)))
	var label := toast_plate.get_node("Text") as Label
	label.add_theme_color_override(&"font_color", p.text)
	label.text = text
	# Over an open loadout panel the top of the screen is its intro text: drop below the panel.
	var low := loadout_screen != null and loadout_screen.is_open()
	toast_plate.set_anchors_preset(Control.PRESET_CENTER_BOTTOM if low else Control.PRESET_CENTER_TOP)
	toast_plate.grow_horizontal = Control.GROW_DIRECTION_BOTH
	toast_plate.grow_vertical = Control.GROW_DIRECTION_BEGIN if low else Control.GROW_DIRECTION_END
	toast_plate.offset_top = -48.0 if low else toast_top
	toast_plate.offset_bottom = -48.0 if low else toast_top
	toast_plate.visible = true
	move_child(toast_plate, get_child_count() - 1)
	_toast_serial += 1
	var serial := _toast_serial
	if is_inside_tree() and seconds > 0.0:
		get_tree().create_timer(seconds).timeout.connect(_expire_toast.bind(serial))


func _make_toast_plate() -> PanelContainer:
	var plate := PanelContainer.new()
	plate.name = "Toast"
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.set_anchors_preset(Control.PRESET_CENTER_TOP)
	plate.grow_horizontal = Control.GROW_DIRECTION_BOTH
	var l := kit.label("", kit.size_body, kit.palette.text, true)
	l.name = "Text"
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.add_child(l)
	return plate


func _expire_toast(serial: int) -> void:
	if serial == _toast_serial and toast_plate != null:
		toast_plate.visible = false


## What the toast says now; empty when none is up.
func toast_text() -> String:
	return (toast_plate.get_node("Text") as Label).text if toast_plate != null and toast_plate.visible else ""
