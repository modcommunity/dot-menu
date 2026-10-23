class_name DotMenuStock
extends RefCounted

## The settings every game here has, declared once, and the pages that show them.
##
## [codeblock]
## var schema := DotSettingsSchema.new()
## DotMenuStock.declare(schema)                 # audio, video, controls, comfort, interface
## # ... the game's own settings ...
## config.apply_to_schema(schema)               # the developer's defaults and ranges
##
## var pages := DotMenuStock.pages()            # General, Video, Audio, Controls
## [/codeblock]
##
## [b]The keys are the family's, and they are a contract.[/b] `master_volume`,
## `sensitivity`, `field_of_view` and the rest are the names six games were already storing
## under, with the scopes they were stored in. A different key or scope here would reset
## every player's choice the day a game moved onto this — and `sensitivity` under the
## shared account namespace is the same number in every game, on purpose.
##
## [b]A game declares only what it applies.[/b] [method declare] takes the groups it wants,
## skips any key the schema already has (so a game's own version of a stock setting wins),
## and a page row whose setting is not declared is not drawn. What must not happen is a
## setting declared and applied by nothing: the game this came from had five, and the menu
## would have been five switches that did nothing. [DotMenuApplier] applies every stock key
## that has an obvious target; see it for the two that need the game.
##
## Defaults are the family's common ones — a game whose genre wants different ones
## (a timer server wants no camera shake) says so in its [DotMenuConfig], not here.

const GROUP_AUDIO := &"audio"
const GROUP_VIDEO := &"video"
const GROUP_CONTROLS := &"controls"
## Camera shake and screen flashes.
const GROUP_COMFORT := &"comfort"
## The theme, the frame-rate counter and net_stat.
const GROUP_INTERFACE := &"interface"
## Whether the chat box is drawn.
const GROUP_CHAT := &"chat"
## Voice chat: push to talk or an open microphone, and which input device. The talk key is
## [DotMenuBindings.add_voice]'s row, which [DotMenuSettings] adds with this group. The
## volume is `voice_volume`, in the audio group with the others.
const GROUP_VOICE := &"voice"
## A music volume. Not in [constant DEFAULT_GROUPS]: a slider for a bus nothing plays on is
## a control that does nothing, and most games here have no music.
const GROUP_MUSIC := &"music"
## `viewmodel_fov`, the lens a first-person weapon is drawn through. Never named by a game:
## [method declare] adds it with the video group when the project has a view model class.
const GROUP_VIEWMODEL := &"viewmodel"

## A game with this script class gets `viewmodel_fov` (zee-dot-weapons' `ZeeViewModel`).
const VIEW_MODEL_CLASS := &"ZeeViewModel"
## `viewmodel_fov` default, horizontal degrees on a 4:3 frame like `field_of_view`.
const VIEWMODEL_FOV := 65

## What [method declare] adds when it is not told: everything except music.
const DEFAULT_GROUPS: Array[StringName] = [
	GROUP_AUDIO, GROUP_VIDEO, GROUP_CONTROLS, GROUP_COMFORT, GROUP_INTERFACE, GROUP_CHAT, GROUP_VOICE,
]

const ALL_GROUPS: Array[StringName] = [
	GROUP_AUDIO, GROUP_MUSIC, GROUP_VIDEO, GROUP_CONTROLS, GROUP_COMFORT, GROUP_INTERFACE, GROUP_CHAT,
	GROUP_VOICE, GROUP_VIEWMODEL,
]

## The voice rows a client hides while its server has voice off (`sv_voice_enable 0`): the
## mode, the device, the volume and the talk key. See [method DotMenuSettings.bind_voice].
const VOICE_ROWS: PackedStringArray = ["voice_mode", "voice_input_device", "voice_volume", "bind_voice_talk"]

## Every key [method declare] can add, by group. What a suite checks the applier against.
const KEYS := {
	GROUP_AUDIO: [&"master_volume", &"sfx_volume", &"ui_volume", &"voice_volume"],
	GROUP_MUSIC: [&"music_volume"],
	GROUP_VIDEO: [&"window_mode", &"vsync", &"fps_max", &"render_scale", &"field_of_view", &"fx_quality"],
	GROUP_CONTROLS: [&"sensitivity", &"invert_mouse"],
	GROUP_COMFORT: [&"shake_scale", &"allow_flashes"],
	GROUP_INTERFACE: [&"ui_theme", &"hud_scale", &"show_fps", &"net_stat", &"net_stat_height", &"net_stat_position", &"scoreboard_hidden"],
	GROUP_CHAT: [&"chat_window"],
	GROUP_VOICE: [&"voice_mode", &"voice_input_device"],
	GROUP_VIEWMODEL: [&"viewmodel_fov"],
}


