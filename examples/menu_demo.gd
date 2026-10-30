extends Node3D

## dot-menu with a world behind it: the stock pages, a game's own page, a picker, and a HUD a player can arrange. Escape opens the menu, H help, P the next theme, M the picker.
## Everything a game writes to use the addon is in [method _build_menu], and it is short on purpose: that length is the claim this addon makes.

var settings: DotSettingsManager = null
var keys: DotMenuBindings = null
var menu: DotMenu = null
var applier: DotMenuApplier = null
var hud: DemoHud = null
var camera: Camera3D = null

var flashlight_on := false
var server_allows_flashlight := true


func _ready() -> void:
	_build_world()
	_build_menu()


func _build_menu() -> void:
	# 1. The keys this game reads.
	keys = DotMenuBindings.new()
	keys.add_movement()
	keys.add(&"demo_flashlight", &"bind_flashlight", "Flashlight", "F", "View")
	var _m := keys.add_maps("Interface")
	keys.add(&"demo_help", &"bind_help", "Help", "H", "Interface")
	keys.add(&"demo_theme", &"bind_theme_next", "Next theme", "P", "Interface")
	keys.add(&"demo_scores", &"bind_scores", "Scoreboard (hold)", "Tab", "Interface")

	# 2. The settings: the stock ones, the game's own, and the developer's config over both.
	var config := DotMenuConfig.new()
	config.brand_mark = "dot"
	config.brand_name = "menu"
	# The environment and the command line over those: DOT_MENU_THEME=paper, --menu-browser-tips=on.
	var _layered := config.load_layered()
	var schema := DotSettingsSchema.new()
	DotMenuStock.declare(schema)
	schema.add(DotSettingsDef.boolean(&"show_speed", true, &"hud").with_description("Your speed under the clock."))
	schema.add(DotSettingsDef.text(&"hud_positions", "", &"hud"))
	keys.add_to_schema(schema)
	var _problems := config.apply_to_schema(schema)

	settings = DotMenuStock.manager(schema, "user://dot_menu_demo", &"dot_menu_demo", &"")
	add_child(settings)
	var _loaded := settings.setup()

	# 3. What applies them.
	applier = DotMenuApplier.new()
	applier.settings = settings
	applier.bindings = keys
	add_child(applier)
	applier.bind_camera(camera)
	var _shown := applier.on(&"show_speed", func(on: Variant, _why: StringName) -> void: hud.speed.visible = bool(on))
	var _placed := applier.on(&"hud_positions", func(text: Variant, _why: StringName) -> void:
		hud.positions = DotMenuLayoutEditor.decode(str(text), hud.pieces())
		hud.place())
	var _applied := applier.setup()

	# 4. The menu, and the game's own page on it.
	menu = DotMenu.new()
	menu.settings = settings
	menu.bindings = keys
	menu.config = config
	menu.help_action = &"demo_help"
	menu.theme_action = &"demo_theme"
	menu.scoreboard_action = &"demo_scores"
	# A demo with no game to capture the pointer for.
	menu.manage_pointer = false
	add_child(menu)
	var _set := menu.setup()

	var gameplay := DotMenuPage.make(&"gameplay", "Gameplay", "What is on the screen, and your light.")
	gameplay.section("HUD") \
		.add(DotMenuRow.toggle(&"show_speed", "Speed", "Your speed under the clock.")) \
		.add(DotMenuRow.button("Arrange", "Drag the clock and the speed wherever you want them.", "Move HUD elements",
			func() -> void: menu.open_layout_editor(hud, {&"clock": "Clock", &"speed": "Speed"})))
	gameplay.section("View").add(
		DotMenuRow.live_toggle("Flashlight", "", func() -> bool: return flashlight_on,
			func(on: bool) -> void: flashlight_on = on)
			.enabled_when(func() -> bool: return server_allows_flashlight)
			.described_by(func() -> String:
				if not server_allows_flashlight:
					return "This server has turned flashlights off."
				return "Only you see it. %s toggles it." % keys.key_for(&"demo_flashlight")))
	menu.add_page(gameplay, &"video")

	menu.screen.subtitle = "Offline · demo"
	menu.help.title_text = "How to play the demo"
	menu.help.about = "Nothing to win here: every menu a game gets from dot-menu, in the theme you pick. A game puts its goal in this card."
	menu.help.add_text("Modes", "A game describes its modes or its rules in a card like this one, and the keys come from its table on the left.")
	menu.help.add_section("This demo", [["P", "The next theme"]], &"keys")
	# The map menu: M opens these, and offline a choice changes the map (here, says so).
	var _maps := menu.use_maps(maps, func(id: StringName) -> DotResult:
		hud.speed.text = "Changed to %s" % id
		return DotResult.success(id))
	menu.layout_editor.saved.connect(func(text: String) -> void: var _s := settings.set_value(&"hud_positions", text))
	menu.picked.connect(func(id: StringName) -> void: hud.speed.text = "Picked %s" % id)
	menu.theme_changed.connect(func(p: DotMenuPalette) -> void: hud.recolour(p))
	menu.action_requested.connect(func(id: StringName) -> void:
		if id == &"leave":
			get_tree().quit())
	hud.recolour(menu.palette())

	# Offline there is no server roster, so the board draws this game's own; online it would be
	# `menu.scoreboard.feed_from(link)`. Kills and deaths are this game's columns.
	menu.scoreboard.add_column({"key": &"kills", "title": "K", "kind": DotMenuScoreboard.KIND_NUMBER}, &"score")
	menu.scoreboard.add_column({"key": &"deaths", "title": "D", "kind": DotMenuScoreboard.KIND_NUMBER}, &"score")
	menu.scoreboard.source = roster




