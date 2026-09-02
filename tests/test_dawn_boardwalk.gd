## Stage 1's authored layout.
##
## These are level-design assertions, not engine ones. Every failure mode here
## produces a stage that loads, renders and plays right up until it cannot be
## finished — which is the worst kind, because it needs a full playthrough to
## find. Two of them were found exactly that way and are fixed:
##
## * a block three tiles above the deck, which the jump cannot clear, in a
##   corridor with no way round it;
## * gaps three cells wide, which a full jump clears only with perfect timing.
extends TestCase

const STAGE := preload("res://scenes/stages/dawn_boardwalk/dawn_boardwalk.gd")


# --- Authoring limits ---------------------------------------------------------

## The jump reaches 2.89 tiles, and test_player_movement asserts 2 is clearable
## and 3 is not. A three-tile step in a corridor is therefore a wall.
func test_no_block_is_taller_than_the_player_can_climb() -> void:
	for spec in STAGE.ROOMS:
		for block in spec["blocks"]:
			assert_true(int(block[1]) <= STAGE.MAX_STEP_TILES,
				"%s: block at cell %d rises %d tiles above the deck, and the jump clears %d"
					% [spec["name"], int(block[0]), int(block[1]), STAGE.MAX_STEP_TILES])


## A full jump covers about 3.4 tiles horizontally at walk speed, so three cells
## is frame-perfect and two is comfortable.
func test_no_gap_is_wider_than_the_player_can_jump() -> void:
	for spec in STAGE.ROOMS:
		for gap in spec["gaps"]:
			var width := int(gap[1]) - int(gap[0])
			assert_true(width <= STAGE.MAX_GAP_TILES,
				"%s: gap at cell %d is %d cells wide, and a comfortable jump crosses %d"
					% [spec["name"], int(gap[0]), width, STAGE.MAX_GAP_TILES])


# --- Checkpoints --------------------------------------------------------------

## A checkpoint over a gap respawns the player into the pit, then again, until
## the life counter empties. The art preview shipped one of these once.
func test_every_checkpoint_stands_on_solid_deck() -> void:
	for spec in STAGE.ROOMS:
		var cell := int(spec["checkpoint"])
		for gap in spec["gaps"]:
			assert_false(cell >= int(gap[0]) and cell < int(gap[1]),
				"%s: checkpoint at cell %d is over the gap at %d-%d"
					% [spec["name"], cell, int(gap[0]), int(gap[1])])


func test_every_room_has_a_checkpoint() -> void:
	for spec in STAGE.ROOMS:
		assert_true(spec.has("checkpoint"), "%s has a checkpoint" % spec["name"])


# --- Shape --------------------------------------------------------------------

## Rooms are laid end to end, so a gap or block at the very edge would straddle
## a door and be half in each room.
func test_nothing_is_authored_across_a_room_boundary() -> void:
	for spec in STAGE.ROOMS:
		for gap in spec["gaps"]:
			assert_between(float(gap[0]), 1.0, float(STAGE.ROOM_WIDTH - 2),
				"%s: gap starts inside the room" % spec["name"])
			assert_between(float(gap[1]), 1.0, float(STAGE.ROOM_WIDTH - 1),
				"%s: gap ends inside the room" % spec["name"])
		for block in spec["blocks"]:
			assert_between(float(int(block[0]) + int(block[2])), 1.0,
				float(STAGE.ROOM_WIDTH - 1),
				"%s: block ends inside the room" % spec["name"])


## Every room must be at least a screen wide, or the camera's limits cannot be
## satisfied and it pins to the left edge.
func test_rooms_are_at_least_one_screen_wide() -> void:
	var tile := PlayerTuning.new().tile_size()
	var view := float(ProjectSettings.get_setting("display/window/size/viewport_width"))
	assert_true(float(STAGE.ROOM_WIDTH) * tile >= view - tile,
		"a room is %.0f px wide against a %.0f px screen"
			% [float(STAGE.ROOM_WIDTH) * tile, view])


## The stage has to end somewhere a boss door can go.
func test_the_last_room_is_clear_for_the_boss_door() -> void:
	var last: Dictionary = STAGE.ROOMS[STAGE.ROOMS.size() - 1]
	assert_true(last["gaps"].is_empty(), "no gaps in the run-up to a boss")
	assert_true(last["enemies"].is_empty(), "and nothing fighting you in it")


## Enemy art has to exist, or a marker silently places nothing and the room is
## empty for a reason no one can see.
func test_every_authored_enemy_has_art() -> void:
	for spec in STAGE.ROOMS:
		for entry in spec["enemies"]:
			var path := "res://resources/sprite_frames/%s.tres" % entry[1]
			assert_true(ResourceLoader.exists(path),
				"%s: %s has no SpriteFrames at %s" % [spec["name"], entry[1], path])
