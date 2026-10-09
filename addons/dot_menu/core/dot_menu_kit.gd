class_name DotMenuKit
extends RefCounted

## How a menu looks: one palette, one [Theme], and the handful of pieces every screen here is
## assembled from.
##
## [b]Everything is a StyleBoxFlat and a colour.[/b] No texture and, by default, no font
## file: a game delivered as a pack stays small, and the menus look the same in a browser
## as on a desktop. That is dot-ui's own rule — ship no art — and this keeps it: what this
## adds over [DotUiTheme] is a designed default and the pieces to build screens from it, not
## a picture anybody has to replace.
##
## [b]An instance, rebuilt on a theme change, rather than static colours.[/b] The game this
## was extracted from kept its palette in static vars so a switch changed every call site at
## once; in an addon that is one palette per PROCESS, and a server and a client in one
## editor session, or two split-screen menus, would share it. A screen holds the kit it was
## built with and is rebuilt with the next — see [method DotMenuScreen.restyle] for why
## rebuilt rather than recoloured.
##
## A game that wants other sizes or a font of its own sets them here before building:
## [codeblock]
## var kit := DotMenuKit.new(themes.named(&"ember"))
## kit.font = preload("res://ui/my_font.ttf")
## kit.size_body = 16
## [/codeblock]

var palette: DotMenuPalette = null

## The face everything is set in. Null is the engine's own.
var font: Font = null

## How heavy [method bold] is when it synthesises from [member font]. A font file would be
## the first binary in a pack that is not a map, for a weight the engine can make.
var embolden: float = 0.7

## A real bold face, when the game has one. Overrides the synthesised one.
var bold_font: Font = null

var radius: int = 14
var radius_small: int = 9

var size_title: int = 26
var size_heading: int = 19
var size_body: int = 15
var size_small: int = 13

var _bold: Font = null


func _init(p_palette: DotMenuPalette = null) -> void:
	palette = p_palette if p_palette != null else DotMenuPalette.new()


## A kit like this one in another palette: same sizes and fonts.
func with_palette(p: DotMenuPalette) -> DotMenuKit:
	var k := DotMenuKit.new(p)
	k.font = font
	k.embolden = embolden
	k.bold_font = bold_font
	k.radius = radius
	k.radius_small = radius_small
	k.size_title = size_title
	k.size_heading = size_heading
	k.size_body = size_body
	k.size_small = size_small
	return k


func base_font() -> Font:
	return font if font != null else ThemeDB.fallback_font


func bold() -> Font:
	if bold_font != null:
		return bold_font
	if _bold == null:
		var v := FontVariation.new()
		v.base_font = base_font()
		v.variation_embolden = embolden
		_bold = v
	return _bold


# --- Boxes ------------------------------------------------------------------

func box(
	fill: Color, p_radius: int = -1, border: Color = Color(0, 0, 0, 0), border_width: int = 0,
	pad: Vector4 = Vector4(0, 0, 0, 0)
) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fill
	s.set_corner_radius_all(radius if p_radius < 0 else p_radius)
	s.corner_detail = 6
	s.anti_aliasing = true
	if border_width > 0:
		s.border_color = border
		s.set_border_width_all(border_width)
	s.content_margin_left = pad.x
	s.content_margin_top = pad.y
	s.content_margin_right = pad.z
	s.content_margin_bottom = pad.w
	return s


## The big card a menu sits on: rounded, bordered faintly, and lifted off the game by a soft
## shadow rather than by a heavy outline.
func surface_box() -> StyleBoxFlat:
	var s := box(palette.surface, radius + 4, palette.line, 1)
	s.shadow_color = Color(0, 0, 0, 0.45)
	s.shadow_size = 28
	s.shadow_offset = Vector2(0, 10)
	return s


# --- The theme --------------------------------------------------------------

