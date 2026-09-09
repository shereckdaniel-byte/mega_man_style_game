## Parallax backdrop for stage 7, "Cold Store".
##
## Same `show_band` / `band_node` contract as stages 1-6. **Two bands**, which is
## fewer than any stage since the first: the plant is two decks of cold rooms
## stacked on each other and the stage crosses between them five times, so the
## two backdrops are seen more often than any others in the game and are drawn
## to be told apart at a glance rather than to be admired.
##
## Drawn in code like stages 5 and 6 -- see Turbine Row's backdrop for why a
## plate with no `file` key beats a plate that fails to load.
##
## The palette: fog. Every other stage has a horizon; a refrigerated dock has a
## wall of cold air about forty feet out, and everything past that is a shape.
## It is the only backdrop in the game with no visible sky on the lower band,
## which is what makes the upper one -- where there *is* one, pale and flat --
## worth climbing to.
extends Node2D

const PLATE_DIR := "res://assets/backgrounds/cold_store/"
const REPEAT_TIMES := 3
const TILE_WIDTH := 512.0

const DECK_PLATE_ROW := 176.0
const HORIZON_UPPER := DECK_PLATE_ROW - 18.0
const HORIZON_LOWER := DECK_PLATE_ROW

const BAND_UPPER := 0
const BAND_LOWER := 1

const UPPER_PLATES := [
	{"name": "Sky", "draw": "sky", "scroll": 0.05, "top": 0.0, "z": -100},
	{"name": "Racks", "draw": "racks", "scroll": 0.2,
		"top": HORIZON_UPPER - 108.0, "z": -90},
	{"name": "Floor", "draw": "floor", "scroll": 0.42, "top": HORIZON_UPPER,
		"z": -80},
]

const LOWER_PLATES := [
	{"name": "Fog", "draw": "fog", "scroll": 0.05, "top": 0.0, "z": -100},
	# Down here the racking is close and half-lost in the cold: bigger, dimmer,
	# and pushed against the deck.
	{"name": "Racks", "draw": "racks", "scroll": 0.26,
		"top": HORIZON_LOWER - 128.0, "z": -90, "scale": 1.15},
	{"name": "Floor", "draw": "floor", "scroll": 0.46, "top": HORIZON_LOWER,
		"z": -80},
]

var _bands: Dictionary = {}


func _ready() -> void:
	_bands[BAND_UPPER] = _build_band("Upper", UPPER_PLATES)
	_bands[BAND_LOWER] = _build_band("Lower", LOWER_PLATES)
	show_band(BAND_UPPER)


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
	const SKY_HIGH := Color(0.62, 0.72, 0.80)
	const SKY_LOW := Color(0.84, 0.90, 0.93)
	const FOG_HIGH := Color(0.46, 0.55, 0.62)
	const FOG_LOW := Color(0.70, 0.78, 0.83)
	const RACK := Color(0.38, 0.47, 0.55)
	const RACK_ICE := Color(0.58, 0.70, 0.78)
	const FLOOR_COLD := Color(0.52, 0.62, 0.68)
	const FROST := Color(0.82, 0.90, 0.94)

	var kind := "sky"

	func _draw() -> void:
		match kind:
			"sky":
				_draw_gradient(SKY_HIGH, SKY_LOW)
			"fog":
				_draw_gradient(FOG_HIGH, FOG_LOW)
			"racks":
				_draw_racks()
			"floor":
				_draw_floor()

	## Banded rather than smooth, like every other backdrop in the game: a
	## gradient at 4.5x reads as a gradient.
	func _draw_gradient(high: Color, low: Color) -> void:
		var height := 240.0
		for i in 7:
			var t := float(i) / 6.0
			draw_rect(Rect2(Vector2(0.0, height * float(i) / 7.0),
				Vector2(W, height / 7.0 + 1.0)), high.lerp(low, t))

	## Racking: uprights with shelves, iced over. No bright blobs -- the frost
	## is drawn as thin lines so nothing here can read as a landmark and get
	## duplicated across two scroll rates, which is the rule
	## `tests/test_backdrops.gd` exists for.
	func _draw_racks() -> void:
		var bays := 6
		var base := 128.0
		for i in bays:
			var x := W * (float(i) + 0.5) / float(bays)
			var w := 54.0
			var h := 112.0
			# Uprights.
			for side in [-1.0, 1.0]:
				draw_rect(Rect2(Vector2(x + side * w * 0.5 - 3.0, base - h),
					Vector2(6.0, h)), RACK)
			# Shelves, with a rime line on the upper edge of each.
			for level in 4:
				var y := base - h + 14.0 + float(level) * 26.0
				draw_rect(Rect2(Vector2(x - w * 0.5, y), Vector2(w, 5.0)), RACK)
				draw_rect(Rect2(Vector2(x - w * 0.5, y - 2.0), Vector2(w, 2.0)),
					RACK_ICE)

	## The floor: cold concrete with frost drifted along it.
	func _draw_floor() -> void:
		draw_rect(Rect2(Vector2.ZERO, Vector2(W, 240.0)), FLOOR_COLD)
		for i in 14:
			var x := W * float(i) / 14.0
			var y := 5.0 + float((i * 19) % 38)
			var w := 22.0 + float((i * 13) % 34)
			draw_rect(Rect2(Vector2(x, y), Vector2(w, 3.0)), Color(FROST, 0.5))
