class_name CarColors
## Car colour schemes: body + accent, in the colours of the 2026 grid (user 2026-11-22). Only the
## colours - no team names, logos, sponsors or livery graphics (generic names in the menu).
## The player picks one, the bots take the others.

const COLORS: Array[Color] = [
	Color(0.86, 0.06, 0.08), Color(1.0, 0.5, 0.0), Color(0.09, 0.13, 0.3), Color(0.76, 0.78, 0.8),
	Color(0.0, 0.36, 0.25), Color(0.05, 0.38, 0.85), Color(0.0, 0.2, 0.55), Color(0.95, 0.95, 0.97),
	Color(0.92, 0.92, 0.92), Color(0.5, 0.51, 0.53), Color(0.1, 0.1, 0.11),
]
## Accent colour of each scheme (nose tip, stripe, wing details).
const ACCENTS: Array[Color] = [
	Color(0.97, 0.97, 0.97), Color(0.12, 0.12, 0.14), Color(0.88, 0.1, 0.15), Color(0.0, 0.68, 0.6),
	Color(0.8, 0.95, 0.15), Color(1.0, 0.45, 0.75), Color(0.45, 0.78, 1.0), Color(0.15, 0.3, 0.85),
	Color(0.85, 0.08, 0.12), Color(0.9, 0.08, 0.14), Color(0.95, 0.95, 0.96),
]
const NAME_KEYS: Array[String] = [
	"COLOR_RED", "COLOR_PAPAYA", "COLOR_NAVY", "COLOR_SILVER", "COLOR_GREEN", "COLOR_BLUE_PINK",
	"COLOR_BLUE", "COLOR_WHITE_BLUE", "COLOR_WHITE_RED", "COLOR_TITANIUM", "COLOR_BLACK",
]


## Accent of a scheme by its body colour (a colour outside the list gets white or dark).
static func accent_for(body: Color) -> Color:
	for i in COLORS.size():
		if COLORS[i].is_equal_approx(body):
			return ACCENTS[i]
	return Color(0.12, 0.12, 0.14) if body.get_luminance() > 0.6 else Color(0.96, 0.96, 0.97)


## Helmet colours (contrasting, picked per car colour).
const HELMETS: Array[Color] = [Color(0.98, 0.85, 0.2), Color(0.96, 0.96, 0.97), Color(0.3, 0.75, 1.0), Color(1.0, 0.55, 0.15)]


static func helmet_for(body: Color) -> Color:
	var start := absi(hash(body.to_html())) % HELMETS.size()
	var best := HELMETS[start]
	for step in HELMETS.size():
		var helmet := HELMETS[(start + step) % HELMETS.size()]
		var contrast := absf(helmet.get_luminance() - body.get_luminance())
		if contrast >= 0.15:
			return helmet
		if contrast > absf(best.get_luminance() - body.get_luminance()):
			best = helmet
	return best


static func color(index: int) -> Color:
	return COLORS[clampi(index, 0, COLORS.size() - 1)]
