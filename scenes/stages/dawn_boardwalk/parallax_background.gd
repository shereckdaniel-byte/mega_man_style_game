## Parallax backdrop for stage 1, "Dawn Boardwalk".
##
## Built in code from a plate table rather than authored as a .tscn, for the
## same reason as test_room.gd: every entry here exists to hold two numbers --
## its scroll factor and where it sits against the horizon -- and the table says
## which. SPRITES.md section 8a is the source of the scroll factors.
##
## The boardwalk itself is deliberately absent: it is the surface the player
## stands on, so it is a TileMapLayer with collision, not a plate here.
extends Node2D

## Source art is pixel art authored at 1 art px == 1 NES px, so a plate is
## scaled by the same world_scale as everything else. Plate coordinates below
## are therefore in art pixels, and 240 of them is one viewport height.
const PLATE_DIR := "res://assets/backgrounds/dawn_boardwalk/"

## Copies drawn either side of the origin copy. A plate is a full viewport wide,
## so one either side is already more than a camera can outrun in a frame.
const REPEAT_TIMES := 3

## Where the waterline sits, in plate pixels from the top of the viewport.
##
## Everything in the backdrop is hung off this one number: the skyline stands on
## it, the water starts at it, and the sun clears it. It is set just below the
## sun's disc -- the sun is centred on plate row 100 with a radius of about 26,
## so 130 leaves it fully clear of the water, which is the "low sun just above
## the horizon" the art direction asks for.
const HORIZON := 130.0

## `scroll` is Parallax2D.scroll_scale.x. `top` is the plate's top edge in plate
## pixels from the top of the viewport. `z` orders against the player, who sits
## at the default z of 0 -- so the pilings, alone, are drawn in front of them.
##
## Vertical scroll is 0 on every plate. A plate is placed against the viewport
## rather than the world, so it must not drift when the camera rises or the
## horizon would walk off the top of the screen.
const PLATES := [
	{"name": "Sky", "file": "sky.png", "scroll": 0.05, "top": 0.0, "z": -100},
	{"name": "Skyline", "file": "skyline.png", "scroll": 0.2, "top": HORIZON - 40.0, "z": -90},
	{"name": "Water", "file": "water.png", "scroll": 0.4, "top": HORIZON, "z": -80},
	{"name": "Pilings", "file": "pilings.png", "scroll": 1.2, "top": 156.0, "z": 100},
]


func _ready() -> void:
	var autoload := get_node_or_null(^"/root/Tuning")
	var scale_factor: float = autoload.player.world_scale if autoload != null else 4.5

	for plate in PLATES:
		_add_plate(plate, scale_factor)


func _add_plate(plate: Dictionary, scale_factor: float) -> void:
	var path: String = PLATE_DIR + String(plate["file"])
	var texture := load(path) as Texture2D
	if texture == null:
		push_error("dawn_boardwalk: missing plate %s" % path)
		return

	var size := Vector2(texture.get_size()) * scale_factor

	var layer := Parallax2D.new()
	layer.name = String(plate["name"])
	layer.scroll_scale = Vector2(float(plate["scroll"]), 0.0)
	# Tiles horizontally as the room scrolls; 0 on y leaves it un-repeated.
	layer.repeat_size = Vector2(size.x, 0.0)
	# repeat_size alone only says how wide a copy is. Without repeat_times the
	# layer draws one copy and leaves bare viewport either side of it, which is
	# visible the moment the camera moves off the plate's origin.
	layer.repeat_times = REPEAT_TIMES
	layer.z_index = int(plate["z"])
	add_child(layer)

	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.centered = false
	sprite.position = Vector2(0.0, float(plate["top"]) * scale_factor)
	sprite.scale = Vector2(scale_factor, scale_factor)
	# The project default is Linear and must stay Linear for the character, which
	# is smooth HD art minified to 0.61x. These plates are the opposite case:
	# pixel art magnified 4.5x, which Linear would blur into mush.
	# CanvasItem.texture_filter is the per-node override that lets both be right
	# in the same frame. See SPRITES.md section 8.
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	layer.add_child(sprite)
