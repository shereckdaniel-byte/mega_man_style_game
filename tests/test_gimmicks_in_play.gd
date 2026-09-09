## The gimmicks, built into a stage and asked whether they are actually running.
##
## **This file exists because stage 1's headline gimmick was inert for two
## milestones and every test passed.** `RisingTide` was written at M5a, is
## complete, and has nine unit tests: it rises in steps, stops at its ceiling,
## recedes when told, kills through i-frames. `running` defaults to false --
## correctly, because water that climbed from the moment the stage loaded would
## top out before the player reached the room -- and the piece nobody wrote was
## the one that turns it on. The gimmick was a blue rectangle sitting still.
##
## Every unit test calls `begin()` itself, which is the exact shape of a test
## that cannot see this: it checks that a thing works when switched on and never
## asks who switches it on. So these build the real stage, move the player
## between real rooms, and ask the built node.
extends TestCase

const STAGE_1 := "res://scenes/stages/dawn_boardwalk/dawn_boardwalk.tscn"
const SETTLE_FRAMES := 6

var stage: AuthoredStage


func is_async() -> bool:
	return true


func before_each_async() -> void:
	stage = (load(STAGE_1) as PackedScene).instantiate() as AuthoredStage
	tree.root.add_child(stage)
	for _i in SETTLE_FRAMES:
		await tree.physics_frame


func after_each_async() -> void:
	if is_instance_valid(stage):
		stage.queue_free()
	await tree.physics_frame


func _tide_room() -> int:
	var keys := stage.tides().keys()
	return int(keys[0]) if not keys.is_empty() else -1


func _enter(index: int) -> void:
	stage.room_changed.emit(stage.rooms()[index])
	await tree.physics_frame


# --- The tide ------------------------------------------------------------------

## The stage has one, and it is attached to a room rather than to the stage at
## large. Which room is the stage's business; that there is one is this file's.
func test_stage_one_places_a_tide_and_knows_which_room_it_is_in() -> void:
	assert_eq(stage.tides().size(), 1, "stage 1 has %d tides" % stage.tides().size())
	var index := _tide_room()
	assert_true(index >= 0 and index < stage.rooms().size(),
		"the tide is registered against room %d" % index)


## **The one that was missing.** Walk into the room; the water climbs.
func test_entering_the_tide_room_starts_the_water() -> void:
	var index := _tide_room()
	var water: RisingTide = stage.tides()[index]
	assert_false(water.running, "the water was already running before anyone arrived")
	var before := water.surface_row
	await _enter(index)
	assert_true(water.running, "entering the room did not start the water")
	# And it is actually moving, not merely flagged as moving.
	for _i in 90:
		await tree.physics_frame
	assert_true(water.surface_row < before,
		"the water is running and has not risen: %.2f -> %.2f"
			% [before, water.surface_row])


## Leaving sends it back down, so the room is not still flooded when the player
## comes back through it.
func test_leaving_the_tide_room_sends_the_water_back_down() -> void:
	var index := _tide_room()
	var water: RisingTide = stage.tides()[index]
	await _enter(index)
	for _i in 120:
		await tree.physics_frame
	var high := water.surface_row
	assert_true(high < water.start_row, "the water never rose")
	await _enter(maxi(index - 1, 0))
	assert_false(water.running, "leaving the room left the water running")
	for _i in 60:
		await tree.physics_frame
	assert_true(water.surface_row > high,
		"the water did not recede: %.2f -> %.2f" % [high, water.surface_row])


## **Re-entering starts from the bottom.** `room_changed` fires on a respawn as
## well as on a door, so a bare `begin()` would put a player who just drowned
## back at the checkpoint with the water already at their neck -- the soft lock
## `RisingTide` was written to make impossible rather than merely unlikely.
func test_coming_back_into_the_room_starts_the_water_from_the_bottom() -> void:
	var index := _tide_room()
	var water: RisingTide = stage.tides()[index]
	await _enter(index)
	for _i in 150:
		await tree.physics_frame
	assert_true(water.surface_row < water.start_row, "the water never rose")
	# However you got here -- a door, or dying in it -- entering the room is
	# entering the room.
	await _enter(index)
	assert_true(is_equal_approx(water.surface_row, water.start_row),
		"re-entering left the water at %.2f of %.2f"
			% [water.surface_row, water.start_row])
	assert_true(water.running, "re-entering did not restart it")


## **The water never covers the way out.** That is `RisingTide`'s whole safety
## contract and the stage is the half of it that can be wrong: the class clamps
## at whatever `ceiling_row` it is handed, and a stage that hands it the wrong
## row builds a room that cannot be escaped with nothing on screen to say why.
##
## The way out of a tide room is its ladder, not its blocks. Stage 1's staircase
## goes under -- deliberately; it is a route to the ladder rather than a refuge
## -- so checking the blocks would assert the opposite of the real rule, and an
## earlier draft of this test did exactly that.
func test_the_tide_never_covers_the_way_out_of_its_room() -> void:
	var index := _tide_room()
	var water: RisingTide = stage.tides()[index]
	var spec: Dictionary = stage.room_table()[index]
	assert_true(spec.has("shaft_up") or spec.has("shaft"),
		"the tide room has no ladder, so the only footing in it is drownable")
	var deck := float(stage.room_deck_row(index))
	# A `shaft_up` climbs a full band, so its top is ROOM_HEIGHT rows above this
	# room's deck.
	var ladder_top := deck - float(AuthoredStage.ROOM_HEIGHT)
	assert_true(ladder_top < water.ceiling_row,
		"the water tops out at row %.1f and the ladder ends at row %.1f"
			% [water.ceiling_row, ladder_top])
	# And there is genuinely dry ladder above the line, not a rung to spare.
	assert_true(water.ceiling_row - ladder_top >= 4.0,
		"only %.1f rows of ladder stay above the water"
			% (water.ceiling_row - ladder_top))
