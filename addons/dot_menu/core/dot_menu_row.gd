class_name DotMenuRow
extends RefCounted

## One line of a menu page: a title, a sentence under it, and the control on the right.
##
## [codeblock]
## DotMenuRow.toggle(&"show_fps", "Frame rate counter", "In the top-right corner.")
## DotMenuRow.slider(&"master_volume", "Master").formatted(DotMenuRow.FORMAT_PERCENT)
## DotMenuRow.select(&"window_mode", "Window")          # options from the setting itself
## DotMenuRow.live_toggle("Flashlight", "", is_on, set_on).enabled_when(server_allows)
## DotMenuRow.button("Arrange", "Drag the HUD around.", "Move HUD elements", open_editor)
## DotMenuRow.custom("Name", "", func(kit): return LineEdit.new())
## [/codeblock]
##
## [b]A setting row is a view of the setting, never a copy of it.[/b] It reads
## [DotSettingsManager] when its page is drawn and writes it when it is changed, so a value
## changed from a console is what the menu shows next time, and there is no Apply button
## because there is nothing left to apply. Its range and its options come from the
## setting's own [DotSettingsDef] unless the row narrows them — the declaration is the
## interface, which is dot-settings' rule, and a slider with a second copy of the range is
## a slider that will one day let a player pick a value the setting refuses.
##
## [b]A row whose setting the schema does not declare is not drawn.[/b] That is what lets
## the stock pages carry every stock row and a game declare only the settings it uses: the
## rows for the others simply are not there, rather than being switches that do nothing —
## this family's most repeated bug.
##
## A "live" row is not a setting: it is state somebody else owns — a server's rule, a
## flashlight the next server may refuse — read through [member getter] and written through
## [member setter]. Storing it would be a promise the next server is free to break.

enum Kind {
	## On or off. A setting row reads a BOOL; a live row a getter returning bool.
	TOGGLE,
	## A number between two bounds.
	SLIDER,
	## One of a list. `options` is `[[value, label], ...]`.
	SELECT,
	## One key binding from a [DotMenuBindings] row. Drawn by the screen.
	BINDING,
	## A button that calls [member on_press].
	BUTTON,
	## A sentence and no control.
	NOTE,
	## Whatever [member build] returns, given the kit.
	CUSTOM,
}

## How a slider shows its value.
const FORMAT_NUMBER := &"number"
const FORMAT_INT := &"int"
const FORMAT_PERCENT := &"percent"
const FORMAT_DEGREES := &"degrees"
const FORMAT_TWO_PLACES := &"two_places"
## Zero reads "Off", anything else a percentage. For a scale whose zero is a choice.
const FORMAT_PERCENT_OR_OFF := &"percent_or_off"

var kind: Kind = Kind.TOGGLE

## The setting this row is a view of. Empty on a live row. Also the row's id when [member id]
## is empty: what [method DotMenuPage.find_row] and the config's `rows_hidden` name.
var key: StringName = &""

## A name for a row that has no setting, so a game or a config can find or hide it.
var id: StringName = &""

var title: String = ""
var description: String = ""

## Slider bounds and step. NAN takes them from the setting.
var min_value: float = NAN
var max_value: float = NAN
var step: float = NAN

## `[[value, label], ...]`. Empty on a SELECT over a setting takes the setting's own
## options, labelled by [method label_for_option].
var options: Array = []

## A [StringName] FORMAT_* or a `Callable(value) -> String`.
var format: Variant = FORMAT_NUMBER

## Live rows: `func() -> Variant` and `func(value) -> void`.
var getter: Callable = Callable()
var setter: Callable = Callable()

## `func() -> bool`. False draws the row disabled. Unset is always enabled.
var enabled_if: Callable = Callable()

## `func() -> bool`. False leaves the row out. Unset is always shown.
var visible_if: Callable = Callable()

## `func() -> String`. When set, replaces [member description] each time the page is drawn,
## for a sentence that depends on state ("This server has turned flashlights off").
var describe_with: Callable = Callable()

## BUTTON: the words on it, and what it does.
var button_text: String = ""
var on_press: Callable = Callable()

## CUSTOM: `func(kit: DotMenuKit) -> Control`.
var build: Callable = Callable()

## BINDING: the [DotMenuBindings] row, as that class stores it.
var binding_row: Dictionary = {}

## Where the row is drawn: &"" everywhere, &"web" only in a browser, &"native" only outside.
## A window mode that offers "borderless" in a browser offers something no page can do.
var platform: StringName = &""

## Danger colouring for a button that loses something (Reset, Leave).
var danger: bool = false


# --- Setting rows -------------------------------------------------------------

static func toggle(p_key: StringName, p_title: String, p_description: String = "") -> DotMenuRow:
	return _make(Kind.TOGGLE, p_key, p_title, p_description)


static func slider(p_key: StringName, p_title: String, p_description: String = "") -> DotMenuRow:
	return _make(Kind.SLIDER, p_key, p_title, p_description)


static func select(
	p_key: StringName, p_title: String, p_description: String = "", p_options: Array = []
) -> DotMenuRow:
	var r := _make(Kind.SELECT, p_key, p_title, p_description)
	r.options = p_options
	return r


# --- Rows that are not settings ----------------------------------------------

static func live_toggle(
	p_title: String, p_description: String, p_getter: Callable, p_setter: Callable
) -> DotMenuRow:
	var r := _make(Kind.TOGGLE, &"", p_title, p_description)
	r.getter = p_getter
	r.setter = p_setter
	return r


static func live_select(
	p_title: String, p_description: String, p_options: Array, p_getter: Callable, p_setter: Callable
) -> DotMenuRow:
	var r := _make(Kind.SELECT, &"", p_title, p_description)
	r.options = p_options
	r.getter = p_getter
	r.setter = p_setter
	return r