## A fresh [Theme] every call, for dot-ui's reason: a Theme is mutable and shared.
func theme() -> Theme:
	var p := palette
	var t := Theme.new()
	t.default_font = base_font()
	t.default_font_size = size_body

	t.set_color(&"font_color", &"Label", p.text)

	# Buttons: quiet by default, a wash of the accent on hover, the accent itself pressed.
	var pad := Vector4(16, 9, 16, 9)
	var wash := p.accent_wash()
	t.set_stylebox(&"normal", &"Button", box(p.card, radius_small, p.line, 1, pad))
	t.set_stylebox(&"hover", &"Button", box(p.card_hover, radius_small, Color(p.text, 0.12), 1, pad))
	t.set_stylebox(&"pressed", &"Button", box(wash, radius_small, p.accent, 1, pad))
	t.set_stylebox(&"hover_pressed", &"Button", box(wash, radius_small, p.accent, 1, pad))
	t.set_stylebox(&"disabled", &"Button", box(Color(p.text, 0.015), radius_small, p.line, 1, pad))
	t.set_stylebox(&"focus", &"Button", box(Color(0, 0, 0, 0), radius_small, Color(p.accent, 0.7), 2))
	t.set_color(&"font_color", &"Button", p.text)
	t.set_color(&"font_hover_color", &"Button", p.text)
	t.set_color(&"font_pressed_color", &"Button", p.accent)
	t.set_color(&"font_hover_pressed_color", &"Button", p.accent)
	t.set_color(&"font_focus_color", &"Button", p.text)
	t.set_color(&"font_disabled_color", &"Button", p.dim)

	# A select box looks like a button with a caret: a well on a dark surface and a raised
	# field on a light one, because a dark wash over a light card reads as disabled.
	for state in [&"normal", &"hover", &"pressed", &"disabled", &"focus"]:
		t.set_stylebox(state, &"OptionButton", t.get_stylebox(state, &"Button"))
	var light := p.is_light()
	var field := Color(1, 1, 1, 0.85) if light else Color(0, 0, 0, 0.25)
	var field_hover := Color(1, 1, 1, 1.0) if light else Color(0, 0, 0, 0.32)
	var field_pad := Vector4(14, 8, 14, 8)
	t.set_stylebox(&"normal", &"OptionButton", box(field, radius_small, p.line, 1, field_pad))
	t.set_stylebox(&"hover", &"OptionButton", box(field_hover, radius_small, Color(p.text, 0.16), 1, field_pad))
	t.set_color(&"font_color", &"OptionButton", p.text)
	t.set_color(&"font_hover_color", &"OptionButton", p.text)
	t.set_color(&"font_pressed_color", &"OptionButton", p.accent)
	t.set_color(&"font_disabled_color", &"OptionButton", p.dim)
	t.set_constant(&"arrow_margin", &"OptionButton", 10)

	# A text field, for a game's own rows (a name, a server address).
	t.set_stylebox(&"normal", &"LineEdit", box(field, radius_small, p.line, 1, field_pad))
	t.set_stylebox(&"focus", &"LineEdit", box(Color(0, 0, 0, 0), radius_small, Color(p.accent, 0.7), 2))
	t.set_stylebox(&"read_only", &"LineEdit", box(Color(p.text, 0.015), radius_small, p.line, 1, field_pad))
	t.set_color(&"font_color", &"LineEdit", p.text)
	t.set_color(&"font_placeholder_color", &"LineEdit", p.dim)
	t.set_color(&"caret_color", &"LineEdit", p.accent)
	t.set_color(&"selection_color", &"LineEdit", Color(p.accent, 0.3))

	# The list a select box opens.
	t.set_stylebox(&"panel", &"PopupMenu", box(Color(p.surface, 0.99), radius_small, Color(p.text, 0.1), 1, Vector4(6, 6, 6, 6)))
	t.set_stylebox(&"hover", &"PopupMenu", box(wash, 6))
	t.set_color(&"font_color", &"PopupMenu", p.text)
	t.set_color(&"font_hover_color", &"PopupMenu", p.accent)
	t.set_constant(&"v_separation", &"PopupMenu", 10)
	t.set_constant(&"item_start_padding", &"PopupMenu", 10)
	t.set_constant(&"item_end_padding", &"PopupMenu", 14)

	# Sliders: a thin rail, the filled part in the accent, a round grabber.
	var rail := box(Color(p.text, 0.09), 3)
	rail.content_margin_top = 3
	rail.content_margin_bottom = 3
	var filled := box(p.accent_deep, 3)
	filled.content_margin_top = 3
	filled.content_margin_bottom = 3
	t.set_stylebox(&"slider", &"HSlider", rail)
	t.set_stylebox(&"grabber_area", &"HSlider", filled)
	t.set_stylebox(&"grabber_area_highlight", &"HSlider", box(p.accent, 3))
	t.set_icon(&"grabber", &"HSlider", dot(16, p.text))
	t.set_icon(&"grabber_highlight", &"HSlider", dot(18, p.accent))
	t.set_icon(&"grabber_disabled", &"HSlider", dot(16, p.dim))

	# Scroll bars that stay out of the way.
	t.set_stylebox(&"scroll", &"VScrollBar", box(Color(0, 0, 0, 0), 4, Color(0, 0, 0, 0), 0, Vector4(3, 0, 3, 0)))
	t.set_stylebox(&"grabber", &"VScrollBar", box(Color(p.text, 0.12), 4))
	t.set_stylebox(&"grabber_highlight", &"VScrollBar", box(Color(p.text, 0.22), 4))
	t.set_stylebox(&"grabber_pressed", &"VScrollBar", box(p.accent_deep, 4))

	t.set_stylebox(&"panel", &"PanelContainer", box(Color(0, 0, 0, 0), 0))
	t.set_stylebox(&"separator", &"HSeparator", box(p.line, 0))
	t.set_constant(&"separation", &"HSeparator", 1)

	t.set_color(&"font_color", &"TooltipLabel", p.text)
	t.set_stylebox(&"panel", &"TooltipPanel", box(Color(p.surface, 0.98), 8, Color(p.text, 0.1), 1, Vector4(10, 6, 10, 6)))
	return t