## Declares the stock settings in [param groups] (by default [constant DEFAULT_GROUPS]) that [param schema] does not have yet.
## [param themes] supplies the `ui_theme` options; null is the stock seven. [param except] is
## stock keys this game has nothing to apply to — a game with no interface sounds leaves out
## `ui_volume`, one with no effects `shake_scale` — because a declared setting nothing
## applies is a switch that does nothing.
static func declare(
	schema: DotSettingsSchema, groups: Array[StringName] = DEFAULT_GROUPS, themes: DotMenuThemes = null,
	except: Array[StringName] = []
) -> DotSettingsSchema:
	var before := schema.keys()
	if groups.has(GROUP_VIDEO) and not groups.has(GROUP_VIEWMODEL) and has_view_model():
		groups = groups.duplicate()
		groups.append(GROUP_VIEWMODEL)
	_declare(schema, groups, themes)
	if not except.is_empty():
		var kept: Array[DotSettingsDef] = []
		for def in schema.defs:
			if before.has(def.key) or not except.has(def.key):
				kept.append(def)
		schema.defs = kept
	return schema


static func _declare(schema: DotSettingsSchema, groups: Array[StringName], themes: DotMenuThemes) -> DotSettingsSchema:
	var account := DotSettingsDef.Scope.ACCOUNT

	if groups.has(GROUP_AUDIO):
		_add(schema, DotSettingsDef.number(&"master_volume", 0.8, 0.0, 1.0, &"audio"))
		_add(schema, DotSettingsDef.number(&"sfx_volume", 1.0, 0.0, 1.0, &"audio"))
		# The interface bus: in a game where the round's own cues play there (a timer's
		# split, a vote opening), this is "how loud is my split" rather than a click volume.
		_add(schema, DotSettingsDef.number(&"ui_volume", 0.8, 0.0, 1.0, &"audio"))
		_add(schema, DotSettingsDef.number(&"voice_volume", 1.0, 0.0, 1.0, &"audio"))

	if groups.has(GROUP_MUSIC):
		_add(schema, DotSettingsDef.number(&"music_volume", 0.6, 0.0, 1.0, &"audio"))

	if groups.has(GROUP_VIDEO):
		# DEVICE, all of these: a laptop and a desktop want different answers.
		_add(schema, DotSettingsDef.choice(
			&"window_mode", &"windowed",
			[&"windowed", &"borderless", &"fullscreen"] as Array[StringName], &"video"
		))
		# [b]Off, with the frame rate unlimited[/b]: a capped frame rate is a later input,
		# and a browser always syncs whatever this says.
		_add(schema, DotSettingsDef.boolean(&"vsync", false, &"video"))
		_add(schema, DotSettingsDef.integer(&"fps_max", 0, 0, 1000, &"video")
			.with_description("Most frames a second. 0 is unlimited."))
		_add(schema, DotSettingsDef.number(&"render_scale", 1.0, 0.5, 1.0, &"video")
			.with_description("Resolution of the 3D world, as a fraction of the window's."))
		# SERVER_CLAMPED: a wide view is an advantage a server may cap — and dot-settings
		# gives a server no way to READ it.
		_add(schema, DotSettingsDef.integer(&"field_of_view", 90, 70, 120, &"video")
			.with_scope(DotSettingsDef.Scope.SERVER_CLAMPED))
		_add(schema, DotSettingsDef.integer(&"fx_quality", 3, 0, 3, &"video"))

	if groups.has(GROUP_VIEWMODEL):
		_add(schema, DotSettingsDef.integer(&"viewmodel_fov", VIEWMODEL_FOV, 50, 100, &"video")
			.with_description("How wide the lens that draws your hands and gun is. Lower is a larger, flatter gun; higher is a smaller one."))

	if groups.has(GROUP_CONTROLS):
		# ACCOUNT, and under the shared namespace the same number in every game: a
		# sensitivity is muscle memory, and a player who has to find it again has lost
		# whatever they came to do.
		_add(schema, DotSettingsDef.number(&"sensitivity", 2.5, 0.05, 20.0, &"controls")
			.with_scope(account)
			.with_description("The same number in every game that reads it."))
		_add(schema, DotSettingsDef.boolean(&"invert_mouse", false, &"controls").with_scope(account))
		# No "raw input". The game this came from declared one and nothing applied it, and
		# the engine has no portable switch for it to apply: a row for it would be a lie.

	if groups.has(GROUP_COMFORT):
		_add(schema, DotSettingsDef.number(&"shake_scale", 1.0, 0.0, 2.0, &"accessibility"))
		_add(schema, DotSettingsDef.boolean(&"allow_flashes", true, &"accessibility"))

	if groups.has(GROUP_INTERFACE):
		var t := themes if themes != null else DotMenuThemes.stock()
		# ACCOUNT: the look is the player's, on every server.
		_add(schema, DotSettingsDef.choice(&"ui_theme", t.default_id(), t.ids(), &"hud")
			.with_scope(account)
			.with_description("The colours of the menus and the HUD."))
		# ACCOUNT, for the theme's reason. 0.7 to 1.4: below that the words are dust, above it
		# the pieces of a 1280x720 HUD run into each other.
		_add(schema, DotSettingsDef.number(&"hud_scale", 1.0, 0.7, 1.4, &"hud", 0.05)
			.with_scope(account)
			.with_description("How large the HUD is drawn."))
		_add(schema, DotSettingsDef.boolean(&"show_fps", false, &"video"))
		var _ns := declare_net_stat(schema)
		# DEVICE (per game): column keys differ by game. Text, not a set, because the
		# columns exist only once the game has made its scoreboard; see DotMenuScoreboard.
		_add(schema, DotSettingsDef.text(DotMenuScoreboard.SETTING, "", &"hud")
			.with_description("Scoreboard columns the player turned off, by key; +key turns one on that the game hides."))

	if groups.has(GROUP_VOICE):
		# ACCOUNT: how a person likes to talk is theirs on every server. The device is a fact
		# about this machine, so DEVICE.
		_add(schema, DotSettingsDef.choice(
			&"voice_mode", &"push_to_talk", [&"push_to_talk", &"open_mic"] as Array[StringName], &"audio"
		).with_scope(account).with_description(
			"Push to talk sends while the key is held; an open microphone sends whenever you speak."
		))
		_add(schema, DotSettingsDef.text(&"voice_input_device", "Default", &"audio")
			.with_description("The microphone, by the name the system gives it."))

	if groups.has(GROUP_CHAT):
		_add(schema, DotSettingsDef.choice(
			&"chat_window", &"auto", [&"auto", &"on", &"off"] as Array[StringName], &"chat"
		).with_scope(account).with_description(
			"auto hides the box on a server already carrying chat somewhere the player can see it."
		))

	return schema


