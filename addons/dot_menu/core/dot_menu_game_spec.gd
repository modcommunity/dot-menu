class_name DotMenuGameSpec
extends RefCounted

## What one game says about its settings menu, as data: its names, its field of view, the settings it adds to the stock
## ones, the stock keys it leaves out, its key table and what its help screen says. [DotMenuGameSettings] turns it into the
## node; a game ships a spec and, at most, a three-line shim that keeps its class name.

var schema_version: int = 1
## The brand on the menu and the help title ("How to play <brand>").
var brand_name: String = "Game"
## Where this game's own document lives (`user://<dir>`) and its namespace. ACCOUNT settings stay under `tmc_account`.
var settings_dir: String = "user://settings"
var app_namespace: StringName = &"game"

## The field of view the camera had before the menu existed, and still the default; the slider's range.
var default_fov: int = 92
var fov_min: int = 70
var fov_max: int = 120

## `reduce_motion` declared by the game itself (ACCOUNT scope, with this description), so it keeps its wording.
## Empty: not declared by the game.
var reduce_motion_text: String = ""
## Also puts a "Reduce motion" toggle with this description on the General page's Comfort section. Empty: no extra row.
var comfort_row_text: String = ""

## A `gore` toggle (dot-fx's decals read it) with this description, and its "Blood splatters" row on the Video page. Empty: the game has no blood.
var gore_text: String = ""

## The ambient sound toggle's description; it comes with an `ambient_volume`. Empty: the game has no ambient settings.
var ambient_text: String = ""

## Stock keys nothing in the game applies; left out of the document and the menu.
var not_applied: Array[StringName] = [&"ui_volume", &"shake_scale", &"allow_flashes", &"fx_quality", &"chat_window"]

## Makes the game's key table: a callable returning a [DotMenuBindings] (a game's `Bindings.make`).
var bindings_maker: Callable = Callable()

## `DotMenuConfig.help_hint` when not empty (`&"off"` hides the corner plate).
var help_hint: StringName = &""

## `DotMenuConfig.menu_button_corner` when not empty (a touch game keeps the thumbs' corner clear).
var menu_button_corner: StringName = &""

## `DotMenuConfig.open_on_pointer_release`: false for a game whose Escape belongs to something else.
var open_on_pointer_release: bool = true

## Hooks for what a plain spec cannot say. All optional; a spec that sets none behaves as before.
## False: the game has no field of view (a 2D game); leave it in [member not_applied] too.
var has_fov: bool = true
## Makes the schema the game's own settings start from (e.g. `DotSettingsSchema.from_config(...)`); the version, field of view and the rest are added to it. Empty: a new schema.
var base_schema: Callable = Callable()
## Further [DotSettingsDef]s, declared after gore and before the ambient pair / after the ambient pair.
var extra_defs: Array = []
var late_defs: Array = []
## Rows the stock pages do not have: `[page, section title, DotMenuRow]`, added after setup in this order.
var extra_rows: Array = []
## Pages of the game's own: `[callable returning a DotMenuPage, before_page_id]`, added after setup.
var page_makers: Array = []
## `DotSettingsManager.migrations`: schema version -> `func(doc: Dictionary) -> Dictionary`, run when a stored document is older.
var migrations: Dictionary = {}
## `DotMenuApplier.fov_transform` (e.g. `DotMenuApplier.vertical_from_horizontal_4_3`). Empty: the angle goes to the camera as it is.
var fov_transform: Callable = Callable()
## Runs at the start of `setup(store)` as `func(settings: DotMenuGameSettings, store: DotSettingsStore) -> DotSettingsStore`; the store it returns is used (a game's one-off file migration).
var before_setup: Callable = Callable()
## `DotMenuConfig.settings` overrides (e.g. a different default master volume), `{key: {"default": v}}`.
var config_settings: Dictionary = {}
## `DotMenuSettings.manage_pointer`.
var manage_pointer: bool = false

## The help screen: the goal, prose cards as [title, text], and sections as [title, rows, kind].
var help_about: String = ""
var help_cards: Array = []
var help_sections: Array = []


## The document: the game's field of view first, so it keeps its own default, then the game's settings, then the stock
## ones it applies.
func make_schema() -> DotSettingsSchema:
	var s: DotSettingsSchema = base_schema.call() if base_schema.is_valid() else DotSettingsSchema.new()
	s.version = schema_version
	if has_fov:
		s.add(DotSettingsDef.integer(&"field_of_view", default_fov, fov_min, fov_max, &"video").with_scope(
			DotSettingsDef.Scope.SERVER_CLAMPED
		))
	if reduce_motion_text != "":
		s.add(DotSettingsDef.boolean(&"reduce_motion", false, &"accessibility").with_scope(DotSettingsDef.Scope.ACCOUNT)
			.with_description(reduce_motion_text))
	if gore_text != "":
		s.add(DotSettingsDef.boolean(&"gore", true, &"video").with_description(gore_text))
	for def: DotSettingsDef in extra_defs:
		s.add(def)
	if ambient_text != "":
		s.add(DotSettingsDef.boolean(&"ambient", true, &"audio").with_description(ambient_text))
		s.add(DotSettingsDef.number(&"ambient_volume", 1.0, 0.0, 1.0, &"audio"))
	for def: DotSettingsDef in late_defs:
		s.add(def)
	return DotMenuStock.declare(s, DotMenuStock.DEFAULT_GROUPS, null, not_applied)


## The help screen's goal, cards and sections.
func fill_help(help: DotMenuHelp) -> void:
	help.about = help_about
	for card: Array in help_cards:
		help.add_text(card[0], card[1])
	for section: Array in help_sections:
		help.add_section(section[0], section[1], section[2] if section.size() > 2 else &"")
