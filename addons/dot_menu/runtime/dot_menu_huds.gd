class_name DotMenuHuds
extends RefCounted
## The HUD roots a game hands [DotMenu] through `follow_hud`: themed and scaled on every change.

var _menu: DotMenu
var _entries: Array[Dictionary] = []


func _init(menu: DotMenu) -> void:
	_menu = menu


func follow(root: Control, accent: Theme, scaled: bool) -> void:
	if root == null:
		return
	for entry in _entries:
		if (entry["root"] as WeakRef).get_ref() == root:
			entry["accent"] = accent
			entry["scaled"] = scaled
			_style(entry)
			_scale(entry)
			return
	var added := {"root": weakref(root), "accent": accent, "scaled": scaled, "fitted": false}
	_entries.append(added)
	_style(added)
	_scale(added)


func unfollow(root: Control) -> void:
	for i in range(_entries.size() - 1, -1, -1):
		var held: Object = (_entries[i]["root"] as WeakRef).get_ref()
		if held == null or held == root:
			_entries.remove_at(i)


func roots() -> Array[Control]:
	var out: Array[Control] = []
	for entry in _entries:
		var held := (entry["root"] as WeakRef).get_ref() as Control
		if held != null:
			out.append(held)
	return out


func style_all() -> void:
	for entry in _entries:
		_style(entry)


func scale_all() -> void:
	for entry in _entries:
		_scale(entry)


func _style(entry: Dictionary) -> void:
	var root := (entry["root"] as WeakRef).get_ref() as Control
	if root == null:
		return
	var p: DotMenuPalette = _menu.palette() if (_menu.kit != null or _menu.themes != null) else DotMenuPalette.new()
	root.theme = p.hud_theme(entry["accent"] as Theme)


func _scale(entry: Dictionary) -> void:
	var root := (entry["root"] as WeakRef).get_ref() as Control
	if root == null or not bool(entry["scaled"]):
		return
	var k := _menu.hud_scale()
	if &"user_scale" in root:
		root.set(&"user_scale", k)
		return
	# A plain root is left as the game laid it out until a size other than 1 is asked for,
	# and put back on full-rect anchors when 1 is asked for again.
	if is_equal_approx(k, 1.0) and not bool(entry["fitted"]):
		return
	if not root.is_inside_tree():
		return
	var vp := root.get_viewport()
	if not bool(entry["fitted"]):
		entry["fitted"] = true
		if not vp.size_changed.is_connected(scale_all):
			vp.size_changed.connect(scale_all)
	if is_equal_approx(k, 1.0):
		root.scale = Vector2.ONE
		root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		entry["fitted"] = false
		return
	DotHud.fit_control(root, vp.get_visible_rect().size, k)
