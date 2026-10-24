class_name DotMenuApplier
extends Node

## Pushes every setting at whatever it controls, once after load and on every change after.
##
## [codeblock]
## var applier := DotMenuApplier.new()
## applier.settings = settings
## applier.bindings = keys
## add_child(applier)
## applier.bind_audio(audio)                  # a DotAudioManager, or its mixer
## applier.bind_fx(fx)                        # a DotFxManager, or its config
## applier.bind_look(sampler.tunables)        # sensitivity and invert
## applier.bind_camera(camera)                # field of view
## applier.on(&"show_own_body", func(v, _why): player.show_own_body = v)
## applier.setup()                            # connects, and applies everything now
## [/codeblock]
##
## [b]`apply_all()` on load, and it is the line this family keeps losing.[/b] A value read
## from disk has not CHANGED, so a game that applies settings only from `changed` ignores
## every saved one until the player touches it — their saved sensitivity does nothing and
## the slider shows the number they chose. Every value is pushed once at [method setup] and
## again whenever something new is bound, then `changed` keeps them current.
##
## [b]Duck-typed, so dot-menu depends on none of what it drives.[/b] An audio target is
## anything with `master`/`sfx`/`ui`/`music`/`voice` (dot-audio's mixer) or a `mixer` that
## has them; with none bound the volumes go straight onto the [AudioServer]'s buses of those
## names, so a game with no dot-audio still has working sliders. An fx target is anything
## with `shake_scale`, `allow_flashes` and `quality`. A look target is anything with
## `mouse_sensitivity` and `invert_look_y` ([DotFpsTunables] — neither is in its movement
## fingerprint, so a client writing them can never disagree with its server).
##
## [b]Two stock settings need the game[/b] and are left to [method on]: `chat_window` (only
## the game knows whether its server carries chat elsewhere) and `ui_theme`/`hud_scale`/`show_fps`/`net_stat*`, which
## [DotMenu] applies itself because it owns what they change.

const CHANNEL := "menu.apply"

## Degrees of view per unit of mouse motion at a sensitivity of 1.
##
## [b]The family's constant, so a player's one number means one turning speed in every game
## that reads it.[/b] It is the genre's own `m_yaw`; a game that converted differently would
## turn a player's sensitivity into two speeds.
const DEGREES_PER_COUNT := 0.022

## A settings key, the dot-audio mixer field it sets, and the [AudioServer] bus it falls back to.
const VOLUMES := {
	&"master_volume": [&"master", &"Master"],
	&"sfx_volume": [&"sfx", &"SFX"],
	&"ui_volume": [&"ui", &"UI"],
	&"music_volume": [&"music", &"Music"],
	&"voice_volume": [&"voice", &"Voice"],
}

## Every stock key this applies, and which of them [DotMenu] applies instead. The suite holds
## [constant DotMenuStock.KEYS] to these two lists and [constant LEFT_TO_THE_GAME], so a stock
## setting nothing applies — this family's most repeated bug — fails a check rather than
## shipping as a switch that does nothing.
const APPLIES: Array[StringName] = [
	&"master_volume", &"sfx_volume", &"ui_volume", &"music_volume", &"voice_volume",
	&"voice_mode", &"voice_input_device",
	&"fps_max", &"vsync", &"window_mode", &"render_scale",
	&"shake_scale", &"allow_flashes", &"fx_quality",
	&"sensitivity", &"invert_mouse", &"field_of_view", &"viewmodel_fov",
]
const APPLIED_BY_MENU: Array[StringName] = [
	&"ui_theme", &"hud_scale", &"show_fps", &"net_stat", &"net_stat_height", &"net_stat_position",
	&"scoreboard_hidden",
]

## Stock keys only the game can apply, through [method on]. See the class note.
const LEFT_TO_THE_GAME: Array[StringName] = [&"chat_window"]

## Nodes in this group with `set_hands_fov_at_4_3(horizontal)` get `viewmodel_fov`, now and
## when they are added (zee-dot-weapons' `ZeeViewModel` joins it itself).
const VIEW_MODEL_GROUP := &"dot_view_model"

## The registry name a client publishes its own player's voice under (dot-voice's
## `DotVoiceManager.CLIENT_SERVICE`, as text: dot-menu does not depend on dot-voice).
const VOICE_SERVICE := &"dot_voice_client"

## A bound voice said whether its server allows voice (`sv_voice_enable`). [DotMenuSettings]
## hides the voice rows on false.
signal voice_available_changed(available: bool)

## Emitted after a key has been applied, with why (&"applied" at boot, else the reason
## [signal DotSettingsManager.changed] gave).
signal applied(key: StringName, value: Variant, why: StringName)

var settings: DotSettingsManager = null
var bindings: DotMenuBindings = null

