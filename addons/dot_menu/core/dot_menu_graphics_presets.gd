class_name DotMenuGraphicsPresets
extends RefCounted

## The Video page's Quality presets: Low, Medium, High, Ultra and Custom. A preset writes every key in
## [constant TABLE]; changing one of those keys by hand turns the preset to Custom. [code]high[/code] is every
## key's own default, so a player who never opens the page sees nothing change. [DotMenuApplier] does both.

const KEY := &"graphics_preset"
const CUSTOM := &"custom"
const DEFAULT := &"high"
const NAMES: Array[StringName] = [&"low", &"medium", &"high", &"ultra", &"custom"]

## Reason a preset write carries, so the applier does not take it for a hand edit.
const REASON := &"preset"

## Value per preset, per key. Applied by GameSpice FX's DotFxGraphics and DotFxRenderQuality (render_scale, aniso, aa) and
## the menu's own fx configs (fx_quality).
const TABLE := {
	&"low": {
		&"shadow_quality": 1, &"shadow_distance": 40.0, &"prop_distance": 70.0, &"lod_bias": 0.5,
		&"particle_quality": 1, &"detail_density": 0.35, &"ambient_occlusion": 0, &"glow": false,
		&"reflection_quality": 0, &"texture_quality": 0, &"aniso": 2, &"aa": 1, &"render_scale": 0.75, &"fx_quality": 1,
	},
	&"medium": {
		&"shadow_quality": 2, &"shadow_distance": 80.0, &"prop_distance": 150.0, &"lod_bias": 0.75,
		&"particle_quality": 2, &"detail_density": 0.6, &"ambient_occlusion": 0, &"glow": true,
		&"reflection_quality": 1, &"texture_quality": 1, &"aniso": 4, &"aa": 3, &"render_scale": 1.0, &"fx_quality": 2,
	},
	&"high": {
		&"shadow_quality": 3, &"shadow_distance": 0.0, &"prop_distance": 0.0, &"lod_bias": 1.0,
		&"particle_quality": 3, &"detail_density": 1.0, &"ambient_occlusion": 1, &"glow": true,
		&"reflection_quality": 2, &"texture_quality": 2, &"aniso": -1, &"aa": 0, &"render_scale": 1.0, &"fx_quality": 3,
	},
	&"ultra": {
		&"shadow_quality": 4, &"shadow_distance": 0.0, &"prop_distance": 0.0, &"lod_bias": 2.0,
		&"particle_quality": 3, &"detail_density": 1.0, &"ambient_occlusion": 2, &"glow": true,
		&"reflection_quality": 3, &"texture_quality": 3, &"aniso": 16, &"aa": 5, &"render_scale": 1.0, &"fx_quality": 3,
	},
}


## The keys a preset sets.
static func keys() -> Array:
	return (TABLE[DEFAULT] as Dictionary).keys()


## The preset's values, or an empty dictionary for Custom or an unknown name.
static func values_of(preset: StringName) -> Dictionary:
	return TABLE.get(preset, {})


## Whether a stored value equals a preset's: numbers compare as numbers (a document read from JSON has floats).
static func same(a: Variant, b: Variant) -> bool:
	var na := a is int or a is float
	var nb := b is int or b is float
	if na and nb:
		return is_equal_approx(float(a), float(b))
	if a is bool or b is bool:
		return a is bool and b is bool and a == b
	return str(a) == str(b)