## A made-up server, two teams and a spectator. What a held Tab draws in the demo.
static func roster() -> Dictionary:
	var names := ["Ada", "Bea", "Cy", "Dot", "Eli", "Fin", "Gus", "Hal", "Ivy"]
	var players: Array = []
	for i in names.size():
		players.append({
			"id": i + 1, "name": names[i], "score": 40 - i * 4 + (i % 3) * 7, "kills": 12 - i, "deaths": 3 + i % 4,
			"ping": [18, 42, 75, 130, 260, 33, -1, 55, 90][i], "seconds": 60 * (5 + i * 7) + i * 13,
			"team": 0 if i == 8 else 1 + i % 2, "bot": i == 6,
		})
	return {
		"server": {"name": "TMC Demo #1  |  Deathmatch", "game": "Arena", "map": "dm_yard", "players": 9, "max": 16},
		"you": 3,
		"header": {"Time left": "7:42", "Round": "3 of 5"},
		"teams": [{"id": 1, "name": "Red", "color": "#e5534b", "score": 4}, {"id": 2, "name": "Blue", "color": "#4c8fe6", "score": 6}],
		"players": players,
	}


static func maps() -> Array:
	var out: Array = []
	var names := ["Intro", "Stages", "Quarry", "Slide Hill", "Build Plots", "Foundry", "Ice Works", "Long Fall", "Canyon", "Harbour"]
	var modes := ["Deathmatch", "Race", "Capture the flag", "Race", "Free build", "Deathmatch", "Race", "Last one standing", "Race", "Deathmatch"]
	for i in names.size():
		var tags: Array = ["tier %d" % (i % 4 + 1)]
		if i == 6:
			tags.append("not in rotation")
		# A made-up picture for most maps (a game's would be a path in its pack); one has none,
		# to show the empty frame a map without a picture keeps.
		out.append({"id": names[i].to_snake_case(), "name": names[i], "mode": modes[i], "tags": tags,
			"current": i == 2, "warn": i == 6, "thumbnail": _swatch(i) if i != 4 else ""})
	return out


