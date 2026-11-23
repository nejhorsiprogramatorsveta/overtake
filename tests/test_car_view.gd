extends TestCase
## Car look (M3G): helmets contrast with the body, the wing flaps open only on the straight
## (fast, throttle, no braking, little steering), the front wheels follow the steering.

var tuning: CarTuning = load("res://data/car/car_tuning.tres")
var track := TrackCatalog.get_track("austria")


func test_helmet_contrasts_with_every_car_colour() -> void:
	for body in CarColors.COLORS:
		var helmet := CarColors.helmet_for(body)
		check(absf(helmet.get_luminance() - body.get_luminance()) >= 0.15, "helmet stands out on %s" % body.to_html())
		check(CarColors.HELMETS.has(helmet), "helmet from the palette")


func _car(speed: float, throttle: bool, brake: bool, steer: float) -> Car:
	var car := Car.new()
	car.setup(track, tuning, Color.RED)
	car.place(100.0, 0.0)
	car.state.velocity = Vector2.from_angle(car.state.heading) * speed
	car.state.steer = steer
	car.last_input.throttle = throttle
	car.last_input.brake = brake
	car._sync_node()
	return car


func test_flaps_open_only_on_the_straight() -> void:
	var cases := [
		[60.0, true, false, 0.0, true, "fast on the throttle: open"],
		[60.0, false, true, 0.0, false, "braking: closed"],
		[60.0, true, false, 0.4, false, "steering into a corner: closed"],
		[20.0, true, false, 0.0, false, "slow: closed"],
	]
	for c: Array in cases:
		var car := _car(c[0], c[1], c[2], c[3])
		check_eq(car.view.aero_open, c[4], c[5])
		car.free()


func test_front_wheels_follow_the_steering() -> void:
	var car := _car(30.0, true, false, -0.5)
	check(is_equal_approx(car.view.steer_angle, -0.5 * tuning.max_steer_angle), "wheels turned left")
	car.free()


func test_colour_schemes_are_complete() -> void:
	check_eq(CarColors.ACCENTS.size(), CarColors.COLORS.size(), "an accent for every body colour")
	check_eq(CarColors.NAME_KEYS.size(), CarColors.COLORS.size(), "a name for every scheme")
	check(CarColors.COLORS.size() >= 11, "enough schemes for a full grid (%d)" % CarColors.COLORS.size())
	for i in CarColors.COLORS.size():
		check(CarColors.accent_for(CarColors.COLORS[i]).is_equal_approx(CarColors.ACCENTS[i]), "accent of scheme %d" % i)


func test_every_scheme_has_its_own_livery() -> void:
	var seen := {}
	for i in CarColors.COLORS.size():
		var livery := CarLivery.for_color(CarColors.COLORS[i])
		var key := "%s|%s|%s|%s|%.2f" % [livery.body.to_html(), livery.pods.to_html(), livery.engine.to_html(), livery.nose.to_html(), livery.pod_width]
		check(not seen.has(key), "scheme %d differs from the others" % i)
		seen[key] = true
	check(CarLivery.for_color(Color(0.3, 0.3, 0.3)).body.is_equal_approx(Color(0.3, 0.3, 0.3)), "unknown colour: plain livery")