## A filled, anti-aliased circle, for a slider's grabber.
static func dot(diameter: int, colour: Color) -> ImageTexture:
	var img := Image.create(diameter, diameter, false, Image.FORMAT_RGBA8)
	var r := diameter * 0.5
	for y in range(diameter):
		for x in range(diameter):
			var d := Vector2(x + 0.5 - r, y + 0.5 - r).length()
			var a := clampf(r - d, 0.0, 1.0)
			img.set_pixel(x, y, Color(colour.r, colour.g, colour.b, colour.a * a))
	return ImageTexture.create_from_image(img)


# --- Pieces -----------------------------------------------------------------

## A label. [param size] 0 is the body size; [param colour] transparent black is the text
## colour — sentinels rather than defaults, because a default argument cannot read the kit.
func label(text: String, size: int = 0, colour: Color = Color(0, 0, 0, 0), heavy: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override(&"font_size", size if size > 0 else size_body)
	l.add_theme_color_override(&"font_color", colour if colour.a > 0.0 else palette.text)
	if heavy:
		l.add_theme_font_override(&"font", bold())
	return l


## A paragraph that wraps inside whatever width it is given. Small and muted unless told.
func paragraph(text: String, size: int = 0, colour: Color = Color(0, 0, 0, 0)) -> Label:
	var l := label(text, size if size > 0 else size_small, colour if colour.a > 0.0 else palette.muted)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Without a minimum width a wrapping label in a container asks for nothing and is
	# squeezed to one character a line.
	l.custom_minimum_size = Vector2(1, 0)
	return l


## A key drawn as a key. [param text] is a binding's own spelling ("Ctrl", "F5", "Mouse 4").
func keycap(text: String, size: int = 0) -> PanelContainer:
	var cap := PanelContainer.new()
	var s := box(palette.keycap, 6, palette.keycap_edge, 1, Vector4(9, 3, 9, 4))
	s.border_width_bottom = 3
	cap.add_theme_stylebox_override(&"panel", s)
	var l := label(text, size if size > 0 else size_small, palette.text, true)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cap.add_child(l)
	return cap


## A rounded group of rows, with a little air between them.
func card() -> PanelContainer:
	var c := PanelContainer.new()
	c.add_theme_stylebox_override(&"panel", box(palette.card, radius, palette.line, 1, Vector4(18, 8, 18, 8)))
	return c


## The section title over a card: small capitals in the accent.
func section(text: String) -> Label:
	return label(text.to_upper(), size_small - 1, palette.accent, true)


## The filled button: Resume, Save, Join.
func primary_button(text: String) -> Button:
	var p := palette
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 42)
	var pad := Vector4(16, 10, 16, 10)
	var none := Color(0, 0, 0, 0)
	b.add_theme_stylebox_override(&"normal", box(p.accent_deep, radius_small, none, 0, pad))
	b.add_theme_stylebox_override(&"hover", box(p.accent_deep.lightened(0.12), radius_small, none, 0, pad))
	b.add_theme_stylebox_override(&"pressed", box(p.accent, radius_small, none, 0, pad))
	b.add_theme_stylebox_override(&"focus", box(none, radius_small, Color(p.accent, 0.8), 2))
	var ink := DotMenuPalette.ink_on(p.accent_deep)
	b.add_theme_color_override(&"font_color", ink)
	b.add_theme_color_override(&"font_hover_color", ink)
	b.add_theme_color_override(&"font_pressed_color", DotMenuPalette.ink_on(p.accent))
	b.add_theme_color_override(&"font_focus_color", ink)
	b.add_theme_font_override(&"font", bold())
	return b