## fps_max, vsync, window_mode and render_scale. Off for a host that owns its window — an
## editor plugin, a launcher showing a game inside it.
var manage_window: bool = true

## `func(sensitivity: float) -> float`, degrees per count. Unset is [constant DEGREES_PER_COUNT]
## times the setting.
var sensitivity_to_degrees: Callable = Callable()

## `func(field_of_view: float) -> float`, what the camera property is set to. Unset is the
## setting itself. For a game whose setting is in another measure (horizontal at 4:3).
var fov_transform: Callable = Callable()


## The vertical field of view (what [Camera3D] takes) that is [param horizontal] degrees across a
## 4:3 frame: the same number means the same view on any window, as in the other games.
static func vertical_from_horizontal_4_3(horizontal: float) -> float:
	var half := deg_to_rad(clampf(horizontal, 20.0, 170.0) * 0.5)
	return rad_to_deg(2.0 * atan(tan(half) * 0.75))

var _audio: Array[Object] = []
var _voice: Array[Object] = []
var _fx: Array[Object] = []
var _look: Array[Object] = []
## `[camera, property]` pairs.
var _cameras: Array[Array] = []
var _handlers: Dictionary = {}
var _any: Array[Callable] = []
var _connected := false


## Connects to the settings and applies every value now.
func setup() -> DotResult:
	if settings == null:
		DotLog.warn(CHANNEL, "setup refused: no settings bound", {"applier": str(get_path()) if is_inside_tree() else name})
		return DotResult.fail(DotError.CODE_STATE, "DotMenuApplier has no settings.")
	if not _connected:
		settings.changed.connect(_on_changed)
		_connected = true
		if is_inside_tree() and not get_tree().node_added.is_connected(_on_node_added):
			get_tree().node_added.connect(_on_node_added)
		# The voice is found, not handed over: a game's chat client publishes its manager
		# and this binds it whichever of the two is built first. A game wires nothing.
		var bus := DotRegistry.signals()
		if not bus.service_registered.is_connected(_on_service_registered):
			bus.service_registered.connect(_on_service_registered)
	var found := DotRegistry.get_service(VOICE_SERVICE)
	if found != null:
		bind_voice(found)
	apply_all()
	return DotResult.success(self)


func _on_service_registered(service: StringName, instance: Object) -> void:
	if service == VOICE_SERVICE and instance != null:
		bind_voice(instance)


func _exit_tree() -> void:
	if _connected and settings != null and settings.changed.is_connected(_on_changed):
		settings.changed.disconnect(_on_changed)
	var bus := DotRegistry.signals()
	if bus.service_registered.is_connected(_on_service_registered):
		bus.service_registered.disconnect(_on_service_registered)
	if is_inside_tree() and get_tree().node_added.is_connected(_on_node_added):
		get_tree().node_added.disconnect(_on_node_added)
	_connected = false


## Every key, as if each had just changed. See the class note for why this exists.
func apply_all() -> void:
	if settings == null or settings.schema == null:
		return
	# Two rows stored on one key (a default that moved under a saved document) are put right
	# before anything reaches the InputMap; see DotMenuBindings.settle.
	if bindings != null:
		var _settled := bindings.settle(settings)
	for key in settings.schema.keys():
		_apply(key, settings.get_value(key), &"applied")


## Calls [param handler] `(value, why)` whenever [param key] is applied, and once now if the
## settings are already loaded. Several handlers per key run in the order they were added.
func on(key: StringName, handler: Callable) -> DotMenuApplier:
	if not _handlers.has(key):
		_handlers[key] = []
	(_handlers[key] as Array).append(handler)
	if _connected and settings != null and settings.schema != null and settings.schema.has(key):
		handler.call(settings.get_value(key), &"applied")
	return self


## Calls [param handler] `(key, value, why)` for every key applied. For a game's own keys
## that it would rather `match` on in one place.
func on_any(handler: Callable) -> DotMenuApplier:
	_any.append(handler)
	return self


# --- What reads them ----------------------------------------------------------

func bind_audio(target: Object) -> void:
	_bind(_audio, target)
	_apply_volumes()


func bind_fx(target: Object) -> void:
	_bind(_fx, target)
	_apply_fx()


func bind_look(target: Object) -> void:
	_bind(_look, target)
	_apply_look()


## [param property] is what the camera's field of view is called: `fov` on a [Camera3D], or
## a game camera's own (`fov_desired`).
func bind_camera(camera: Object, property: StringName = &"fov") -> void:
	if camera == null:
		return
	for pair in _cameras:
		if pair[0] == camera:
			return
	_cameras.append([camera, property])
	_apply_fov()


