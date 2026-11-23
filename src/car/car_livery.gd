class_name CarLivery
extends RefCounted
## How one car is painted and shaped (user 2026-11-23: as close as possible to the 2025/2026
## grid): colour zones (body, nose, sidepods, engine cover, stripes, wing flaps, halo, a car split
## in two colours) and a few shape numbers (sidepod width and length, nose width), so the cars
## differ like the real ones. Colours and layouts only - no names, logos or sponsors.

var body := Color.RED
var nose := Color.RED
var pods := Color.RED
var engine := Color.RED
## Centre line of the engine cover and the stripe along the sidepods (alpha 0 = none).
var spine := Color(1, 1, 1, 0)
var stripe := Color(1, 1, 1, 0)
var nose_tip := Color.WHITE
var front_flap := Color.RED
var rear_flap := Color.RED
var halo := Color(0.2, 0.2, 0.22)
## The left half of the car in this colour (alpha 0 = one colour).
var split_left := Color(0, 0, 0, 0)
var pod_width := 0.6
var pod_end := -0.9
var nose_width := 0.14

const BLACK := Color(0.12, 0.12, 0.14)
const WHITE := Color(0.95, 0.95, 0.96)


## The livery of a colour scheme of CarColors (a colour outside the list: plain body + accent).
static func for_color(color: Color) -> CarLivery:
	for i in CarColors.COLORS.size():
		if CarColors.COLORS[i].is_equal_approx(color):
			return scheme(i)
	return plain(color, CarColors.accent_for(color))


static func plain(color: Color, accent: Color) -> CarLivery:
	var livery := CarLivery.new()
	livery._paint(color, color, color, color, accent, accent, accent, color.darkened(0.15), color)
	return livery


## The eleven schemes, in CarColors order (inspired by the 2025/2026 cars of the grid).
static func scheme(index: int) -> CarLivery:
	var l := CarLivery.new()
	var red := Color(0.86, 0.06, 0.08)
	var papaya := Color(1.0, 0.5, 0.0)
	var navy := Color(0.09, 0.13, 0.3)
	var silver := Color(0.76, 0.78, 0.8)
	var teal := Color(0.0, 0.68, 0.6)
	var green := Color(0.0, 0.36, 0.25)
	var lime := Color(0.8, 0.95, 0.15)
	var blue := Color(0.05, 0.38, 0.85)
	var pink := Color(1.0, 0.45, 0.75)
	var royal := Color(0.0, 0.2, 0.55)
	var sky := Color(0.45, 0.78, 1.0)
	var vivid := Color(0.15, 0.3, 0.85)
	var titanium := Color(0.5, 0.51, 0.53)
	var hot := Color(0.9, 0.08, 0.14)
	match index:
		0:  # red, white bands, black wings
			l._paint(red, red, red, red, WHITE, WHITE, red, BLACK, red)
			l._shape(0.6, -0.9, 0.14)
		1:  # papaya with black sidepods
			l._paint(papaya, papaya, BLACK, papaya, BLACK, Color(0, 0, 0, 0), BLACK, papaya, papaya)
			l._shape(0.58, -1.02, 0.13)
		2:  # navy, red stripes, yellow nose tip
			l._paint(navy, navy, navy, navy, hot, hot, Color(0.98, 0.8, 0.1), navy, hot)
			l._shape(0.63, -0.85, 0.16)
		3:  # silver front, black rear, teal lines
			l._paint(BLACK, silver, BLACK, BLACK, teal, teal, silver, silver, BLACK)
			l._shape(0.57, -0.96, 0.12)
		4:  # racing green, lime stripes
			l._paint(green, green, green, green, lime, lime, lime, green, green)
			l._shape(0.63, -0.9, 0.15)
		5:  # blue front, pink sidepods and wings
			l._paint(blue, blue, pink, blue, pink, Color(0, 0, 0, 0), pink, pink, pink)
			l._shape(0.59, -0.95, 0.13)
		6:  # dark blue, light blue stripes, white rear wing
			l._paint(royal, royal, royal, royal, WHITE, sky, WHITE, royal, WHITE)
			l._shape(0.6, -0.88, 0.14)
		7:  # white with a blue engine cover
			l._paint(WHITE, WHITE, WHITE, vivid, hot, vivid, vivid, vivid, vivid)
			l._shape(0.61, -0.92, 0.15)
		8:  # white front, black rear, red lines
			l._paint(WHITE, WHITE, WHITE, BLACK, hot, hot, BLACK, BLACK, hot)
			l._shape(0.6, -0.9, 0.14)
		9:  # titanium, black rear, red accents
			l._paint(titanium, titanium, titanium, BLACK, hot, hot, hot, BLACK, hot)
			l._shape(0.58, -0.98, 0.13)
		10:  # black and white, split down the middle
			l._paint(BLACK, BLACK, BLACK, BLACK, Color(0, 0, 0, 0), Color(0, 0, 0, 0), WHITE, BLACK, BLACK)
			l.split_left = WHITE
			l._shape(0.6, -0.93, 0.14)
		_:
			return plain(CarColors.color(index), CarColors.ACCENTS[index % CarColors.ACCENTS.size()])
	return l


func _paint(p_body: Color, p_nose: Color, p_pods: Color, p_engine: Color, p_spine: Color, p_stripe: Color,
		p_tip: Color, p_front: Color, p_rear: Color) -> void:
	body = p_body
	nose = p_nose
	pods = p_pods
	engine = p_engine
	spine = p_spine
	stripe = p_stripe
	nose_tip = p_tip
	front_flap = p_front
	rear_flap = p_rear


func _shape(p_pod_width: float, p_pod_end: float, p_nose_width: float) -> void:
	pod_width = p_pod_width
	pod_end = p_pod_end
	nose_width = p_nose_width
