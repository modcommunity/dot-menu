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
## The theme and the frame-rate counter.
const GROUP_INTERFACE := &"interface"
## Whether the chat box is drawn.
const GROUP_CHAT := &"chat"
## A music volume. Not in [constant DEFAULT_GROUPS]: a slider for a bus nothing plays on is
## a control that does nothing, and most games here have no music.
const GROUP_MUSIC := &"music"

## What [method declare] adds when it is not told: everything except music.
const DEFAULT_GROUPS: Array[StringName] = [
	GROUP_AUDIO, GROUP_VIDEO, GROUP_CONTROLS, GROUP_COMFORT, GROUP_INTERFACE, GROUP_CHAT,
]

const ALL_GROUPS: Array[StringName] = [
	GROUP_AUDIO, GROUP_MUSIC, GROUP_VIDEO, GROUP_CONTROLS, GROUP_COMFORT, GROUP_INTERFACE, GROUP_CHAT,
]

## Every key [method declare] can add, by group. What a suite checks the applier against.
const KEYS := {
	GROUP_AUDIO: [&"master_volume", &"sfx_volume", &"ui_volume", &"voice_volume"],
	GROUP_MUSIC: [&"music_volume"],
	GROUP_VIDEO: [&"window_mode", &"vsync", &"fps_max", &"render_scale", &"field_of_view", &"fx_quality"],
	GROUP_CONTROLS: [&"sensitivity", &"invert_mouse"],
	GROUP_COMFORT: [&"shake_scale", &"allow_flashes"],
	GROUP_INTERFACE: [&"ui_theme", &"show_fps"],
	GROUP_CHAT: [&"chat_window"],
}


## Declares the stock settings in [param groups] (by default [constant DEFAULT_GROUPS]) that [param schema] does not have yet.
## [param themes] supplies the `ui_theme` options; null is the stock six.
static func declare(
	schema: DotSettingsSchema, groups: Array[StringName] = DEFAULT_GROUPS, themes: DotMenuThemes = null
) -> DotSettingsSchema:
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
		_add(schema, DotSettingsDef.boolean(&"show_fps", false, &"video"))

	if groups.has(GROUP_CHAT):
		_add(schema, DotSettingsDef.choice(
			&"chat_window", &"auto", [&"auto", &"on", &"off"] as Array[StringName], &"chat"
		).with_scope(account).with_description(
			"auto hides the box on a server already carrying chat somewhere the player can see it."
		))

	return schema


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

## General, Video, Audio and Controls, with a row for every stock setting. [param config]
## supplies the frame-rate list; null is the stock one.
static func pages(config: DotMenuConfig = null) -> Array[DotMenuPage]:
	var out: Array[DotMenuPage] = [general_page(), video_page(config), audio_page(), controls_page()]
	return out


static func general_page() -> DotMenuPage:
	var p := DotMenuPage.make(&"general", "General", "How the game looks and what is on the screen.")
	p.section("Interface") \
		.add(DotMenuRow.select(&"ui_theme", "Theme", "The menus and the HUD.")) \
		.add(DotMenuRow.toggle(&"show_fps", "Frame rate counter", "In the top-right corner."))
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
		.add(DotMenuRow.slider(&"render_scale", "Render scale", "Draw the 3D world at a lower resolution and scale it up.")
			.with_range(0.5, 1.0, 0.05).formatted(DotMenuRow.FORMAT_PERCENT)) \
		.add(DotMenuRow.select(&"fx_quality", "Effects", "Particles and other effects that change nothing about the game.",
			[[0, "Off"], [1, "Low"], [2, "Medium"], [3, "High"]]))
	return p


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
	return p


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
