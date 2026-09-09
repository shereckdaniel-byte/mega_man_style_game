## Parallax backdrop for stage 5, "Turbine Row".
##
## Same `show_band` / `band_node` contract as stages 1-4 -- `AuthoredStage` swaps
## bands on a room change and does not care which stage it is talking to. Three
## bands here, because the stage is a V: the causeway out, the sea deck at the
## bottom of it, and the nacelle at the top of the climb.
##
## ### Every plate is drawn in code, and that is the greybox
##
## The other four backdrops load PNGs out of `assets/backgrounds/<stage>/`. This
## one has none yet, and `tests/test_backdrops.gd` would rather be told that than
## find a plate missing at load: a plate that fails to load is a band of flat
## colour where the horizon should be, which reads as art nobody made rather than
## as art nobody has made **yet**. A plate with no `file` key is a plate the test
## skips by design.
##
## So this is a real backdrop with placeholder art, in the same shape the
## generated one will have -- three plates, one horizon row, the same scroll
## rates. Swapping in `sky.png`, `rows.png` and `sea.png` later is adding a
## `file` key to three dictionaries and deleting the drawing code, not
## rewriting the band machinery.
##
## ### The light stays on the sky, in advance
##
## The rule `tests/test_backdrops.gd` exists for -- a landmark lives on exactly
## one plate -- costs nothing to obey now and is expensive to retrofit, so the
## overcast disc is on the sky plate and the turbine rows carry no bright pixels
## at all. When the art lands it has to keep that arrangement; writing it down
## here is what makes that a requirement rather than a preference.
extends Node2D

## Kept for symmetry with the other four backdrops and for
## `tests/test_backdrops.gd`, which joins it to a plate's `file`. Nothing here
## has a `file` yet.
const PLATE_DIR := "res://assets/backgrounds/turbine_row/"

## Copies drawn either side of the origin copy.
const REPEAT_TIMES := 3

## Width of one drawn tile, in plate pixels. A viewport is 1920 / 4.5 = 427 of
## them across, so a 512-px tile is a little wider than the screen and the seam
## is never in view twice.
const TILE_WIDTH := 512.0

## Where the deck sits in each band, in plate pixels from the top of the
## viewport. A room is one screen tall with its deck on row 11 of 15, so
## 11/15 of 240. Written down rather than eyeballed -- stage 3 shipped its
## waterline sixteen pixels under its own walkway.
const DECK_PLATE_ROW := 176.0

## The sea is the same water from all three bands; what changes is how much of
## it you can see. The nacelle sees furthest and the sea deck is nearly on it.
const HORIZON_NACELLE := DECK_PLATE_ROW - 26.0
const HORIZON_CAUSEWAY := DECK_PLATE_ROW - 10.0
const HORIZON_SEA := DECK_PLATE_ROW

const BAND_NACELLE := 0
const BAND_CAUSEWAY := 1
const BAND_SEA := 2

## The palette. An offshore wind farm in weather: high cloud, cold water, and
## turbines that are white in life and read as silhouette against a bright sky.
const SKY_HIGH := Color(0.60, 0.70, 0.80)
const SKY_LOW := Color(0.80, 0.86, 0.90)
const SUN_DISC := Color(0.99, 0.99, 0.96)
const ROW_FAR := Color(0.46, 0.55, 0.64)
const ROW_NEAR := Color(0.33, 0.41, 0.50)
const SEA_DEEP := Color(0.20, 0.30, 0.40)
const SEA_FOAM := Color(0.52, 0.64, 0.72)

const NACELLE_PLATES := [
	{"name": "Sky", "draw": "sky", "scroll": 0.05, "top": 0.0, "z": -100},
	{"name": "Rows", "draw": "rows", "scroll": 0.16,
		"top": HORIZON_NACELLE - 96.0, "z": -90, "scale": 0.7},
	{"name": "Sea", "draw": "sea", "scroll": 0.34, "top": HORIZON_NACELLE,
		"z": -80},
]

const CAUSEWAY_PLATES := [
	{"name": "Sky", "draw": "sky", "scroll": 0.05, "top": 0.0, "z": -100},
	{"name": "Rows", "draw": "rows", "scroll": 0.2,
		"top": HORIZON_CAUSEWAY - 120.0, "z": -90},
	{"name": "Sea", "draw": "sea", "scroll": 0.4, "top": HORIZON_CAUSEWAY,
		"z": -80},
]

const SEA_PLATES := [
	{"name": "Sky", "draw": "sky", "scroll": 0.05, "top": 0.0, "z": -100},
	# From the sea deck the far rows are nearly edge-on to the horizon, so they
	# are pushed down against it rather than standing above it.
	{"name": "Rows", "draw": "rows", "scroll": 0.22,
		"top": HORIZON_SEA - 104.0, "z": -90},
	{"name": "Sea", "draw": "sea", "scroll": 0.45, "top": HORIZON_SEA, "z": -80},
]

var _bands: Dictionary = {}


func _ready() -> void:
	_bands[BAND_NACELLE] = _build_band("Nacelle", NACELLE_PLATES)
	_bands[BAND_CAUSEWAY] = _build_band("Causeway", CAUSEWAY_PLATES)
	_bands[BAND_SEA] = _build_band("Sea", SEA_PLATES)
	show_band(BAND_CAUSEWAY)


