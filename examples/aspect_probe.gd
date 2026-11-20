extends Node3D

## Resizes a native window to 16:9, 21:9, 4:3 and portrait under a shell-like stretch (canvas_items, keep) and
## checks the game fills each with no bars while keep_aspect is off, and letterboxes when it is on. With
## `-- --out=DIR` on a display it saves each window as the screen shows it (bars included).
##
##   tools/aspect_shot.sh (gpu.sh shot on staging02)

const SIZES := [Vector2i(1600, 900), Vector2i(2520, 1080), Vector2i(1200, 900), Vector2i(720, 1280)]

var _out := ""
var _passed := 0
var _failed := 0
var _store: DotSettingsManager
var _applier: DotMenuApplier


func _ready() -> void:
	var keep := false
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.substr(6)
		elif a == "--keep":
			keep = true
	var root := get_tree().root
	root.content_scale_size = Vector2i(1280, 720)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	_build()
	var schema := DotMenuStock.declare(DotSettingsSchema.new())
	_store = DotSettingsManager.new()
	_store.schema = schema
	_store.local_store = DotSettingsStoreMemory.new()
	_store.app_namespace = &"aspect_probe"
	_store.persist = false
	_store.register_as_service = false
	add_child(_store)
	var _s := _store.setup()
	var _k := _store.set_value(&"keep_aspect", keep)
	_applier = DotMenuApplier.new()
	_applier.settings = _store
	add_child(_applier)
	var _a := _applier.setup()
	var display := DisplayServer.get_name() != "headless"
	if display:
		# The window as launched (tools/aspect_shot.sh starts one per shape with --resolution).
		await _at(DisplayServer.window_get_size(), keep, display)
	else:
		for sz in SIZES:
			await _at(sz, keep, display)
		var _k2 := _store.set_value(&"keep_aspect", not keep)
		for sz in SIZES:
			await _at(sz, not keep, display)
	print("aspect probe: %d passed, %d failed" % [_passed, _failed])
	get_tree().quit(1 if _failed > 0 else 0)


func _at(sz: Vector2i, keep: bool, display: bool) -> void:
	var root := get_tree().root
	if not display:
		root.size = sz
	for i in 12:
		await get_tree().process_frame
	if display:
		await RenderingServer.frame_post_draw
	var win := DisplayServer.window_get_size() if display else root.size
	var vis := root.get_visible_rect().size
	var want := float(win.x) / float(win.y)
	var got := vis.x / vis.y
	var square := is_equal_approx(want, 16.0 / 9.0)
	var tag := "%dx%d%s" % [win.x, win.y, "_keep" if keep else ""]
	var fills := absf(want - got) < 0.01
	_check(fills != keep or square, "%s: the game's area is %.0fx%.0f (window aspect %.3f, game %.3f)%s" % [tag, vis.x, vis.y, want, got, " letterboxed" if keep else ""])
	if display:
		var img := get_viewport().get_texture().get_image()
		var screen := DisplayServer.screen_get_image(DisplayServer.window_get_current_screen())
		if screen != null and not screen.is_empty():
			img = screen.get_region(Rect2i(DisplayServer.window_get_position(), win))
		var bars := _black_edges(img)
		_check((bars > 0) == keep or square, "%s: %d px of black bars on screen" % [tag, bars])
		if _out != "":
			var _e := img.save_png("%s/%s.png" % [_out, tag])


## Black rows or columns along the window's edges, the larger side.
static func _black_edges(img: Image) -> int:
	var w := img.get_width()
	var h := img.get_height()
	var cols := 0
	while cols < w / 2 and _black(img.get_pixel(cols, h / 2)) and _black(img.get_pixel(cols, h / 4)):
		cols += 1
	var rows := 0
	while rows < h / 2 and _black(img.get_pixel(w / 2, rows)) and _black(img.get_pixel(w / 4, rows)):
		rows += 1
	return maxi(cols, rows)


static func _black(c: Color) -> bool:
	return c.r < 0.02 and c.g < 0.02 and c.b < 0.02


func _check(ok: bool, what: String) -> void:
	if ok:
		_passed += 1
	else:
		_failed += 1
	print("%s: %s" % ["ok" if ok else "FAIL", what])


## A 3D floor and sky behind a HUD whose corners are anchored: a bar shows as black beyond the corner marks.
func _build() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.25, 0.45, 0.7)
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 2, 6)
	add_child(cam)
	cam.look_at(Vector3.ZERO)
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(60, 60)
	floor_mesh.mesh = plane
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.3, 0.6, 0.3)
	floor_mesh.material_override = mat
	add_child(floor_mesh)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 30, 0)
	add_child(sun)
	var hud := CanvasLayer.new()
	add_child(hud)
	var frame := ReferenceRect.new()
	frame.editor_only = false
	frame.border_color = Color(1, 0.8, 0.1)
	frame.border_width = 6.0
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud.add_child(frame)
	for corner in [[Control.PRESET_TOP_LEFT, "top left"], [Control.PRESET_TOP_RIGHT, "top right"],
			[Control.PRESET_BOTTOM_LEFT, "bottom left"], [Control.PRESET_BOTTOM_RIGHT, "bottom right"], [Control.PRESET_CENTER, "centre"]]:
		var l := Label.new()
		l.text = corner[1]
		l.add_theme_font_size_override(&"font_size", 28)
		hud.add_child(l)
		l.set_anchors_and_offsets_preset(corner[0], Control.PRESET_MODE_MINSIZE, 12)
