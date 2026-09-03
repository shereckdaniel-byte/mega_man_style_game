## The rule every stage's backdrop has to obey: **a landmark lives on exactly one
## plate.**
##
## Parallax plates move at different rates by definition -- that is what makes
## them parallax. So anything the player can identify as a single object must
## exist on one of them and no other, or the copies slide apart and the sky ends
## up with two suns in it.
##
## Both stages shipped a version of this and neither was caught by a test,
## because both look right in the one screenshot anybody takes:
##
##   * Dawn Boardwalk drew the sun's reflection into the water plate, which
##     scrolls at 0.4 against the sky's 0.05. Two rooms along, the reflection was
##     most of a screen to the right of the sun.
##   * Substation's pylon plate was generated with its own sky, and the keying
##     pass that removed the sky left the moon and the stars behind as islands --
##     so the moon existed twice, once at 0.05 and once at 0.2.
##
## Neither is visible in a still. Both are obvious the moment the camera moves,
## which is why this is a test rather than a look.
extends TestCase

## The backdrops under test, and which plate in each is allowed to hold the
## bright things. Everything else must be silhouette.
const BACKDROPS := {
	"dawn_boardwalk": {
		"script": preload("res://scenes/stages/dawn_boardwalk/parallax_background.gd"),
		"light_source": "Sky",
		# Its reflection is the deliberate exception: the same object on a second
		# plate, locked to the first by an equal scroll factor. Checked in detail
		# by tests/test_backdrop_bands.gd.
		"paired": "SunGlint",
	},
	"substation": {
		"script": preload("res://scenes/stages/substation/parallax_background.gd"),
		"light_source": "Sky",
		"paired": "",
	},
}

## How much brighter than its own plate's median a pixel has to be to count as
## light. Relative, because a dawn sky is bright everywhere and a night one is
## dark everywhere, and an absolute cut-off would call half of stage 1's sky a
## sun and none of stage 2's moon one.
const LIGHT_ABOVE_MEDIAN := 0.30

## **The size of the largest connected bright region is what separates a landmark
## from detail**, and it is not a close call. Measured across every plate in both
## stages:
##
##   the duplicated sun in the water plate      500 px
##   the duplicated moon in the pylon plate      71 px
##   ------------------------------------------------ the line sits here
##   transformer lamps on the yard plate         17 px
##   spray on the water, rust on the pilings    3-5 px
##
## A moon is one blob. A row of lamps is thirty small ones, and counting bright
## *pixels* would rank the lamps (268) above the moon (94) and catch the wrong
## thing. Four times the headroom either side of 32.
const MAX_LANDMARK_BLOB := 32


func test_only_one_plate_per_backdrop_carries_the_light() -> void:
	for name in BACKDROPS:
		var entry: Dictionary = BACKDROPS[name]
		var script: GDScript = entry["script"]
		for plate in _plates(script):
			var plate_name := String(plate["name"])
			if plate_name == String(entry["light_source"]) \
					or plate_name == String(entry["paired"]):
				continue
			var blob := _largest_light_blob(script, plate)
			assert_true(blob <= MAX_LANDMARK_BLOB,
				"%s/%s carries a %d-pixel light; the sky owns the light, or the copies drift apart"
					% [name, plate_name, blob])


## And the plate that is allowed to have it must actually have it -- a rule that
## only ever says "no" would pass just as well against a backdrop with no sky.
func test_the_light_source_plate_actually_has_light_on_it() -> void:
	for name in BACKDROPS:
		var entry: Dictionary = BACKDROPS[name]
		var script: GDScript = entry["script"]
		var plate := _plate(script, String(entry["light_source"]))
		assert_false(plate.is_empty(), "%s has no %s plate" % [name, entry["light_source"]])
		assert_true(_largest_light_blob(script, plate) > MAX_LANDMARK_BLOB,
			"%s/%s has nothing bright on it" % [name, entry["light_source"]])


## Every plate a backdrop names must exist on disk. A missing one is a band of
## flat colour where the horizon should be, which reads as art nobody made.
func test_every_named_plate_is_on_disk() -> void:
	for name in BACKDROPS:
		var script: GDScript = BACKDROPS[name]["script"]
		for plate in _plates(script):
			if not plate.has("file"):
				continue  # drawn in code, not loaded
			var path: String = script.PLATE_DIR + String(plate["file"])
			assert_true(ResourceLoader.exists(path), "%s: missing plate %s" % [name, path])


# --- Helpers -------------------------------------------------------------------

## Every plate a backdrop declares, across all of its bands.
func _plates(script: GDScript) -> Array:
	var out: Array = []
	for key in ["PLATES", "YARD_PLATES", "TRENCH_PLATES", "UNDER_PLATES"]:
		if key in script:
			out.append_array(script.get(key))
	return out


func _plate(script: GDScript, name: String) -> Dictionary:
	for plate in _plates(script):
		if String(plate["name"]) == name:
			return plate
	return {}


## The size of the biggest connected run of light on a plate.
func _largest_light_blob(script: GDScript, plate: Dictionary) -> int:
	if not plate.has("file"):
		return 0
	var path: String = script.PLATE_DIR + String(plate["file"])
	if not ResourceLoader.exists(path):
		return 0
	var texture := load(path) as Texture2D
	if texture == null:
		return 0
	var image := texture.get_image()
	var width := image.get_width()
	var height := image.get_height()

	# The plate's own median luminance, so the threshold follows the art.
	var levels: Array[float] = []
	for y in height:
		for x in width:
			var c := image.get_pixel(x, y)
			if c.a >= 0.5:
				levels.append(_luminance(c))
	if levels.is_empty():
		return 0
	levels.sort()
	var cut: float = levels[levels.size() / 2] + LIGHT_ABOVE_MEDIAN

	var lit := {}
	for y in height:
		for x in width:
			var c := image.get_pixel(x, y)
			if c.a >= 0.5 and _luminance(c) > cut:
				lit[Vector2i(x, y)] = true

	var seen := {}
	var best := 0
	for start: Vector2i in lit:
		if seen.has(start):
			continue
		var queue: Array[Vector2i] = [start]
		seen[start] = true
		var size := 0
		while not queue.is_empty():
			var at: Vector2i = queue.pop_back()
			size += 1
			for dx in [-1, 0, 1]:
				for dy in [-1, 0, 1]:
					var next := at + Vector2i(dx, dy)
					if lit.has(next) and not seen.has(next):
						seen[next] = true
						queue.append(next)
		best = maxi(best, size)
	return best


func _luminance(c: Color) -> float:
	return 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b