## `net_stat`, `net_stat_height` and `net_stat_position` alone, for a game with its own
## settings and no [DotMenu] (it draws them with [method DotMenuNetStat.follow]).
## [method declare] adds them with the interface group.
##
## net_stat is the console command too: every console here binds the schema's keys, so
## `net_stat 2` and the Advanced page are one value. An integer for that reason — the
## level a person types. DEVICE: it is a diagnosis of this machine's connection.
## [param corner] is the default corner, for a game whose HUD already holds the top right.
static func declare_net_stat(schema: DotSettingsSchema, corner: StringName = &"") -> DotSettingsSchema:
	var default_corner: StringName = corner if DotMenuNetStat.POSITIONS.has(corner) else DotMenuNetStat.POSITIONS[0]
	_add(schema, DotSettingsDef.integer(&"net_stat", 0, 0, 3, &"network")
		.with_description("The connection overlay: 0 off, 1 numbers, 2 and a graph, 3 everything."))
	_add(schema, DotSettingsDef.integer(&"net_stat_height", 96, DotMenuNetStat.MIN_HEIGHT, DotMenuNetStat.MAX_HEIGHT, &"network")
		.with_description("The height of net_stat's graph, in pixels."))
	_add(schema, DotSettingsDef.choice(&"net_stat_position", default_corner, DotMenuNetStat.POSITIONS, &"network")
		.with_description("The corner net_stat is drawn in."))
	return schema


## Whether this project ships a first-person view model (a global script class, so no addon is named).
static func has_view_model() -> bool:
	for c in ProjectSettings.get_global_class_list():
		if c.get("class") == VIEW_MODEL_CLASS:
			return true
	return false


static func _add(schema: DotSettingsSchema, def: DotSettingsDef) -> void:
	if not schema.has(def.key):
		schema.add(def)


