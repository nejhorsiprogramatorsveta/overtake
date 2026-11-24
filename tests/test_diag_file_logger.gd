extends TestCase
## The single diagnostic log file (DiagFileLogger): memory before a game, one file per game.

const TEST_PATH := "user://test_diag/last_game.log"


func _content() -> String:
	return FileAccess.get_file_as_string(TEST_PATH)


func test_lines_before_a_game_are_kept_and_each_game_replaces_the_file() -> void:
	DirAccess.remove_absolute(TEST_PATH)
	var logger := DiagFileLogger.new()
	logger.path = TEST_PATH
	logger._log_message("startup line\n", false)
	logger._log_error("func", "file.gd", 7, "code", "something broke", false, 0, [] as Array[ScriptBacktrace])
	check(not FileAccess.file_exists(TEST_PATH), "nothing written to disk before a game")
	logger.begin_game("=== header 1 ===")
	logger._log_message(DiagLog.line("conn", "peer 5 connected"), false)
	var first := _content()
	check(first.begins_with("=== header 1 ==="), "header first")
	check(first.contains("startup line") and first.contains("ERROR: something broke (file.gd:7 func)"), "remembered lines and errors")
	check(first.contains("] [conn] peer 5 connected"), "live line written and flushed")
	logger.begin_game("=== header 2 ===")
	logger._log_message("second game", false)
	logger.flush()
	var second := _content()
	check(second.begins_with("=== header 2 ===") and not second.contains("peer 5"), "a new game replaces the old log")
	logger.close()
	DirAccess.remove_absolute(TEST_PATH)
	DirAccess.remove_absolute(TEST_PATH.get_base_dir())


func test_stamps() -> void:
	var stamped := DiagFileLogger.stamp("x")
	check(DiagFileLogger.is_stamped(stamped), "own stamp is recognised")
	check(not DiagFileLogger.is_stamped("[net] something"), "other brackets are not a stamp")


## Overtake (user 2026-11-24): addresses never reach the log.
func test_addresses_are_masked() -> void:
	var text := DiagLog.mask("joining 192.168.1.20 and 100.101.5.7 then fe80::1:2:3")
	check(not text.contains("192.168") and not text.contains("100.101") and not text.contains("fe80"), "no address left: %s" % text)


## A race line every interval: FPS, physics pauses and per-peer network gaps.
func test_race_log_reports_hitches_and_gaps() -> void:
	var log := RaceLog.new()
	check_eq(log.tick(1000, 60.0, true), "", "nothing before the interval ends")
	log.tick(1016, 60.0, true)
	log.tick(1200, 20.0, true)  # a 184 ms pause between physics ticks
	log.record_arrival(2, 1300)
	log.record_arrival(2, 1316)
	log.record_arrival(2, 1500)  # 184 ms without a state from peer 2
	log.record_reject(2)
	var now := 1200
	while now + 16 < 1000 + RaceLog.INTERVAL_MS:
		now += 16
		log.tick(now, 60.0, true)
	var line := log.tick(1000 + RaceLog.INTERVAL_MS, 58.0, true, func() -> String: return "peer 2 rtt=40ms",
			func() -> String: return "delay peer2=80ms")
	check(line.contains("min=20") and line.contains("tick_gap_max=184ms") and line.contains("hitches>50ms=1"), line)
	check(line.contains("peer 2 received=3 gap_max=184ms gaps>100ms=1 rejected=1"), line)
	check(line.contains("link peer 2 rtt=40ms") and line.contains("delay peer2=80ms"), line)
	check_eq(log.tick(1016 + RaceLog.INTERVAL_MS, 60.0, true), "", "a new window starts")
