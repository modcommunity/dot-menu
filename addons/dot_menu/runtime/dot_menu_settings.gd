class_name DotMenuSettings
extends Node

## A player's settings, what applies them, and the menu that changes them, as one node.
##
## [codeblock]
## var settings := DotMenuSettings.new()
## settings.directory = "user://my_game_settings"
## settings.app_namespace = &"my_game"
## settings.schema = my_schema()          # null is the stock set
## add_child(settings)
## settings.setup()                       # loads, applies everything, builds the menu
## settings.bind_look(sampler.tunables)
## settings.bind_camera(camera)
## settings.bind_audio(audio)
## settings.menu_state_changed.connect(func(open): sampler.suspended = open)
## [/codeblock]
##
## [b]The shape six games had written by hand.[/b] Each minigame carried a two-hundred-and-
## fifty-line file that was this node with its class renamed: a manager, a `match` that
## pushed four keys at a sampler, a camera and a mixer, and a `DotSettingsScreen` on a
## stack. A game now subclasses this for its schema and its defaults and keeps the API its
## client already called, and the screen it opens is the full menu.
##
## [b]`setup` applies before it returns[/b] ([DotMenuApplier]'s reason: a stored value has not
## changed, so a game that waits for `changed` ignores every saved one), and anything bound
## after is applied as it is bound.

const CHANNEL := "menu.settings"

## A menu opened or the last one closed. What a client suspends its input sampler on.
signal menu_state_changed(any_open: bool)

## Where this game's own document lives. The shared account document is dot-settings'.
var directory: String = "user://settings"
var app_namespace: StringName = &"game"
## ACCOUNT settings are shared under this name; the family's is `tmc_account`.
var shared_namespace: StringName = &"tmc_account"

## The settings. Null at setup is [method DotMenuStock.declare] over the default groups.
var schema: DotSettingsSchema = null

## The developer's config. Null at setup is the stock one; it is layered (file, env, argv)
## only if the caller did so.
var config: DotMenuConfig = null

## Keys a client reads, if it has a table. Null draws no key cards.
var bindings: DotMenuBindings = null

## Free the pointer while the menu is open and capture it after. Off for a client that owns
## its pointer and does both on [signal menu_state_changed].
var manage_pointer: bool = false

## Built by [method setup].
var settings: DotSettingsManager = null
var applier: DotMenuApplier = null
var menu: DotMenu = null


## Loads the document, applies it, and builds the menu. [param store] replaces the file
## store, which is what a suite does; [param with_menu] false builds the document alone (a
## server, or a suite that does not want a screen).
func setup(store: DotSettingsStore = null, with_menu: bool = true) -> DotResult:
	if config == null:
		config = DotMenuConfig.new()
	if schema == null:
		schema = DotMenuStock.declare(DotSettingsSchema.new())
	# The talk key goes with the voice settings, so every game that has them has the key in
	# its table, its Controls page and its help screen, on the same setting.
	if bindings != null and schema.has(&"voice_mode") and bindings.row_for_action(&"dot_voice_talk").is_empty():
		var _v := bindings.add_voice("Communication", bindings.free_key(["V", "K", "B", "X"]))
	if bindings != null:
		bindings.add_to_schema(schema)
	var themes := config.make_themes()
	var _problems := config.apply_to_schema(schema, themes)

	settings = DotMenuStock.manager(schema, directory, app_namespace, shared_namespace, store)
	add_child(settings)
	var loaded := settings.setup()
	if not loaded.ok:
		return loaded.wrap("the player's settings")

	applier = DotMenuApplier.new()
	applier.name = "Applier"
	applier.settings = settings
	applier.bindings = bindings
	add_child(applier)
	var _applied := applier.setup()

	if with_menu:
		menu = DotMenu.new()
		menu.settings = settings
		menu.bindings = bindings
		menu.config = config
		menu.themes = themes
		menu.manage_pointer = manage_pointer
		add_child(menu)
		var built := menu.setup()
		if not built.ok:
			# Not fatal: the document still applies, which is most of what matters. The menu
			# is how a player changes it, and a WARN says it is not there.
			DotLog.warn(CHANNEL, "no menu", {"why": built.error.message})
			menu.queue_free()
			menu = null
		else:
			menu.overlays_changed.connect(func(open: bool) -> void: menu_state_changed.emit(open))
			applier.voice_available_changed.connect(_on_voice_available)

	return DotResult.success(self)


# --- What reads them ----------------------------------------------------------

func bind_look(tunables: Object) -> void:
	if applier != null:
		applier.bind_look(tunables)


func bind_camera(camera: Object, property: StringName = &"fov") -> void:
	if applier != null:
		applier.bind_camera(camera, property)


func bind_audio(audio: Object) -> void:
	if applier != null:
		applier.bind_audio(audio)


## A player's own voice (dot-voice's `DotVoiceManager`). Rarely needed: the applier binds
## whatever is published as `dot_voice_client` by itself.
func bind_voice(voice: Object) -> void:
	if applier != null:
		applier.bind_voice(voice)


## The server's `sv_voice_enable`, through the bound voice: off hides the voice rows and the
## talk key, because a key that does nothing on this server is a key a player presses and
## then reports.
func _on_voice_available(available: bool) -> void:
	if menu != null:
		menu.hide_rows(&"voice", PackedStringArray() if available else DotMenuStock.VOICE_ROWS)


func bind_fx(fx: Object) -> void:
	if applier != null:
		applier.bind_fx(fx)


## Pushes every value at what reads it again.
func apply_all() -> void:
	if applier != null:
		applier.apply_all()


# --- The menu -----------------------------------------------------------------

func is_open() -> bool:
	return menu != null and menu.any_open()


func open(page: StringName = &"") -> void:
	if menu != null and not menu.is_open():
		menu.open(page)


func close() -> void:
	if menu != null:
		menu.close_all()


func describe() -> Dictionary:
	var out := settings.describe() if settings != null else {}
	var applied := applier.describe() if applier != null else {}
	out["open"] = is_open()
	out["look_bound"] = int(applied.get("look", 0))
	out["camera_bound"] = int(applied.get("cameras", 0)) > 0
	out["audio_bound"] = int(applied.get("audio", 0)) > 0
	out["menu"] = menu != null
	return out
