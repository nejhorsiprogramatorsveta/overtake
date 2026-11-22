class_name HudStyle
## Shared look of the race HUD (M3G): dark slanted panels with a red edge, and a bold variant of
## Godot's default font with equal-width digits, so running times do not jitter. Lap-time colours
## as on TV: purple = fastest of the session, green = own best, yellow = slower.

const BACK := Color(0.05, 0.06, 0.08, 0.8)
const EDGE := Color(0.88, 0.12, 0.15)
const TEXT := Color(0.96, 0.96, 0.98)
const DIM := Color(0.68, 0.7, 0.76)
const GOLD := Color(1.0, 0.84, 0.2)
const PURPLE := Color(0.74, 0.4, 1.0)
const GREEN := Color(0.32, 0.92, 0.46)
const YELLOW := Color(1.0, 0.86, 0.28)
const GAIN := Color(0.32, 0.92, 0.46)
const LOSS := Color(1.0, 0.36, 0.32)

static var _bold: FontVariation


## Bold default font with tabular (equal-width) digits.
static func bold() -> Font:
	if _bold == null:
		_bold = FontVariation.new()
		_bold.base_font = ThemeDB.fallback_font
		_bold.variation_embolden = 0.55
		var server := TextServerManager.get_primary_interface()
		_bold.opentype_features = {server.name_to_tag("tnum"): 1}
	return _bold


## Panel background: dark, slightly slanted, coloured edge on the left.
static func panel(edge: Color = EDGE) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = BACK
	style.border_width_left = 5
	style.border_color = edge
	style.skew = Vector2(0.08, 0.0)
	style.set_corner_radius_all(3)
	style.content_margin_left = 18
	style.content_margin_right = 16
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	return style


## A HUD label: bold, sized and coloured, not auto-translated (texts come from tr() already).
static func label(size: int, color: Color = TEXT) -> Label:
	var result := Label.new()
	result.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	result.add_theme_font_override("font", bold())
	result.add_theme_font_size_override("font_size", size)
	result.add_theme_color_override("font_color", color)
	return result


## Font colour of a label, set only when it changes (an override change relayouts the label).
static func set_color(label: Label, color: Color) -> void:
	if not label.has_theme_color_override("font_color") or label.get_theme_color("font_color") != color:
		label.add_theme_color_override("font_color", color)


## Short "pop" of a control: scaled up, then back (lap time, position change).
static func pop(control: Control) -> void:
	control.pivot_offset = control.size * 0.5
	control.scale = Vector2.ONE * 1.25
	var tween := control.create_tween()
	tween.tween_property(control, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
