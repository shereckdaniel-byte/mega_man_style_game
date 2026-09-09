## Parallax backdrop for stage 6, "Stack".
##
## Same `show_band` / `band_node` contract as stages 1-5. Three bands, and the
## stage only ever goes **down** through them: the tip floor out under the
## chimneys, the flue gallery below it, and the furnace hall at the bottom where
## Cinder is.
##
## **Drawn in code, like Turbine Row's**, because stage 6's art has not been
## generated either -- see that backdrop's docstring for why a plate with no
## `file` key is better than a plate that fails to load. Swapping in real PNGs
## later is adding a `file` key to three dictionaries.
##
## The palette is the point of difference. Five stages so far are a dawn, a
## blackout, a rust yard, a bleached noon and an overcast sea; this one is the
## only one lit from **below**, by its own fires. So the sky is the darkest in
## the game and the ground is the brightest thing in the frame, which is the
## exact inversion of every other stage and is what will make a screenshot of it
## unmistakable.
extends Node2D

const PLATE_DIR := "res://assets/backgrounds/stack/"
const REPEAT_TIMES := 3
const TILE_WIDTH := 512.0

## A room is one screen tall with its deck on row 11 of 15, so the deck lands at
## 11/15 of 240 plate px. Written down rather than eyeballed -- stage 3 shipped
## its waterline sixteen pixels under its own walkway.
const DECK_PLATE_ROW := 176.0
const HORIZON_TIP := DECK_PLATE_ROW - 30.0
const HORIZON_HALL := DECK_PLATE_ROW
const HORIZON_GALLERY := DECK_PLATE_ROW - 14.0

const BAND_TIP := 0
const BAND_GALLERY := 1
const BAND_HALL := 2

const TIP_PLATES := [
	{"name": "Sky", "draw": "sky", "scroll": 0.05, "top": 0.0, "z": -100},
	{"name": "Stacks", "draw": "stacks", "scroll": 0.18,
		"top": HORIZON_TIP - 130.0, "z": -90},
	{"name": "Ground", "draw": "ground", "scroll": 0.4, "top": HORIZON_TIP,
		"z": -80},
]

const HALL_PLATES := [
	{"name": "Sky", "draw": "sky", "scroll": 0.05, "top": 0.0, "z": -100},
	# Inside the hall the chimneys are overhead rather than on the skyline, so
	# the row is pushed down against the deck and reads as furnace bodies.
	{"name": "Stacks", "draw": "stacks", "scroll": 0.24,
		"top": HORIZON_HALL - 96.0, "z": -90, "scale": 0.8},
	{"name": "Ground", "draw": "ground", "scroll": 0.45, "top": HORIZON_HALL,
		"z": -80},
]

const GALLERY_PLATES := [
	{"name": "Sky", "draw": "sky", "scroll": 0.05, "top": 0.0, "z": -100},
	{"name": "Stacks", "draw": "stacks", "scroll": 0.15,
		"top": HORIZON_GALLERY - 150.0, "z": -90, "scale": 0.65},
	{"name": "Ground", "draw": "ground", "scroll": 0.34, "top": HORIZON_GALLERY,
		"z": -80},
]

var _bands: Dictionary = {}


func _ready() -> void:
	_bands[BAND_TIP] = _build_band("Tip", TIP_PLATES)
	_bands[BAND_GALLERY] = _build_band("Gallery", GALLERY_PLATES)
	_bands[BAND_HALL] = _build_band("Hall", HALL_PLATES)
	show_band(BAND_TIP)


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


## One drawn plate. Carries its own copies of the width and the palette: an
## inner class does not see the outer script's constants.
class Plate:
	extends Node2D

	const W := 512.0
	const SKY_HIGH := Color(0.10, 0.09, 0.14)
	const SKY_LOW := Color(0.34, 0.21, 0.18)
	const STACK_FAR := Color(0.20, 0.17, 0.20)
	const STACK_NEAR := Color(0.13, 0.11, 0.13)
	const GLOW := Color(0.86, 0.38, 0.14)
	const GROUND := Color(0.22, 0.16, 0.15)
	const SLAG := Color(0.90, 0.44, 0.16)

	var kind := "sky"

	func _draw() -> void:
		match kind:
			"sky":
				_draw_sky()
			"stacks":
				_draw_stacks()
			"ground":
				_draw_ground()

	## **Lit from the bottom.** Dark overhead, hot near the horizon: the fires
	## are the light source and they are on the ground, which is what inverts
	## this stage against the other five.
	func _draw_sky() -> void:
		var height := 240.0
		for i in 7:
			var t := float(i) / 6.0
			draw_rect(Rect2(Vector2(0.0, height * float(i) / 7.0),
				Vector2(W, height / 7.0 + 1.0)), SKY_HIGH.lerp(SKY_LOW, t * t))

	## Chimneys, back row behind front row. No bright pixels: the glow lives on
	## the sky plate's gradient and on the ground, so nothing here can duplicate
	## a landmark across two scroll rates.
	func _draw_stacks() -> void:
		_draw_stack_row(0.0, 0.66, STACK_FAR, 5)
		_draw_stack_row(26.0, 1.0, STACK_NEAR, 3)

	func _draw_stack_row(offset_y: float, size: float, colour: Color,
			count: int) -> void:
		var base := 150.0 + offset_y
		for i in count:
			var x := W * (float(i) + 0.5) / float(count)
			var w := 26.0 * size
			var h := 118.0 * size
			draw_rect(Rect2(Vector2(x - w * 0.5, base - h), Vector2(w, h)), colour)
			# A wider cap, so a chimney is a chimney and not a post.
			draw_rect(Rect2(Vector2(x - w * 0.72, base - h - 7.0 * size),
				Vector2(w * 1.44, 8.0 * size)), colour)
			# Smoke, as a stack of softening bars rather than a shape.
			for p in 4:
				var sy := base - h - 12.0 * size - float(p) * 13.0 * size
				draw_rect(Rect2(Vector2(x - w * (0.5 + 0.22 * float(p)), sy),
					Vector2(w * (1.0 + 0.44 * float(p)), 7.0 * size)),
					Color(colour, 0.5 - 0.1 * float(p)))

	## The tip: dark ground with channels of slag running through it. The
	## brightest thing in the frame, which is the inversion.
	func _draw_ground() -> void:
		draw_rect(Rect2(Vector2.ZERO, Vector2(W, 240.0)), GROUND)
		for i in 9:
			var x := W * float(i) / 9.0
			var y := 10.0 + float((i * 17) % 46)
			var w := 30.0 + float((i * 23) % 40)
			draw_rect(Rect2(Vector2(x, y), Vector2(w, 4.0)), Color(SLAG, 0.75))
			draw_rect(Rect2(Vector2(x + 4.0, y + 4.0), Vector2(w * 0.6, 2.0)),
				Color(GLOW, 0.4))