## A settings manager over [param schema], stored under [param directory], namespaced as
## [param app] with ACCOUNT settings shared under the family's `tmc_account`. Not set up:
## the caller adds it to the tree and calls `setup()`.
##
## [b]Not registered as a service[/b]: a server and a client in one editor session, and a
## suite, hold two of these, and a registry name would be the last one's.
static func manager(
	schema: DotSettingsSchema, directory: String, app: StringName,
	shared: StringName = &"tmc_account", store: DotSettingsStore = null
) -> DotSettingsManager:
	var m := DotSettingsManager.new()
	m.name = "Settings"
	m.schema = schema
	m.local_store = store if store != null else DotSettingsStoreFile.new(directory)
	m.app_namespace = app
	m.shared_namespace = shared
	m.register_as_service = false
	return m


# --- Pages ------------------------------------------------------------------------

## General, Video, Audio, Controls and Advanced, with a row for every stock setting.
## [param config] supplies the frame-rate list; null is the stock one.
static func pages(config: DotMenuConfig = null) -> Array[DotMenuPage]:
	var out: Array[DotMenuPage] = [general_page(), video_page(config), audio_page(), controls_page(), advanced_page()]
	return out


## What a player opens to find out why it feels slow, and does not need otherwise.
static func advanced_page() -> DotMenuPage:
	var p := DotMenuPage.make(&"advanced", "Advanced", "Diagnostics. Saved on this device.")
	p.section("Network") \
		.add(DotMenuRow.select(&"net_stat", "Connection overlay",
			"What the connection is doing, over the game. The console's net_stat sets the same thing.",
			[[0, "Off"], [1, "Numbers"], [2, "Numbers and graph"], [3, "Everything"]])) \
		.add(DotMenuRow.slider(&"net_stat_height", "Graph height", "")
			.with_range(DotMenuNetStat.MIN_HEIGHT, DotMenuNetStat.MAX_HEIGHT, 8)
			.formatted(func(v: float) -> String: return "%d px" % roundi(v))) \
		.add(DotMenuRow.select(&"net_stat_position", "Corner", "",
			[[&"top_right", "Top right"], [&"bottom_right", "Bottom right"], [&"top_left", "Top left"], [&"bottom_left", "Bottom left"]]))
	return p


static func general_page() -> DotMenuPage:
	var p := DotMenuPage.make(&"general", "General", "How the game looks and what is on the screen.")
	p.section("Interface") \
		.add(DotMenuRow.select(&"ui_theme", "Theme", "The menus and the HUD.")) \
		.add(DotMenuRow.slider(&"hud_scale", "HUD size", "How large health, ammunition, the clock and the rest are drawn.")
			.formatted(DotMenuRow.FORMAT_PERCENT)) \
		.add(DotMenuRow.toggle(&"show_fps", "Frame rate counter", "In the top-right corner."))
	# Its rows are the live scoreboard's columns, supplied by DotMenu when the page is drawn.
	var _board := p.section("Scoreboard")
	p.section("Comfort") \
		.add(DotMenuRow.slider(&"shake_scale", "Camera shake", "How hard the view shakes for a landing, a hit or an explosion.")
			.formatted(DotMenuRow.FORMAT_PERCENT_OR_OFF)) \
		.add(DotMenuRow.toggle(&"allow_flashes", "Screen flashes", "Full-screen flashes of colour."))
	p.section("Chat") \
		.add(DotMenuRow.select(&"chat_window", "Chat box", "Auto hides it on a server that already shows chat somewhere else.",
			[[&"auto", "Auto"], [&"on", "Always"], [&"off", "Never"]]))
	return p


