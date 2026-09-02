## Puts the stage 1 backdrop behind the M1 tuning room, so the art can be judged
## against the player at the size it will actually be seen.
##
## This is the cheap answer to the open question in SPRITES.md section 8: pixel
## backgrounds behind a smooth anti-aliased character is a deliberate mixed
## style, and the only way to settle it is to look at the two together before
## generating seven more stages of it.
##
## Development scene: nothing in the game routes here.
extends Node2D

const BACKGROUND := preload("res://scenes/stages/dawn_boardwalk/parallax_background.gd")
const TEST_ROOM := preload("res://scenes/stages/test_room/test_room.tscn")


func _ready() -> void:
	var background := Node2D.new()
	background.name = "DawnBoardwalkBackground"
	background.set_script(BACKGROUND)
	add_child(background)

	add_child(TEST_ROOM.instantiate())
