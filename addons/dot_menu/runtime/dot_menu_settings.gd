class_name DotMenuSettings
extends Node

## A player's settings, what applies them, and the menu that changes them, as one node. Example: docs/examples.md.
## A game subclasses this for its schema and defaults and keeps the API its client already called.
## `setup` applies before it returns ([DotMenuApplier]'s reason), and anything bound after is applied as it is bound.

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

## Keys a client reads, if it has a table. Null at setup is a table holding the help key alone.
var bindings: DotMenuBindings = null

## Leave does the stock thing (API 4): off the server when connected, quit when solo on a
## desktop. See [member DotMenu.leave_on_its_own]. Off for a game that leaves its own way.
var leave_on_its_own: bool = true

## The map menu key, M, in this game's table (API 5): on for every game, because every game
## in the family has more than one map, course or layout. The key does nothing until the
## client calls [method use_maps]; a game with one map turns this off.
var map_menu: bool = true

## The loadout menu key, B, in this game's table (API 6): on for a game where players choose
## what they carry, off by default because most of the family's games hand out their kit. The
## key does nothing until the client calls [method use_loadout].
var loadout_menu: bool = false

## The emote, pose and gesture keys on the Controls page (API 16), for a game that plays avatar actions.
var avatar_actions: bool = false

## Free the pointer while the menu is open and capture it after. Off for a client that owns
## its pointer and does both on [signal menu_state_changed].
var manage_pointer: bool = false

## Built by [method setup].
var settings: DotSettingsManager = null
var applier: DotMenuApplier = null

## [member DotSettingsManager.migrations] for the game's schema versions, set before [method setup].
var migrations: Dictionary = {}
var menu: DotMenu = null


## Loads the document, applies it, and builds the menu. [param store] replaces the file
## store, which is what a suite does; [param with_menu] false builds the document alone (a
## server, or a suite that does not want a screen).
func setup(store: DotSettingsStore = null, with_menu: bool = true) -> DotResult:
	if config == null:
		config = DotMenuConfig.new()
	if schema == null:
		schema = DotMenuStock.declare(DotSettingsSchema.new())
	# The loadout key first, so B is the loadout's and the talk key's fallbacks skip it.
	if loadout_menu and bindings != null and bindings.row_for_action(DotMenuBindings.LOADOUT_ACTION).is_empty() \
			and bindings.row_for_setting(DotMenuBindings.LOADOUT_SETTING).is_empty():
		var _l := bindings.add_loadout("", bindings.free_key([DotMenuBindings.LOADOUT_KEY, "F4"]))
	# The talk key goes with the voice settings, so every game that has them has the key in
	# its table, its Controls page and its help screen, on the same setting.
	if bindings != null and schema.has(&"voice_mode") and bindings.row_for_action(&"dot_voice_talk").is_empty():
		var _v := bindings.add_voice("Communication", bindings.free_key(["V", "K", "B", "X"]))
	# The help key, H, in every game's table (API 4), unless the game put its own help row
	# in. A game with no table gets one with the help key alone, so H is still a rebindable
	# key on the Controls page rather than a key nothing lists.
	if bindings == null:
		bindings = DotMenuBindings.new()
	if bindings.row_for_action(DotMenuBindings.HELP_ACTION).is_empty() \
			and bindings.row_for_setting(DotMenuBindings.HELP_SETTING).is_empty():
		var _h := bindings.add_help("", bindings.free_key([DotMenuBindings.HELP_KEY, "F1"]))
	# The map menu key, M (API 5), the same way: a game's own row on that action or setting is
	# kept. On M unless the game ships something there, which its suite fails on.
	if loadout_menu and bindings.row_for_action(DotMenuBindings.LOADOUT_ACTION).is_empty() \
			and bindings.row_for_setting(DotMenuBindings.LOADOUT_SETTING).is_empty():
		var _l := bindings.add_loadout("", bindings.free_key([DotMenuBindings.LOADOUT_KEY, "F4"]))
	if avatar_actions and bindings.row_for_action(DotMenuBindings.AVATAR_EMOTE_ACTION).is_empty() \
			and bindings.row_for_setting(DotMenuBindings.AVATAR_EMOTE_SETTING).is_empty():
		var _a := bindings.add_avatar_actions()
	if map_menu and bindings.row_for_action(DotMenuBindings.MAPS_ACTION).is_empty() \
			and bindings.row_for_setting(DotMenuBindings.MAPS_SETTING).is_empty():
		var _m := bindings.add_maps("", bindings.free_key([DotMenuBindings.MAPS_KEY, "F3"]))
	bindings.add_to_schema(schema)
	var themes := config.make_themes()
	var _problems := config.apply_to_schema(schema, themes)

	settings = DotMenuStock.manager(schema, directory, app_namespace, shared_namespace, store)
	settings.migrations = migrations
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
		menu.leave_on_its_own = leave_on_its_own
		var own_help := bindings.row_for_setting(DotMenuBindings.HELP_SETTING)
		if not own_help.is_empty():
			menu.help_action = own_help["action"]
		add_child(menu)
		var built := menu.setup()
		if not built.ok:
			# Not fatal: the document still applies, which is most of what matters. The menu
			# is how a player changes it, and a WARN says it is not there.
			DotLog.warn(CHANNEL, "no menu", {"why": built.error.message})
			menu.queue_free()
			menu = null
		else:
			_fill_help(menu.help)
			menu.overlays_changed.connect(func(open: bool) -> void: menu_state_changed.emit(open))
			applier.voice_available_changed.connect(_on_voice_available)

	return DotResult.success(self)


## What only the game can say on its help screen: [member DotMenuHelp.about] (the goal), and cards from
## [method DotMenuHelp.add_text] and [method DotMenuHelp.add_section]. The keys are drawn from the table.
## Called once, after the menu is built; a game overrides it.
func _fill_help(_help: DotMenuHelp) -> void:
	pass


## The map menu: M opens [param rows_fn]'s list and solo [param change_fn] changes to the
## choice; on a server the server decides. See [method DotMenu.use_maps]. Null without a menu.
func use_maps(rows_fn: Callable, change_fn: Callable) -> DotMenuMaps:
	return menu.use_maps(rows_fn, change_fn) if menu != null else null


## The loadout menu: B opens what [param offer_fn] returns and solo [param choose_fn] saves the
## choice; on a server the server decides. See [method DotMenu.use_loadout]. Null without a menu.
func use_loadout(offer_fn: Callable, choose_fn: Callable, decorate_fn: Callable = Callable()) -> DotMenuLoadout:
	return menu.use_loadout(offer_fn, choose_fn, decorate_fn) if menu != null else null


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