## A loadout offer as dot-loadout's `offer_for` sends one, decorated as a game would: a made-up
## silhouette per weapon (a game's are rendered from its models) and the statistics.
static func loadout_offer() -> Dictionary:
	var specs := {
		"primary": [["rifle", "Rifle", 2, 0.42, 0.75, 0.7], ["carbine", "Carbine", 2, 0.36, 0.82, 0.55],
			["smg", "SMG", 2, 0.28, 0.95, 0.35], ["marksman", "Marksman", 2, 0.78, 0.25, 0.95],
			["shotgun", "Shotgun", 2, 0.95, 0.2, 0.12], ["launcher", "Launcher", 4, 1.0, 0.1, 0.6],
			["minigun", "Minigun", 4, 0.3, 1.0, 0.45], ["sniper", "Long Rifle", 4, 1.0, 0.08, 1.0]],
		"secondary": [["pistol", "Pistol", 1, 0.3, 0.5, 0.55], ["revolver", "Revolver", 1, 0.6, 0.22, 0.6],
			["machine_pistol", "Machine Pistol", 1, 0.2, 0.9, 0.3]],
		"melee": [["knife", "Knife", 0, 0.45, 0.6, 0.05], ["hatchet", "Hatchet", 0, 0.6, 0.4, 0.06]],
		"thrown": [["frag", "Frag Grenade", 1, 0.9, 0.1, 0.3], ["sticky", "Sticky Bomb", 1, 0.85, 0.1, 0.25]],
	}
	var names := {"primary": "Primary", "secondary": "Sidearm", "melee": "Melee", "thrown": "Grenades"}
	var current := {"primary": "rifle", "secondary": "pistol", "melee": "knife", "thrown": "frag"}
	var slots: Array = []
	var shade := 0
	for slot_id: String in ["primary", "secondary", "melee", "thrown"]:
		var choices: Array = []
		for spec: Array in specs[slot_id]:
			shade += 1
			choices.append({"id": spec[0], "name": spec[1], "cost": spec[2], "tags": ["automatic"] if spec[4] > 0.7 else [],
				"locked": spec[0] in ["minigun", "sniper"], "store": "https://example.com/store" if spec[0] in ["minigun", "sniper"] else "",
				"icon": _silhouette(shade, slot_id), "detail": "A stand-in description of the %s." % str(spec[1]).to_lower(),
				"stats": [{"label": "Damage", "value": spec[3], "text": str(int(spec[3] * 120))},
					{"label": "Fire rate", "value": spec[4], "text": "%d/min" % int(spec[4] * 900)},
					{"label": "Range", "value": spec[5], "text": "%d m" % int(spec[5] * 200)},
					{"label": "Magazine", "value": 0.5, "text": "30"}]})
		slots.append({"id": slot_id, "name": names[slot_id], "current": current[slot_id], "fixed": false, "choices": choices})
	return {"choose": true, "budget": 7, "note": "", "slots": slots,
		"saved": [{"index": 0, "name": "Assault", "selected": true, "saved": true},
			{"index": 1, "name": "Long range", "selected": false, "saved": true},
			{"index": 2, "name": "Close quarters", "selected": false, "saved": true}]}


## A flat gun-ish shape, as a stand-in for a game's rendered weapon icon.
static func _silhouette(i: int, slot_id: String) -> Texture2D:
	var img := Image.create(160, 80, false, Image.FORMAT_RGBA8)
	var ink := Color(0.86, 0.88, 0.92, 1.0)
	var long := 120 if slot_id == "primary" else (70 if slot_id == "secondary" else 60)
	img.fill_rect(Rect2i(20, 30, long, 12 + i % 3 * 2), ink)
	if slot_id != "melee" and slot_id != "thrown":
		img.fill_rect(Rect2i(30 + i % 4 * 6, 42, 14, 26), ink)
	if slot_id == "thrown":
		img.fill_rect(Rect2i(55, 20, 40, 44), ink)
	return ImageTexture.create_from_image(img)