## A player's own voice: anything with `set_open_mic(bool)`, `set_input_device(String)` and
## `set_volume(float)` (dot-voice's `DotVoiceManager`), and optionally `server_enabled` and a
## `server_enabled_changed(bool)` signal, which [signal voice_available_changed] passes on.
## Bound automatically when one is published as `dot_voice_client`.
func bind_voice(target: Object) -> void:
	if target == null or _voice.has(target):
		return
	_prune(_voice)
	_voice.append(target)
	if target.has_signal(&"server_enabled_changed") and not target.is_connected(&"server_enabled_changed", _on_voice_available):
		target.connect(&"server_enabled_changed", _on_voice_available)
	_apply_voice()
	if &"server_enabled" in target:
		voice_available_changed.emit(bool(target.get(&"server_enabled")))


func _on_voice_available(available: bool) -> void:
	voice_available_changed.emit(available)


func unbind(target: Object) -> void:
	_voice.erase(target)
	_audio.erase(target)
	_fx.erase(target)
	_look.erase(target)
	for i in range(_cameras.size() - 1, -1, -1):
		if _cameras[i][0] == target:
			_cameras.remove_at(i)


func _bind(list: Array[Object], target: Object) -> void:
	if target != null and not list.has(target):
		list.append(target)


# --- Applying -----------------------------------------------------------------

func _on_changed(key: StringName, value: Variant, why: StringName) -> void:
	_apply(key, value, why)


func _apply(key: StringName, value: Variant, why: StringName) -> void:
	if VOLUMES.has(key):
		_apply_volumes()
		if key == &"voice_volume":
			_apply_voice()
	elif key == &"voice_mode" or key == &"voice_input_device":
		_apply_voice()
	else:
		match key:
			&"fps_max":
				if manage_window:
					Engine.max_fps = maxi(int(value), 0)
			&"vsync":
				if manage_window:
					_apply_vsync(bool(value))
			&"window_mode":
				if manage_window:
					_apply_window_mode(StringName(str(value)), why)
			&"render_scale":
				if manage_window and is_inside_tree():
					get_viewport().scaling_3d_scale = clampf(float(value), 0.25, 2.0)
			&"shake_scale", &"allow_flashes", &"fx_quality":
				_apply_fx()
			&"sensitivity", &"invert_mouse":
				_apply_look()
			&"field_of_view":
				_apply_fov()
			&"viewmodel_fov":
				_apply_view_models()
			_:
				if bindings != null:
					var _bound := bindings.apply_setting(key, value)

	if _handlers.has(key):
		for h in (_handlers[key] as Array):
			(h as Callable).call(value, why)
	for h in _any:
		h.call(key, value, why)
	applied.emit(key, value, why)


func _has(key: StringName) -> bool:
	return settings != null and settings.schema != null and settings.schema.has(key)


func _apply_volumes() -> void:
	if settings == null:
		return
	_prune(_audio)

	if _audio.is_empty():
		_volumes_to_buses()
		return

	for target in _audio:
		var mixer: Object = target.get("mixer") if "mixer" in target else target
		if mixer == null:
			continue
		for key in VOLUMES:
			var field: StringName = VOLUMES[key][0]
			if _has(key) and field in mixer:
				mixer.set(field, settings.get_float(key, 1.0))
		if mixer.has_method("apply_to_buses"):
			var _made: Variant = mixer.call("apply_to_buses")


## No mixer: each volume straight onto the bus of its name, where there is one.
func _volumes_to_buses() -> void:
	for key in VOLUMES:
		if not _has(key):
			continue
		var bus := AudioServer.get_bus_index(String(VOLUMES[key][1]))
		if bus < 0:
			continue
		var linear := clampf(settings.get_float(key, 1.0), 0.0, 1.0)
		AudioServer.set_bus_volume_db(bus, linear_to_db(linear) if linear > 0.0 else -80.0)


func _apply_voice() -> void:
	if settings == null:
		return
	_prune(_voice)
	var device := settings.get_string(&"voice_input_device", "Default") if _has(&"voice_input_device") else ""
	if _voice.is_empty():
		# Nothing to tell, but the device is the engine's, so it can still be set.
		if device != "" and AudioServer.get_input_device_list().has(device):
			AudioServer.input_device = device
		return
	for target in _voice:
		if _has(&"voice_mode") and target.has_method(&"set_open_mic"):
			target.call(&"set_open_mic", settings.get_string(&"voice_mode", "push_to_talk") == "open_mic")
		if device != "" and target.has_method(&"set_input_device"):
			var _known: Variant = target.call(&"set_input_device", device)
		# The voice bus is already set by the volumes; a voice with no bus of its own takes
		# the level here.
		if _has(&"voice_volume") and target.has_method(&"set_volume") and AudioServer.get_bus_index(&"Voice") < 0:
			target.call(&"set_volume", settings.get_float(&"voice_volume", 1.0))


