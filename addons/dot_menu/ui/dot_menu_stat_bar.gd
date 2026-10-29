class_name DotMenuStatBar
extends RefCounted
## The stat bar of the loadout screen's detail card.


## One stat: a label, a bar, and a tick where the equipped item stands.
static func build(kit: DotMenuKit, label: String, value: float, text: String, held: float, same: bool) -> Control:
	var p := kit.palette
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 10)
	var name := kit.label(label, kit.size_small, p.muted)
	name.custom_minimum_size = Vector2(92, 0)
	row.add_child(name)
	var track := PanelContainer.new()
	track.custom_minimum_size = Vector2(0, 10)
	track.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	track.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	track.add_theme_stylebox_override(&"panel", kit.box(Color(p.text, 0.08), 5))
	row.add_child(track)
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	track.add_child(holder)
	var better := held < 0.0 or same or value >= held - 0.001
	var fill := Panel.new()
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fill.add_theme_stylebox_override(&"panel", kit.box(p.accent if better else p.warn, 5))
	fill.anchor_bottom = 1.0
	fill.anchor_right = maxf(value, 0.02)
	holder.add_child(fill)
	if held >= 0.0 and not same:
		# What is equipped now: a tick on the track, so a shorter bar reads as a step down.
		var tick := ColorRect.new()
		tick.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tick.color = p.text
		tick.anchor_left = clampf(held, 0.0, 1.0)
		tick.anchor_right = clampf(held, 0.0, 1.0)
		tick.anchor_bottom = 1.0
		tick.offset_left = -1.0
		tick.offset_right = 1.0
		tick.offset_top = -3.0
		tick.offset_bottom = 3.0
		holder.add_child(tick)
	var v := kit.label(text, kit.size_small, p.text, true)
	v.custom_minimum_size = Vector2(64, 0)
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(v)
	return row