static func live_slider(
	p_title: String, p_description: String, low: float, high: float, p_step: float,
	p_getter: Callable, p_setter: Callable
) -> DotMenuRow:
	var r := _make(Kind.SLIDER, &"", p_title, p_description)
	r.min_value = low
	r.max_value = high
	r.step = p_step
	r.getter = p_getter
	r.setter = p_setter
	return r


static func button(
	p_title: String, p_description: String, p_text: String, p_on_press: Callable
) -> DotMenuRow:
	var r := _make(Kind.BUTTON, &"", p_title, p_description)
	r.button_text = p_text
	r.on_press = p_on_press
	return r


static func note(text: String) -> DotMenuRow:
	return _make(Kind.NOTE, &"", "", text)


static func custom(p_title: String, p_description: String, p_build: Callable) -> DotMenuRow:
	var r := _make(Kind.CUSTOM, &"", p_title, p_description)
	r.build = p_build
	return r


static func binding(row: Dictionary) -> DotMenuRow:
	var r := _make(Kind.BINDING, StringName(row.get("setting", &"")), str(row.get("label", "")), "")
	r.binding_row = row
	return r


static func _make(k: Kind, p_key: StringName, p_title: String, p_description: String) -> DotMenuRow:
	var r := DotMenuRow.new()
	r.kind = k
	r.key = p_key
	r.title = p_title
	r.description = p_description
	return r


# --- Builders -----------------------------------------------------------------

func named(p_id: StringName) -> DotMenuRow:
	id = p_id
	return self


func described(text: String) -> DotMenuRow:
	description = text
	return self


func with_range(low: float, high: float, p_step: float = NAN) -> DotMenuRow:
	min_value = low
	max_value = high
	step = p_step
	return self


func with_options(p_options: Array) -> DotMenuRow:
	options = p_options
	return self


func formatted(p_format: Variant) -> DotMenuRow:
	format = p_format
	return self


func enabled_when(test: Callable) -> DotMenuRow:
	enabled_if = test
	return self


func shown_when(test: Callable) -> DotMenuRow:
	visible_if = test
	return self


func described_by(source: Callable) -> DotMenuRow:
	describe_with = source
	return self


func only_on_web() -> DotMenuRow:
	platform = &"web"
	return self


func only_native() -> DotMenuRow:
	platform = &"native"
	return self


func dangerous() -> DotMenuRow:
	danger = true
	return self


# --- Reading ------------------------------------------------------------------

## What a page, a config and [method DotMenuPage.find_row] call this row.
func row_id() -> StringName:
	return id if id != &"" else key


func is_live() -> bool:
	return key == &"" or kind == Kind.BUTTON or kind == Kind.NOTE or kind == Kind.CUSTOM


func is_setting() -> bool:
	return key != &"" and (kind == Kind.TOGGLE or kind == Kind.SLIDER or kind == Kind.SELECT)


## Whether this row is drawn at all, here and now. [param settings] may be null, which
## draws only rows that need no setting.
func is_shown(settings: DotSettingsManager) -> bool:
	if platform == &"web" and not DotPlatform.is_web():
		return false
	if platform == &"native" and DotPlatform.is_web():
		return false
	if is_setting() or kind == Kind.BINDING:
		if settings == null or settings.schema == null or not settings.schema.has(key):
			return false
	if visible_if.is_valid() and not bool(visible_if.call()):
		return false
	return true


func is_enabled() -> bool:
	return not enabled_if.is_valid() or bool(enabled_if.call())


func text_under() -> String:
	return str(describe_with.call()) if describe_with.is_valid() else description


## The slider's bounds and step: the row's own, or the setting's. A step of zero (a
## continuous setting) becomes a hundredth of the range, which is what a slider dragged by a
## person can actually choose between.
func slider_range(def: DotSettingsDef) -> Vector3:
	var low := min_value if not is_nan(min_value) else (def.min_value if def != null else 0.0)
	var high := max_value if not is_nan(max_value) else (def.max_value if def != null else 1.0)
	var s := step
	if is_nan(s):
		s = def.step if def != null else 0.0
		if s <= 0.0:
			s = 1.0 if def != null and def.kind == DotSettingsDef.Kind.INT else (high - low) / 100.0
	return Vector3(low, high, s)


## The options: the row's own, or the setting's labelled by [method label_for_option].
func option_list(def: DotSettingsDef) -> Array:
	if not options.is_empty() or def == null:
		return options
	var out: Array = []
	for o in def.options:
		out.append([o, label_for_option(o)])
	return out


## `"bottom_centre"` as "Bottom centre". What an option nobody labelled is called.
static func label_for_option(value: Variant) -> String:
	var s := str(value).replace("_", " ").strip_edges()
	return s.substr(0, 1).to_upper() + s.substr(1) if s != "" else s


## The value as the slider's readout says it.
func show_value(v: float) -> String:
	if format is Callable:
		return str((format as Callable).call(v))
	match StringName(str(format)):
		FORMAT_INT:
			return "%d" % roundi(v)
		FORMAT_PERCENT:
			return "%d%%" % roundi(v * 100.0)
		FORMAT_PERCENT_OR_OFF:
			return "Off" if v <= 0.0 else "%d%%" % roundi(v * 100.0)
		FORMAT_DEGREES:
			return "%d°" % roundi(v)
		FORMAT_TWO_PLACES:
			return "%.2f" % v
	# A whole number shown as one, anything else to the places its step needs.
	if is_equal_approx(v, roundf(v)):
		return "%d" % roundi(v)
	return "%.2f" % v


func describe() -> Dictionary:
	return {
		"kind": Kind.keys()[kind], "id": String(row_id()), "title": title,
		"live": is_live(),
	}
