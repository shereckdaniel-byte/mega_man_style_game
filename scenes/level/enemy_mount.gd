## The post a fixed enemy is bolted to when it sits above the deck.
##
## Stage 1's Lampjacks stand two tiles up with nothing under them, which a
## playtester noticed within a minute of starting: "the turret looking enemy is
## just floating in the air". They were right, and it had been that way since M4.
##
## **This is scenery and has no collision, deliberately.** A solid pillar under
## every elevated turret would change what the player can stand on and jump over
## in half the rooms in the game, and invalidate traversal that the authoring
## tests and the playthrough bot have already signed off on. The fault was that
## the turret looked unattached; the fix is something for it to be attached to,
## not a change to the level's shape.
##
## Drawn rather than tiled for the same reason: a tile column would have to come
## out of the terrain layer, which is where collision comes from.
class_name EnemyMount
extends Node2D

## How far down to the deck, in tiles. The node sits at the enemy's feet and the
## post is drawn downward from there.
@export var height_tiles: float = 2.0:
	set(value):
		height_tiles = maxf(value, 0.0)
		queue_redraw()

## Cool weathered steel. Darker than the deck it stands on, so it reads as
## something in front of the backdrop rather than as part of the boardwalk.
const POST := Color(0.30, 0.31, 0.37)
const POST_EDGE := Color(0.19, 0.20, 0.25)
const COLLAR := Color(0.42, 0.44, 0.50)


func _ready() -> void:
	z_index = -1   # behind the enemy it carries
	queue_redraw()


func _draw() -> void:
	var tile := _tile_size()
	var height := height_tiles * tile
	if height <= 0.0:
		return
	var width := tile * 0.28

	# The shaft, from the enemy's feet down to the deck.
	draw_rect(Rect2(Vector2(-width * 0.5, 0.0), Vector2(width, height)), POST)
	draw_rect(Rect2(Vector2(-width * 0.5, 0.0), Vector2(maxf(width * 0.22, 2.0), height)),
		POST_EDGE)

	# A collar at the top and a foot plate at the bottom, so the post reads as
	# bolted at both ends rather than as a line someone drew.
	var collar := maxf(tile * 0.12, 3.0)
	draw_rect(Rect2(Vector2(-width * 0.85, 0.0), Vector2(width * 1.7, collar)), COLLAR)
	draw_rect(Rect2(Vector2(-width * 1.1, height - collar),
		Vector2(width * 2.2, collar)), COLLAR)


func _tile_size() -> float:
	var autoload := get_node_or_null(^"/root/Tuning")
	return autoload.player.tile_size() if autoload != null else 72.0