func show_band(band: int) -> void:
	for key in _bands:
		var node: Node2D = _bands[key]
		if node != null:
			node.visible = key == band


func band_node(band: int) -> Node2D:
	return _bands.get(band, null)


func _build_band(band_name: String, plates: Array) -> Node2D:
	var holder := Node2D.new()
	holder.name = band_name
	add_child(holder)
	for plate in plates:
		_add_plate(holder, plate)
	return holder


func _add_plate(into: Node2D, plate: Dictionary) -> void:
	var autoload := get_node_or_null(^"/root/Tuning")
	var world: float = autoload.player.world_scale if autoload != null else 4.5
	# Optional per-plate scale, for the same art seen from further away. Both
	# axes, deliberately: squashing only the height gives stubby turbines at the
	# same apparent distance rather than a row further away.
	var art: float = float(plate.get("scale", 1.0))
	var scale_factor := world * art

	var layer := Parallax2D.new()
	layer.name = String(plate["name"])
	layer.scroll_scale = Vector2(float(plate["scroll"]), 0.0)
	layer.repeat_size = Vector2(TILE_WIDTH * scale_factor, 0.0)
	layer.repeat_times = REPEAT_TIMES
	# Against the viewport, not the world: a plate that drifted when the camera
	# rose would walk its horizon off the top of the screen.
	layer.follow_viewport = true
	into.add_child(layer)

	var piece := Plate.new()
	piece.kind = String(plate["draw"])
	piece.scale = Vector2(scale_factor, scale_factor)
	# `top` is in plate pixels against the viewport, so it scales by world and
	# not by the plate's own art scale -- a plate drawn smaller must still sit on
	# the horizon its band put it on.
	piece.position = Vector2(0.0, float(plate["top"]) * world)
	piece.z_index = int(plate["z"])
	layer.add_child(piece)


## One drawn plate. An inner class rather than three scripts: the whole of the
## greybox is `_draw`, and three files whose only difference is a match arm would
## be three files to delete when the art lands.
##
## It carries its own copies of the width and the palette. An inner class does
## not see the outer script's constants, and the alternative -- passing six
## colours in through fields -- is more machinery than the thing it configures.
class Plate:
	extends Node2D

	const W := 512.0
	const SKY_HIGH := Color(0.60, 0.70, 0.80)
	const SKY_LOW := Color(0.80, 0.86, 0.90)
	const SUN_DISC := Color(0.99, 0.99, 0.96)
	const ROW_FAR := Color(0.46, 0.55, 0.64)
	const ROW_NEAR := Color(0.33, 0.41, 0.50)
	const SEA_DEEP := Color(0.20, 0.30, 0.40)
	const SEA_FOAM := Color(0.52, 0.64, 0.72)

	var kind := "sky"

	func _draw() -> void:
		match kind:
			"sky":
				_draw_sky()
			"rows":
				_draw_rows()
			"sea":
				_draw_sea()

	## Banded rather than smooth: a gradient at 4.5x reads as a gradient, and
	## every other backdrop in the game is flat bands of colour.
	func _draw_sky() -> void:
		var height := 240.0
		for i in 6:
			var t := float(i) / 5.0
			draw_rect(Rect2(Vector2(0.0, height * float(i) / 6.0),
				Vector2(W, height / 6.0 + 1.0)), SKY_HIGH.lerp(SKY_LOW, t))
		# The one landmark, and it lives here and nowhere else.
		draw_circle(Vector2(W * 0.72, 46.0), 13.0, SUN_DISC)

	## A row of turbines, back row behind front row. No bright pixels: a turbine
	## is white in life and a silhouette against a bright sky, which is both what
	## it looks like and what keeps the light on one plate.
	func _draw_rows() -> void:
		_draw_turbine_row(0.0, 0.62, ROW_FAR, 7)
		_draw_turbine_row(38.0, 1.0, ROW_NEAR, 4)

	func _draw_turbine_row(offset_y: float, size: float, colour: Color,
			count: int) -> void:
		var base := 120.0 + offset_y
		var mast := 96.0 * size
		for i in count:
			var x := W * (float(i) + 0.5) / float(count)
			draw_line(Vector2(x, base), Vector2(x, base - mast), colour, 3.0 * size)
			var hub := Vector2(x, base - mast)
			draw_circle(hub, 3.0 * size, colour)
			# Three blades at 120 degrees, turned a little per turbine so the row
			# does not read as one shape stamped repeatedly.
			var turn := float(i) * 0.7
			for blade in 3:
				var angle := turn + float(blade) * TAU / 3.0
				draw_line(hub, hub + Vector2.UP.rotated(angle) * 34.0 * size,
					colour, 2.0 * size)

	## Flat water with a few foam dashes. It sits at the plate's origin, so the
	## horizon its band chose is the top edge of what is drawn here.
	func _draw_sea() -> void:
		draw_rect(Rect2(Vector2.ZERO, Vector2(W, 240.0)), SEA_DEEP)
		for i in 22:
			var x := W * float(i) / 22.0
			var y := 6.0 + float((i * 13) % 40)
			draw_line(Vector2(x, y), Vector2(x + 14.0, y), SEA_FOAM, 2.0)
