## Parallax backdrop for stage 8, "Sinkhole".
##
## Same `show_band` / `band_node` contract as stages 1-7. Three bands, and the
## stage spirals down through them: the collapsed surface, the gallery, and the
## flooded bottom where Quarry is.
##
## Drawn in code like stages 5-7. See Turbine Row's backdrop for why a plate
## with no `file` key beats a plate that fails to load.
##
## **It is the only backdrop that gets darker as the player descends and then
## brighter again at the bottom** -- the flooded level is lit from under the
## water, which is the one light source in the game that comes from below and
## is not a fire. Stage 6 is lit from below by its own furnaces; this is the
## same trick in the opposite temperature, and the two stages read as a pair
## because of it.
extends Node2D

const PLATE_DIR := "res://assets/backgrounds/sinkhole/"
const REPEAT_TIMES := 3
const TILE_WIDTH := 512.0

const DECK_PLATE_ROW := 176.0
const HORIZON_SURFACE := DECK_PLATE_ROW - 22.0
const HORIZON_GALLERY := DECK_PLATE_ROW
const HORIZON_SUMP := DECK_PLATE_ROW - 6.0

const BAND_SURFACE := 0
const BAND_GALLERY := 1
const BAND_SUMP := 2

const SURFACE_PLATES := [
	{"name": "Sky", "draw": "sky", "scroll": 0.05, "top": 0.0, "z": -100},
	{"name": "Rim", "draw": "rim", "scroll": 0.2,
		"top": HORIZON_SURFACE - 110.0, "z": -90},
	{"name": "Ground", "draw": "ground", "scroll": 0.42, "top": HORIZON_SURFACE,
		"z": -80},
]

const GALLERY_PLATES := [
	{"name": "Dark", "draw": "dark", "scroll": 0.05, "top": 0.0, "z": -100},
	{"name": "Rim", "draw": "rim", "scroll": 0.26,
		"top": HORIZON_GALLERY - 132.0, "z": -90, "scale": 1.2},
	{"name": "Ground", "draw": "ground", "scroll": 0.46, "top": HORIZON_GALLERY,
		"z": -80},
]

const SUMP_PLATES := [
	{"name": "Glow", "draw": "glow", "scroll": 0.05, "top": 0.0, "z": -100},
	{"name": "Rim", "draw": "rim", "scroll": 0.24,
		"top": HORIZON_SUMP - 120.0, "z": -90, "scale": 1.1},
	{"name": "Ground", "draw": "ground", "scroll": 0.44, "top": HORIZON_SUMP,
		"z": -80},
]

var _bands: Dictionary = {}


func _ready() -> void:
	_bands[BAND_SURFACE] = _build_band("Surface", SURFACE_PLATES)
	_bands[BAND_GALLERY] = _build_band("Gallery", GALLERY_PLATES)
	_bands[BAND_SUMP] = _build_band("Sump", SUMP_PLATES)
	show_band(BAND_SURFACE)


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
	var art: float = float(plate.get("scale", 1.0))
	var scale_factor := world * art

	var layer := Parallax2D.new()
	layer.name = String(plate["name"])
	layer.scroll_scale = Vector2(float(plate["scroll"]), 0.0)
	layer.repeat_size = Vector2(TILE_WIDTH * scale_factor, 0.0)
	layer.repeat_times = REPEAT_TIMES
	layer.follow_viewport = true
	into.add_child(layer)

	var piece := Plate.new()
	piece.kind = String(plate["draw"])
	piece.scale = Vector2(scale_factor, scale_factor)
	piece.position = Vector2(0.0, float(plate["top"]) * world)
	piece.z_index = int(plate["z"])
	layer.add_child(piece)


## One drawn plate. Carries its own copies of the width and palette: an inner
## class does not see the outer script's constants.
class Plate:
	extends Node2D

	const W := 512.0
	const SKY_HIGH := Color(0.46, 0.52, 0.56)
	const SKY_LOW := Color(0.68, 0.70, 0.66)
	const DARK_HIGH := Color(0.07, 0.08, 0.10)
	const DARK_LOW := Color(0.16, 0.17, 0.20)
	const GLOW_HIGH := Color(0.08, 0.14, 0.18)
	const GLOW_LOW := Color(0.20, 0.44, 0.52)
	const ROCK_FAR := Color(0.30, 0.28, 0.27)
	const ROCK_NEAR := Color(0.19, 0.18, 0.18)
	const GROUND := Color(0.26, 0.24, 0.22)
	const SEEP := Color(0.34, 0.58, 0.64)

	var kind := "sky"

	func _draw() -> void:
		match kind:
			"sky":
				_draw_gradient(SKY_HIGH, SKY_LOW)
			"dark":
				_draw_gradient(DARK_HIGH, DARK_LOW)
			"glow":
				# The only gradient in the game that is brightest at the bottom
				# and cold: lit from under the water.
				_draw_gradient(GLOW_HIGH, GLOW_LOW)
			"rim":
				_draw_rim()
			"ground":
				_draw_ground()

	func _draw_gradient(high: Color, low: Color) -> void:
		var height := 240.0
		for i in 7:
			var t := float(i) / 6.0
			draw_rect(Rect2(Vector2(0.0, height * float(i) / 7.0),
				Vector2(W, height / 7.0 + 1.0)), high.lerp(low, t * t))

	## The sinkhole's walls: broken strata stepping down. No bright pixels, so
	## nothing here can read as a landmark and be duplicated across two scroll
	## rates -- the rule `tests/test_backdrops.gd` exists for.
	func _draw_rim() -> void:
		_draw_strata(0.0, 0.7, ROCK_FAR)
		_draw_strata(30.0, 1.0, ROCK_NEAR)

	func _draw_strata(offset_y: float, size: float, colour: Color) -> void:
		var base := 140.0 + offset_y
		var steps := 7
		for i in steps:
			var x := W * float(i) / float(steps)
			var w := W / float(steps) + 2.0
			# A jagged profile from the index, so the wall is broken rock rather
			# than a staircase.
			var h := (34.0 + float((i * 29) % 46)) * size
			draw_rect(Rect2(Vector2(x, base - h), Vector2(w, h)), colour)
			# A bedding plane across each block.
			draw_rect(Rect2(Vector2(x, base - h * 0.55), Vector2(w, 3.0 * size)),
				Color(colour.darkened(0.25), 0.8))

	## Spoil and standing water.
	func _draw_ground() -> void:
		draw_rect(Rect2(Vector2.ZERO, Vector2(W, 240.0)), GROUND)
		for i in 11:
			var x := W * float(i) / 11.0
			var y := 8.0 + float((i * 23) % 44)
			var w := 26.0 + float((i * 17) % 38)
			draw_rect(Rect2(Vector2(x, y), Vector2(w, 5.0)), Color(SEEP, 0.5))
