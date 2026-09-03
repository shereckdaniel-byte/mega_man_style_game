## Parallax backdrop for stage 2, "Substation".
##
## Same shape as stage 1's -- a table of plates, each holding a scroll factor and
## a place against the horizon -- and the same `show_band` / `band_node` contract,
## because `AuthoredStage` swaps bands on a room change and does not care which
## stage it is talking to.
##
## Where it differs is that **both bands are generated plates here**, where stage
## 1 draws its under-deck set in code. That was the right call there: the
## boardwalk's underside is a depth gradient and some pilings, which describe
## themselves in three loops and want tuning against the tileset. A cable trench
## is cable trays, conduit and brick, which do not.
##
## The other difference is that most of this is going to be seen through
## `DarkRoom`'s overlay at 78% and only fully in the arc flashes. That is why the
## trench plate is a single mid-distance wall rather than a stack of four: three
## more layers of parallax nobody can see is three more plates to keep in step.
extends Node2D

## Source art is authored at 1 art px == 1 NES px, so a plate scales by the same
## world_scale as everything else and plate coordinates are in art pixels --
## 240 of them is one viewport height.
const PLATE_DIR := "res://assets/backgrounds/substation/"

## Copies drawn either side of the origin copy. A plate is a full viewport wide,
## so one either side is already more than a camera can outrun in a frame.
const REPEAT_TIMES := 3

## Where the yard's waterline sits, in plate pixels from the top of the viewport.
##
## Everything in the yard band hangs off this: the pylons stand on it and the
## transformer row is half sunk in it. Lower than stage 1's 130 because there is
## no sun to keep clear of -- the moon is high in the plate, and a lower horizon
## leaves more sky, which is the half of this band worth looking at.
const HORIZON := 150.0

## Vertical scroll is 0 on every plate. A plate is placed against the viewport
## rather than the world, so it must not drift when the camera rises, or the
## horizon walks off the top of the screen.
##
## `z` orders against the player, who sits at the default z of 0.
const YARD_PLATES := [
	{"name": "Sky", "file": "sky.png", "scroll": 0.05, "top": 0.0, "z": -100},
	{"name": "Pylons", "file": "pylons.png", "scroll": 0.2, "top": HORIZON - 116.0, "z": -90},
	{"name": "Transformers", "file": "yard.png", "scroll": 0.4, "top": HORIZON - 64.0, "z": -80},
]

## One plate, full height. The trench has no horizon: it is a wall, and a wall
## that scrolled at 0.05 would read as the player being on a treadmill.
const TRENCH_PLATES := [
	{"name": "TrenchWall", "file": "trench.png", "scroll": 0.45, "top": 0.0, "z": -100},
]

const BAND_YARD := 0
const BAND_TRENCH := 1

var _bands: Dictionary = {}


func _ready() -> void:
	_bands[BAND_YARD] = _build_band("Yard", YARD_PLATES)
	_bands[BAND_TRENCH] = _build_band("Trench", TRENCH_PLATES)
	show_band(BAND_YARD)


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
		push_error("substation: missing plate %s" % path)
		return null
	return load(path) as Texture2D


func _add_plate(into: Node2D, plate: Dictionary, texture: Texture2D) -> void:
	var autoload := get_node_or_null(^"/root/Tuning")
	var scale_factor: float = autoload.player.world_scale if autoload != null else 4.5

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
	sprite.position = Vector2(0.0, float(plate["top"]) * scale_factor)
	sprite.z_index = int(plate["z"])
	# Pixel art magnified: nearest, like the tilesets. The project default is
	# Linear and must stay Linear for the character (SPRITES.md section 8).
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	layer.add_child(sprite)
