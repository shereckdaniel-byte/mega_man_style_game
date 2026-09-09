## The fortress backdrop, shared by all four of its stages.
##
## **One backdrop for four stages, where the eight get one each.** The master
## stages are eight different places and their skies are the fastest way to say
## so; the fortress is one place, and four backdrops for it would be four
## answers to a question with one. What changes between its stages is the band
## the player is in -- and the fortress's three bands are a story rather than a
## palette: the sea outside, the works inside, and the flooded bottom the sea
## has already taken.
##
## Drawn in code, like stages 5-8. See Turbine Row's backdrop for why a plate
## with no `file` key beats a plate that fails to load.
##
## **It is the only backdrop in the game with a horizon in every band.** The
## eight are places you are inside of; this is a wall, and a wall has a far side.
## The far side is the drowned coast of stage 1, which is what the fortress did.
extends Node2D

const REPEAT_TIMES := 3
const TILE_WIDTH := 512.0

const DECK_PLATE_ROW := 176.0

## The three bands, named for what the sea has done to each.
const BAND_OUTSIDE := 0
const BAND_WORKS := 1
const BAND_FLOOD := 2

const OUTSIDE_PLATES := [
	{"name": "Sky", "draw": "dawn", "scroll": 0.05, "top": 0.0, "z": -100},
	{"name": "Wall", "draw": "wall", "scroll": 0.18,
		"top": DECK_PLATE_ROW - 128.0, "z": -90},
	{"name": "Apron", "draw": "apron", "scroll": 0.40, "top": DECK_PLATE_ROW,
		"z": -80},
]

const WORKS_PLATES := [
	{"name": "Dark", "draw": "dark", "scroll": 0.05, "top": 0.0, "z": -100},
	{"name": "Wall", "draw": "ribs", "scroll": 0.24,
		"top": DECK_PLATE_ROW - 140.0, "z": -90, "scale": 1.15},
	{"name": "Apron", "draw": "apron", "scroll": 0.44, "top": DECK_PLATE_ROW,
		"z": -80},
]

const FLOOD_PLATES := [
	{"name": "Green", "draw": "green", "scroll": 0.05, "top": 0.0, "z": -100},
	{"name": "Wall", "draw": "ribs", "scroll": 0.22,
		"top": DECK_PLATE_ROW - 120.0, "z": -90, "scale": 1.05},
	{"name": "Apron", "draw": "silt", "scroll": 0.42, "top": DECK_PLATE_ROW,
		"z": -80},
]

var _bands: Dictionary = {}


func _ready() -> void:
	_bands[BAND_OUTSIDE] = _build_band("Outside", OUTSIDE_PLATES)
	_bands[BAND_WORKS] = _build_band("Works", WORKS_PLATES)
	_bands[BAND_FLOOD] = _build_band("Flood", FLOOD_PLATES)
	show_band(BAND_OUTSIDE)


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
	const DAWN_HIGH := Color(0.20, 0.24, 0.36)
	const DAWN_LOW := Color(0.62, 0.48, 0.42)
	const DARK_HIGH := Color(0.06, 0.07, 0.09)
	const DARK_LOW := Color(0.14, 0.15, 0.18)
	const GREEN_HIGH := Color(0.05, 0.11, 0.11)
	const GREEN_LOW := Color(0.12, 0.28, 0.26)
	const CONCRETE_FAR := Color(0.28, 0.29, 0.31)
	const CONCRETE_NEAR := Color(0.19, 0.20, 0.22)
	const APRON := Color(0.23, 0.23, 0.24)
	const SILT := Color(0.17, 0.20, 0.19)
	const STAIN := Color(0.30, 0.36, 0.34)

	var kind := "dawn"

	func _draw() -> void:
		match kind:
			"dawn":
				_draw_gradient(DAWN_HIGH, DAWN_LOW)
			"dark":
				_draw_gradient(DARK_HIGH, DARK_LOW)
			"green":
				_draw_gradient(GREEN_HIGH, GREEN_LOW)
			"wall":
				_draw_wall()
			"ribs":
				_draw_ribs()
			"apron":
				_draw_apron(APRON)
			"silt":
				_draw_apron(SILT)

	func _draw_gradient(high: Color, low: Color) -> void:
		var height := 240.0
		for i in 7:
			var t := float(i) / 6.0
			draw_rect(Rect2(Vector2(0.0, height * float(i) / 7.0),
				Vector2(W, height / 7.0 + 1.0)), high.lerp(low, t * t))

	## The seawall from outside: one flat mass with expansion joints down it. No
	## bright pixels, so nothing here can read as a landmark and be duplicated
	## across two scroll rates -- the rule `tests/test_backdrops.gd` exists for.
	func _draw_wall() -> void:
		draw_rect(Rect2(Vector2(0.0, 40.0), Vector2(W, 200.0)), CONCRETE_FAR)
		for i in 9:
			var x := W * float(i) / 9.0
			draw_rect(Rect2(Vector2(x, 40.0), Vector2(4.0, 200.0)),
				CONCRETE_FAR.darkened(0.22))
		# The tide line: the height the sea has been getting to.
		draw_rect(Rect2(Vector2(0.0, 148.0), Vector2(W, 7.0)),
			Color(STAIN, 0.45))

	## The same wall from inside: buttresses, and the gaps between them.
	func _draw_ribs() -> void:
		draw_rect(Rect2(Vector2(0.0, 30.0), Vector2(W, 210.0)), CONCRETE_NEAR)
		for i in 7:
			var x := W * float(i) / 7.0
			var w := W / 7.0 * 0.42
			var h := 150.0 + float((i * 31) % 40)
			draw_rect(Rect2(Vector2(x, 240.0 - h), Vector2(w, h)),
				CONCRETE_FAR.darkened(0.1))

	func _draw_apron(colour: Color) -> void:
		draw_rect(Rect2(Vector2.ZERO, Vector2(W, 240.0)), colour)
		for i in 13:
			var x := W * float(i) / 13.0
			var y := 6.0 + float((i * 19) % 40)
			var w := 20.0 + float((i * 23) % 34)
			draw_rect(Rect2(Vector2(x, y), Vector2(w, 4.0)), Color(STAIN, 0.32))