## A sky-over-ground picture in a colour of its own, as a stand-in for a map's preview.
static func _swatch(i: int) -> Texture2D:
	var img := Image.create(64, 36, false, Image.FORMAT_RGB8)
	var hue := fmod(0.07 * i + 0.55, 1.0)
	for y in 36:
		var c := Color.from_hsv(hue, 0.35, 0.95 - y * 0.008) if y < 20 else Color.from_hsv(fmod(hue + 0.3, 1.0), 0.55, 0.55 - (y - 20) * 0.01)
		for x in 64:
			img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)


func _build_world() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	sky.sky_material = ProceduralSkyMaterial.new()
	e.sky = sky
	e.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.environment = e
	add_child(env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 30, 0)
	sun.shadow_enabled = true
	add_child(sun)

	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(80, 80)
	ground.mesh = plane
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.32, 0.36, 0.3)
	ground.material_override = gm
	add_child(ground)

	var colours := [Color(0.85, 0.4, 0.3), Color(0.3, 0.6, 0.85), Color(0.9, 0.8, 0.3), Color(0.4, 0.8, 0.5)]
	for i in 12:
		var box := MeshInstance3D.new()
		var m := BoxMesh.new()
		m.size = Vector3(2, 1 + (i % 4), 2)
		box.mesh = m
		var mat := StandardMaterial3D.new()
		mat.albedo_color = colours[i % colours.size()]
		box.material_override = mat
		box.position = Vector3((i % 6) * 4.0 - 10.0, m.size.y * 0.5, -6.0 - (i / 6) * 6.0)
		add_child(box)

	camera = Camera3D.new()
	camera.position = Vector3(0, 4, 8)
	camera.rotation_degrees = Vector3(-18, 0, 0)
	add_child(camera)

	var layer := CanvasLayer.new()
	add_child(layer)
	hud = DemoHud.new()
	layer.add_child(hud)


## A HUD of two pieces the layout editor can move: the duck-typed four it needs.
class DemoHud extends Control:
	var clock: Label = null
	var speed: Label = null
	var positions := {}

	func _ready() -> void:
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		clock = _label("0:42.180", 34)
		speed = _label("312 u/s", 18)
		resized.connect(place)
		place()

	func _label(text: String, size_px: int) -> Label:
		var l := Label.new()
		l.text = text
		l.add_theme_font_size_override(&"font_size", size_px)
		l.add_theme_constant_override(&"outline_size", 6)
		l.add_theme_color_override(&"font_outline_color", Color(0, 0, 0, 0.7))
		add_child(l)
		return l

	func pieces() -> Array:
		return [&"clock", &"speed"]

	func recolour(p: DotMenuPalette) -> void:
		clock.add_theme_color_override(&"font_color", p.hud_text)
		speed.add_theme_color_override(&"font_color", p.hud_detail)

	func _default(id: StringName) -> Vector2:
		return Vector2(0.5, 0.82) if id == &"clock" else Vector2(0.5, 0.89)

	func _node(id: StringName) -> Label:
		return clock if id == &"clock" else speed

	func place() -> void:
		if clock == null:
			return
		for id in pieces():
			var l := _node(id)
			var at: Vector2 = positions.get(id, _default(id))
			l.size = l.get_combined_minimum_size()
			l.position = at * size - l.size * 0.5

	func element_rect(id: StringName) -> Rect2:
		var l := _node(id)
		return Rect2(l.position, l.size) if l != null else Rect2()

	func move_element(id: StringName, centre: Vector2) -> void:
		positions[id] = Vector2(clampf(centre.x / size.x, 0.0, 1.0), clampf(centre.y / size.y, 0.0, 1.0))
		place()

	func reset_element(id: StringName) -> void:
		positions.erase(id)
		place()
