## Parallax backdrop for stage 3, "Breakers".
##
## Same shape and the same `show_band` / `band_node` contract as stages 1 and 2 --
## `AuthoredStage` swaps bands on a room change and does not care which stage it
## is talking to. What is new here is that there are **three** bands rather than
## two, because the stage climbs: the waterline it starts on, the inside of a
## hull, and the gantry over the top.
##
## ### The sky plate had a sun in it, and the sun had to go
##
## `create_image_pixflux` was asked for an empty banded sky and returned a
## complete scene -- cloud, a low sun, a skyline and water. That is the failure
## SPRITES.md section 8c records for stage 1's water, and it matters more here
## than "the composition is wrong": a landmark baked into the sky plate scrolls
## at the sky's 0.05 while the hulls plate in front of it scrolls at 0.2, so the
## two horizons slide across each other. Stage 2 shipped that bug and M6b fixed
## it by moving pixels rather than regenerating.
##
## So the shipped plate is the generated one **cropped above its own horizon**.
## The cut is measured rather than eyeballed: the first row whose longest run of
## pixels darker than 120 exceeds 8 px is where the silhouettes start (cloud
## speckle never manages more than 4), which puts it at row 159, and the plate
## keeps rows 0-154 stretched back to full height with NEAREST. Flat bands stay
## flat under nearest-neighbour; they only get thicker.
##
## ### The water is derived, not generated
##
## Still water is the sky mirrored about the waterline, so `water.png` is exactly
## that -- darkened and cooled with depth, with debris scattered on it. It costs
## no generations and it cannot drift out of palette with the sky, because it
## *is* the sky. Stage 1 arrived at the same answer after discarding two
## generated water plates.
extends Node2D

## Source art is authored at 1 art px == 1 NES px, so a plate scales by the same
## world_scale as everything else and plate coordinates are in art pixels --
## 240 of them is one viewport height.
const PLATE_DIR := "res://assets/backgrounds/breakers/"

## Copies drawn either side of the origin copy. A plate is a full viewport wide,
## so one either side is already more than a camera can outrun in a frame.
const REPEAT_TIMES := 3

## Where the waterline sits in each open band, in plate pixels from the top of
## the viewport.
##
## **Both are at or below the deck line, and that is not a matter of taste.** A
## room is one screen tall with its deck on row 11 of 15, so the deck lands at
## 11/15 of 240 = 176 plate px. The first version of this put the waterline at
## 150 and the stage shipped with its walkway sixteen pixels *under* the sea --
## which looked exactly like art nobody had checked, because it was.
##
## Two numbers rather than one because the player's eye is three screens higher
## at the end of the stage than at the start, and a backdrop that did not
## acknowledge the climb would make the climb invisible. The gantry sees more
## water and smaller hulls: its plate is drawn at 0.62 scale, and **scaling both
## axes is what makes distance read** -- squashing only the height gives stubby
## ships at the same apparent distance (SPRITES.md section 8c).
const DECK_PLATE_ROW := 176.0
const HORIZON_WATER := DECK_PLATE_ROW
const HORIZON_GANTRY := DECK_PLATE_ROW - 8.0

## Vertical scroll is 0 on every plate. A plate is placed against the viewport
## rather than the world, so it must not drift when the camera rises, or the
## horizon walks off the top of the screen.
##
## `z` orders against the player, who sits at the default z of 0.
const WATER_PLATES := [
	{"name": "Sky", "file": "sky.png", "scroll": 0.05, "top": 0.0, "z": -100},
	{"name": "Hulls", "file": "hulls.png", "scroll": 0.2,
		"top": HORIZON_WATER - 96.0, "z": -90},
	{"name": "Water", "file": "water.png", "scroll": 0.4, "top": HORIZON_WATER,
		"z": -80},
]

const GANTRY_PLATES := [
	{"name": "Sky", "file": "sky.png", "scroll": 0.05, "top": 0.0, "z": -100},
	{"name": "Hulls", "file": "hulls.png", "scroll": 0.18,
		"top": HORIZON_GANTRY - 60.0, "z": -90, "scale": 0.62},
	{"name": "Water", "file": "water.png", "scroll": 0.35, "top": HORIZON_GANTRY,
		"z": -80},
]

## One plate, full height. The hull's inside has no horizon: it is a wall, and a
## wall that scrolled at 0.05 would read as the player being on a treadmill.
const HULL_PLATES := [
	{"name": "Bulkhead", "file": "interior.png", "scroll": 0.45, "top": 0.0,
		"z": -100},
]

const BAND_GANTRY := 0
const BAND_HULL := 1
const BAND_WATER := 2

var _bands: Dictionary = {}


func _ready() -> void:
	_bands[BAND_GANTRY] = _build_band("Gantry", GANTRY_PLATES)
	_bands[BAND_HULL] = _build_band("Hull", HULL_PLATES)
	_bands[BAND_WATER] = _build_band("Water", WATER_PLATES)
	show_band(BAND_WATER)


## Shows one band's plates and hides the others.
func show_band(band: int) -> void:
	for key in _bands:
		var node: Node2D = _bands[key]
		if node != null:
			node.visible = key == band


func band_node(band: int) -> Node2D:
	return _bands.get(band, null)


func _build_band(name: String, plates: Array) -> Node2D:
	var holder := Node2D.new()
	holder.name = name
	add_child(holder)
	for plate in plates:
		var texture := _load_plate(plate)
		if texture == null:
			continue
		_add_plate(holder, plate, texture)
	return holder


func _load_plate(plate: Dictionary) -> Texture2D:
	var path: String = PLATE_DIR + String(plate["file"])
	if not ResourceLoader.exists(path):
		# Loud, not silent. A missing plate is a hole in the sky, and the
		# symptom -- a band of flat colour where the horizon should be -- looks
		# exactly like art nobody made.
		push_error("breakers: missing plate %s" % path)
		return null
	return load(path) as Texture2D


func _add_plate(into: Node2D, plate: Dictionary, texture: Texture2D) -> void:
	var autoload := get_node_or_null(^"/root/Tuning")
	var world: float = autoload.player.world_scale if autoload != null else 4.5
	# Optional per-plate scale, for a plate that is the same art seen from
	# further away. Both axes, deliberately -- see HORIZON_GANTRY.
	var art: float = float(plate.get("scale", 1.0))
	var scale_factor := world * art

	var layer := Parallax2D.new()
	layer.name = String(plate["name"])
	layer.scroll_scale = Vector2(float(plate["scroll"]), 0.0)
	layer.repeat_size = Vector2(float(texture.get_width()) * scale_factor, 0.0)
	layer.repeat_times = REPEAT_TIMES
	# Against the viewport, not the world: see the note on vertical scroll above.
	layer.follow_viewport = true
	into.add_child(layer)

	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.centered = false
	sprite.scale = Vector2(scale_factor, scale_factor)
	# `top` is in plate pixels against the viewport, so it scales by world and
	# not by the plate's own art scale -- a plate drawn smaller must still sit on
	# the horizon the band put it on.
	sprite.position = Vector2(0.0, float(plate["top"]) * world)
	sprite.z_index = int(plate["z"])
	# Pixel art magnified: nearest, like the tilesets. The project default is
	# Linear and must stay Linear for the character (SPRITES.md section 8).
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	layer.add_child(sprite)
