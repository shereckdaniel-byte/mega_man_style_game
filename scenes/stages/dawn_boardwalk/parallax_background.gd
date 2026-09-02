## Parallax backdrop for stage 1, "Dawn Boardwalk".
##
## Built in code from a plate table rather than authored as a .tscn, for the
## same reason as test_room.gd: every entry here exists to hold one number --
## its scroll factor -- and the table says which. SPRITES.md section 8a is the
## source of those factors.
##
## Only the plates that exist are listed. Skyline, water and foreground are
## still to be generated; adding one is a row in PLATES, not new code.
##
## The boardwalk itself is deliberately absent: it is the surface the player
## stands on, so it is a TileMapLayer with collision, not a plate here.
extends Node2D

## Source art is pixel art authored at 1 art px == 1 NES px, so a plate is
## scaled by the same world_scale as everything else. The sky is 400x240, which
## at 4.5 is exactly 1800x1080 -- a full viewport height with no resampling.
const PLATE_DIR := "res://assets/backgrounds/dawn_boardwalk/"

## Copies drawn either side of the origin copy. A plate is a full viewport wide,
## so one either side is already more than a camera can outrun in a frame.
const REPEAT_TIMES := 3

## `scroll` is Parallax2D.scroll_scale.x. Vertical scroll is 0 on every plate:
## a plate is sized to the viewport height exactly, so any vertical drift would
## walk its edge into frame. Skies are conventionally locked vertically anyway.
##
## `z` orders the plates against the player, who is at the default z of 0.
const PLATES := [
	{"name": "Sky", "file": "sky.png", "scroll": 0.05, "z": -100},
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
	sprite.scale = Vector2(scale_factor, scale_factor)
	# The project default is Linear and must stay Linear for the character, which
	# is smooth HD art minified to 0.61x. These plates are the opposite case:
	# 16-px-grid pixel art magnified 4.5x, which Linear would blur into mush.
	# CanvasItem.texture_filter is the per-node override that lets both be right
	# in the same frame. See SPRITES.md section 8.
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	layer.add_child(sprite)