static func video_page(config: DotMenuConfig = null) -> DotMenuPage:
	var p := DotMenuPage.make(&"video", "Video", "Window, frame rate and image quality. Saved on this device.")
	var display := p.section("Display")
	display.add(DotMenuRow.select(&"window_mode", "Window", "",
		[[&"windowed", "Windowed"], [&"borderless", "Borderless fullscreen"], [&"fullscreen", "Fullscreen"]]).only_native())
	# A page may go fullscreen only inside a click, and has no "borderless"; the keyboard
	# lock it asks for in fullscreen is what keeps Ctrl+W away from a game.
	display.add(DotMenuRow.select(&"window_mode", "Window",
		"Fullscreen also keeps browser shortcuts like Ctrl+W away from the game, in browsers that allow it.",
		[[&"windowed", "In the page"], [&"fullscreen", "Fullscreen"]]).only_on_web().named(&"window_mode_web"))
	display.add(DotMenuRow.toggle(&"vsync", "V-Sync", "Locks the frame rate to the screen. A browser always syncs."))
	display.add(fps_row(config))

	p.section("Image") \
		.add(DotMenuRow.slider(&"field_of_view", "Field of view", "").formatted(DotMenuRow.FORMAT_DEGREES)) \
		.add(DotMenuRow.slider(&"viewmodel_fov", "Weapon field of view", "How wide the lens that draws your hands and gun is. Lower is a larger gun.").formatted(DotMenuRow.FORMAT_DEGREES)) \
		.add(DotMenuRow.slider(&"render_scale", "Render scale", "Draw the 3D world at a lower resolution and scale it up.")
			.with_range(0.5, 1.0, 0.05).formatted(DotMenuRow.FORMAT_PERCENT)) \
		.add(DotMenuRow.select(&"fx_quality", "Effects", "Particles and other effects that change nothing about the game.",
			[[0, "Off"], [1, "Low"], [2, "Medium"], [3, "High"]]))
	return p


## Adds the "Blood splatters" row (`gore`, a game-declared setting dot-fx's decals read) to a
## video page's Image section. Not stock: only games with blood declare the key.
static func add_gore_row(video: DotMenuPage) -> void:
	if video == null:
		return
	video.section("Image").add(DotMenuRow.toggle(&"gore", "Blood splatters",
		"Blood on the walls and floor behind a body you hit. Off draws none."))


## The frame-rate select, built when the page is drawn so the list always holds the value
## stored — a cap typed at the console must not vanish from the list that shows it.
static func fps_row(config: DotMenuConfig = null) -> DotMenuRow:
	var cfg := config if config != null else DotMenuConfig.new()
	var row := DotMenuRow.select(&"fps_max", "Max frame rate",
		"Unlimited by default. Capping it saves power and can steady a stuttering machine.")
	row.options = fps_options(cfg.fps_list())
	return row


static func fps_options(list: Array[int]) -> Array:
	var out: Array = []
	for n in list:
		out.append([n, "Unlimited" if n == 0 else "%d fps" % n])
	return out


static func audio_page() -> DotMenuPage:
	var p := DotMenuPage.make(&"audio", "Audio", "Volume by kind of sound.")
	p.section("Volume") \
		.add(DotMenuRow.slider(&"master_volume", "Master").formatted(DotMenuRow.FORMAT_PERCENT)) \
		.add(DotMenuRow.slider(&"sfx_volume", "Effects", "Footsteps, weapons, the world.").formatted(DotMenuRow.FORMAT_PERCENT)) \
		.add(DotMenuRow.slider(&"ui_volume", "Interface", "Menus, and the round's own cues.").formatted(DotMenuRow.FORMAT_PERCENT)) \
		.add(DotMenuRow.slider(&"music_volume", "Music").formatted(DotMenuRow.FORMAT_PERCENT)) \
		.add(DotMenuRow.slider(&"voice_volume", "Voice chat").formatted(DotMenuRow.FORMAT_PERCENT))
	p.section("Voice chat") \
		.add(DotMenuRow.select(&"voice_mode", "Talk",
			"The microphone opens the first time you press the Push to talk key (Controls), never before.",
			[[&"push_to_talk", "Push to talk"], [&"open_mic", "Open microphone"]])) \
		.add(input_device_row())
	return p


## The microphone select, listing the devices the engine reports now. A stored device that is
## no longer plugged in stays in the list, as the frame-rate select keeps a typed cap.
static func input_device_row() -> DotMenuRow:
	var options: Array = []
	for device in AudioServer.get_input_device_list():
		options.append([device, "System default" if device == "Default" else device])
	return DotMenuRow.select(&"voice_input_device", "Microphone", "", options).only_native()


## Mouse, then one card per [DotMenuBindings] group, then a reset. The binding cards are
## filled from the menu's table when the page is drawn, so a row added to the table appears
## here without this page being edited.
static func controls_page() -> DotMenuPage:
	var p := DotMenuPage.make(&"controls", "Controls", "Mouse and key bindings. Keys are saved on this device.")
	p.show_bindings = true
	p.section("Mouse") \
		.add(DotMenuRow.slider(&"sensitivity", "Sensitivity",
			"0.022 degrees per count times this — the same number in every game that reads it.")
			.with_range(0.1, 10.0, 0.05).formatted(DotMenuRow.FORMAT_TWO_PLACES)) \
		.add(DotMenuRow.toggle(&"invert_mouse", "Invert vertical look"))
	return p
