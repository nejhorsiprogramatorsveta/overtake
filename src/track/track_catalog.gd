class_name TrackCatalog
## All tracks in the game (id -> data file). Names are TRACK_*_NAME keys inside the files.

const DEFAULT_ID := "austria"
const FILES := {
	"austria": "res://data/tracks/austria.json",
	"brazil": "res://data/tracks/brazil.json",
	"china": "res://data/tracks/china.json",
}
## Name keys for menus without loading the whole file (must match the files).
const NAME_KEYS := {
	"austria": "TRACK_AUSTRIA_NAME",
	"brazil": "TRACK_BRAZIL_NAME",
	"china": "TRACK_CHINA_NAME",
}

static var _cache: Dictionary = {}


static func ids() -> PackedStringArray:
	return PackedStringArray(FILES.keys())


static func has(id: String) -> bool:
	return FILES.has(id)


static func id_or_default(id: String) -> String:
	return id if FILES.has(id) else DEFAULT_ID


## Loaded once and shared (the data never changes during the game).
static func get_track(id: String) -> TrackData:
	id = id_or_default(id)
	if not _cache.has(id):
		_cache[id] = TrackData.load_file(FILES[id])
	return _cache[id]
