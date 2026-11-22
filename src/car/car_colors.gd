class_name CarColors
## Car colours to choose from (plain colours, no real team liveries). Bots take the others.

const COLORS: Array[Color] = [
	Color(0.86, 0.13, 0.15), Color(0.12, 0.36, 0.86), Color(0.1, 0.62, 0.32), Color(1.0, 0.5, 0.05),
	Color(0.96, 0.8, 0.1), Color(0.72, 0.74, 0.78), Color(0.52, 0.22, 0.78), Color(0.08, 0.7, 0.76),
	Color(0.14, 0.14, 0.16), Color(0.96, 0.96, 0.96),
]
const NAME_KEYS: Array[String] = [
	"COLOR_RED", "COLOR_BLUE", "COLOR_GREEN", "COLOR_ORANGE", "COLOR_YELLOW",
	"COLOR_SILVER", "COLOR_PURPLE", "COLOR_TEAL", "COLOR_BLACK", "COLOR_WHITE",
]


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