## A sidebar entry. With a [param group] it is a page tab that stays lit; without, an
## action (Help, Leave).
func nav_button(text: String, group: ButtonGroup = null) -> Button:
	var p := palette
	var b := Button.new()
	b.text = text
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size = Vector2(0, 38)
	b.focus_mode = Control.FOCUS_ALL
	if group != null:
		b.toggle_mode = true
		b.button_group = group

	var pad := Vector4(14, 8, 12, 8)
	var none := Color(0, 0, 0, 0)
	var selected := box(p.accent_wash(), radius_small, none, 0, pad)
	selected.border_color = p.accent
	selected.border_width_left = 3
	b.add_theme_stylebox_override(&"normal", box(none, radius_small, none, 0, pad))
	b.add_theme_stylebox_override(&"hover", box(p.card_hover, radius_small, none, 0, pad))
	b.add_theme_stylebox_override(&"pressed", selected)
	b.add_theme_stylebox_override(&"hover_pressed", selected)
	b.add_theme_color_override(&"font_color", p.muted)
	b.add_theme_color_override(&"font_hover_color", p.text)
	b.add_theme_color_override(&"font_focus_color", p.text)
	return b


## An empty block [param height] tall.
static func gap(height: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, height)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


## The game behind an open menu, softened and dimmed. [param strength] scales the dim.
##
## A blur where the renderer has screen mipmaps and a plain dim where it does not — which
## is what the shader falls back to on its own, so there is one code path.
func backdrop(strength: float = 1.0) -> ColorRect:
	var tint := Color(palette.backdrop, clampf(palette.backdrop.a * strength, 0.0, 1.0))
	var back := ColorRect.new()
	back.name = "Backdrop"
	back.color = tint
	fill_parent(back)
	back.mouse_filter = Control.MOUSE_FILTER_STOP

	var mat := ShaderMaterial.new()
	mat.shader = _backdrop_shader()
	mat.set_shader_parameter(&"tint", tint)
	back.material = mat
	return back


static var _shader: Shader = null


static func _backdrop_shader() -> Shader:
	if _shader == null:
		_shader = Shader.new()
		_shader.code = """
shader_type canvas_item;
uniform sampler2D screen : hint_screen_texture, filter_linear_mipmap;
uniform vec4 tint : source_color = vec4(0.02, 0.03, 0.05, 0.62);
void fragment() {
	vec3 c = textureLod(screen, SCREEN_UV, 3.0).rgb;
	COLOR = vec4(mix(c, tint.rgb, tint.a), 1.0);
}
"""
	return _shader


## A [Control] sized by its parent's rectangle, every offset set explicitly — the trap
## dot-ui's notes have paid for seven times: an anchor set on a Control with no rectangle
## yet keeps a zero size.
static func fill_parent(c: Control) -> void:
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


## Takes every child off [param node] now, and frees them later.
##
## [b]Removed, then freed.[/b] `queue_free` alone leaves the old children in the tree until
## the end of the frame, so a page rebuilt in the same frame is drawn — and measured — with
## both sets in it.
static func clear(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()
