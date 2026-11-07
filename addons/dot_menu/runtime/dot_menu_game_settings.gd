class_name DotMenuGameSettings
extends DotMenuSettings

## [DotMenuSettings] declared by data: a game passes a [DotMenuGameSpec] and has its settings, key table, help screen and
## Comfort row, with no settings class of its own to keep. Behaviour is the base class's.

var spec: DotMenuGameSpec = null


func _init(game_spec: DotMenuGameSpec = null) -> void:
	if game_spec == null:
		return
	spec = game_spec
	name = "Settings"
	directory = spec.settings_dir
	app_namespace = spec.app_namespace
	schema = spec.make_schema()
	config = DotMenuConfig.new()
	config.brand_name = spec.brand_name
	if spec.bindings_maker.is_valid():
		bindings = spec.bindings_maker.call()
	config.open_on_pointer_release = spec.open_on_pointer_release
	if spec.help_hint != &"":
		config.help_hint = spec.help_hint
	# By name: an older dot-menu has no such property.
	if spec.menu_button_corner != &"" and &"menu_button_corner" in config:
		config.set(&"menu_button_corner", spec.menu_button_corner)
	var _layered := config.load_layered()


func setup(store: DotSettingsStore = null, with_menu: bool = true) -> DotResult:
	var made := super.setup(store, with_menu)
	if menu != null and spec != null and spec.gore_text != "":
		DotMenuStock.add_gore_row(menu.page(&"video"))
	if menu != null and spec != null and spec.comfort_row_text != "":
		var general := menu.page(&"general")
		if general != null:
			general.section("Comfort").add(DotMenuRow.toggle(&"reduce_motion", "Reduce motion", spec.comfort_row_text))
	return made


func _fill_help(help: DotMenuHelp) -> void:
	if spec != null:
		spec.fill_help(help)