func _apply_fx() -> void:
	if settings == null:
		return
	_prune(_fx)
	for target in _fx:
		var cfg: Object = target.get("config") if "config" in target else target
		if cfg == null:
			continue
		if _has(&"shake_scale") and "shake_scale" in cfg:
			cfg.set(&"shake_scale", settings.get_float(&"shake_scale", 1.0))
		if _has(&"allow_flashes") and "allow_flashes" in cfg:
			cfg.set(&"allow_flashes", settings.get_bool(&"allow_flashes", true))
		if _has(&"fx_quality") and "quality" in cfg:
			cfg.set(&"quality", settings.get_int(&"fx_quality", 3))


func _apply_look() -> void:
	if settings == null:
		return
	_prune(_look)
	var degrees := degrees_per_count(settings.get_float(&"sensitivity", 2.5))
	for target in _look:
		if _has(&"sensitivity") and "mouse_sensitivity" in target:
			target.set(&"mouse_sensitivity", degrees)
		if _has(&"invert_mouse") and "invert_look_y" in target:
			target.set(&"invert_look_y", settings.get_bool(&"invert_mouse", false))


func _apply_view_models() -> void:
	if is_inside_tree() and _has(&"viewmodel_fov"):
		get_tree().call_group(VIEW_MODEL_GROUP, &"set_hands_fov_at_4_3", settings.get_float(&"viewmodel_fov", 65.0))


func _on_node_added(node: Node) -> void:
	if node.is_in_group(VIEW_MODEL_GROUP) and _has(&"viewmodel_fov"):
		node.call(&"set_hands_fov_at_4_3", settings.get_float(&"viewmodel_fov", 65.0))


func _apply_fov() -> void:
	if settings == null or not _has(&"field_of_view"):
		return
	for i in range(_cameras.size() - 1, -1, -1):
		if not is_instance_valid(_cameras[i][0]):
			_cameras.remove_at(i)
	var fov := float(settings.get_value(&"field_of_view"))
	if fov_transform.is_valid():
		fov = float(fov_transform.call(fov))
	for pair in _cameras:
		(pair[0] as Object).set(pair[1], fov)


## Sensitivity as degrees per unit of mouse motion. See [constant DEGREES_PER_COUNT].
func degrees_per_count(sensitivity: float) -> float:
	if sensitivity_to_degrees.is_valid():
		return float(sensitivity_to_degrees.call(sensitivity))
	return maxf(sensitivity, 0.0) * DEGREES_PER_COUNT


func _prune(list: Array[Object]) -> void:
	for i in range(list.size() - 1, -1, -1):
		if not is_instance_valid(list[i]):
			list.remove_at(i)


## V-Sync, on a window that has one. A headless run (every suite) has no window, and the
## call is skipped rather than left to fail.
func _apply_vsync(on: bool) -> void:
	if DisplayServer.get_name() == "headless":
		return
	DisplayServer.window_set_vsync_mode(
		DisplayServer.VSYNC_ENABLED if on else DisplayServer.VSYNC_DISABLED
	)


## Windowed, borderless or fullscreen.
##
## [b]In a browser, only when the player just asked.[/b] A page may go fullscreen only inside
## a user gesture, so the stored value is NOT applied at boot there — it would be refused,
## and the refusal reads as a setting that does not work. Chosen from the menu, the choice
## arrives inside the click that made it.
##
## [b]And it asks the browser for the keyboard.[/b] Ctrl+W, Ctrl+T and Ctrl+N are the
## browser's and no page can cancel them — and Ctrl is Duck in the genre's bindings, so a
## player holding duck and pressing forward closes the tab. In fullscreen, browsers that
## have it let a page lock the keyboard (`navigator.keyboard.lock()`), after which those keys
## reach the game and Escape has to be HELD to leave. Elsewhere the call does not exist and
## nothing happens.
func _apply_window_mode(mode: StringName, why: StringName) -> void:
	if DisplayServer.get_name() == "headless":
		return

	if DotPlatform.is_web():
		if why == &"applied":
			return
		if mode == &"windowed":
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			return
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		var _locked: Variant = JavaScriptBridge.eval(
			"(navigator.keyboard && navigator.keyboard.lock) ? (navigator.keyboard.lock(), true) : false",
			true
		)
		return

	match mode:
		&"fullscreen":
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
		&"borderless":
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		_:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)


func describe() -> Dictionary:
	return {
		"audio": _audio.size(), "fx": _fx.size(), "look": _look.size(),
		"cameras": _cameras.size(), "handlers": _handlers.size(),
		"manage_window": manage_window,
	}
