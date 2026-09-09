## Switchgear: the boss rush, and the only stage the playthrough bot cannot
## drive.
##
## **That is why this file is longer than the other stages'.** `tools/playthrough
## .gd` walks right until it reaches the boss door and fights what is in the last
## room; Switchgear has no boss door, no last-room boss, and a route that is not
## a walk. Every other stage in the game has a bot run standing behind it saying
## "a player can get from the start to the end of this"; this one has these
## tests instead, so they have to build it for real and actually take the route.
extends TestCase

const Switchgear := preload("res://scenes/stages/switchgear/switchgear.gd")
const SCENE := "res://scenes/stages/switchgear/switchgear.tscn"

const SETTLE_FRAMES := 8

var stage: AuthoredStage


func is_async() -> bool:
	return true


func before_each_async() -> void:
	stage = (load(SCENE) as PackedScene).instantiate() as AuthoredStage
	tree.root.add_child(stage)
	for _i in SETTLE_FRAMES:
		await tree.physics_frame


func after_each_async() -> void:
	if is_instance_valid(stage):
		stage.queue_free()
	await tree.physics_frame


func _arenas() -> Array[BossArena]:
	var out: Array[BossArena] = []
	for child in stage.get_children():
		if child is BossArena:
			out.append(child as BossArena)
	return out


# --- The shape ---------------------------------------------------------------------

func test_it_knows_which_fortress_stage_it_is() -> void:
	assert_eq(stage.fortress_index(), 2)
	assert_eq(String(StageRoster.fortress_entry(2)["name"]), "Switchgear")


## **All eight, exactly once each.** A boss rush that skipped one or ran one
## twice would be an eight-fight room that is not the eight fights.
func test_every_one_of_the_eight_has_a_cell() -> void:
	var seen: Array[int] = []
	for spec in Switchgear.ROOMS:
		if spec.has("refight"):
			var index := int(spec["refight"])
			assert_false(seen.has(index), "boss %d has two cells" % index)
			seen.append(index)
	seen.sort()
	var wanted: Array[int] = []
	for i in GameState.BOSS_COUNT:
		wanted.append(i)
	assert_eq(seen, wanted, "the cells hold %s" % str(seen))


## And each cell really builds its boss, from the roster rather than from a
## second table in the stage.
func test_each_cell_builds_the_boss_the_roster_names() -> void:
	var arenas: Array[BossArena] = _arenas()
	assert_eq(arenas.size(), GameState.BOSS_COUNT,
		"%d arenas for %d bosses" % [arenas.size(), GameState.BOSS_COUNT])
	for i in GameState.BOSS_COUNT:
		var wanted: GDScript = StageRoster.boss_script(i)
		assert_not_null(wanted, "the roster has no script for boss %d" % i)
		var found := false
		for arena in arenas:
			if arena.boss_script == wanted:
				found = true
		assert_true(found,
			"no arena builds %s" % String(StageRoster.entry(i)["boss"]))


## **The arenas are unreachable on foot.** Laid out side by side they would
## share a deck, and a player who walked off one would be standing in the next
## with `Stage.room` still naming the first -- no enemies, a camera locked to a
## room they have left, and nothing to say so. That is the M6i shaft bug's shape
## and it was worth a whole stage then.
func test_no_two_cells_share_a_band() -> void:
	var bands: Array[int] = []
	for spec in Switchgear.ROOMS:
		if not spec.has("refight"):
			continue
		var band := int(spec["band"])
		assert_false(bands.has(band),
			"two cells in band %d, so their decks join" % band)
		bands.append(band)


## And the stage hangs no doors across those links, which is what
## `"exit": "teleport"` is for.
func test_the_cells_have_no_doors() -> void:
	var doors := 0
	for child in stage.get_children():
		if child is Door:
			doors += 1
	# Entry -> Approach -> Hub is two doors, and nothing after the hub is walked.
	assert_eq(doors, 2,
		"%d doors in a stage with three walkable rooms" % doors)


## A hub with a hole in it would be a hub you can fall out of while choosing.
func test_the_hub_is_flat_and_empty() -> void:
	var hub: Dictionary = Switchgear.ROOMS[int(stage.hub_room_index())]
	assert_true((hub.get("gaps", []) as Array).is_empty())
	assert_true((hub.get("blocks", []) as Array).is_empty())
	assert_true((hub.get("enemies", []) as Array).is_empty())
	# And it has a checkpoint: the player comes back to it eight times, and a
	# death should cost the cell rather than the stage.
	assert_false(is_equal_approx(float(hub["checkpoint"]),
		AuthoredStage.NO_CHECKPOINT))


## No cell has a checkpoint, for the reason no arena in the game does: it would
## let a player who died mid-fight respawn past the seal with the boss gone.
func test_no_cell_has_a_checkpoint() -> void:
	for spec in Switchgear.ROOMS:
		if not spec.has("refight"):
			continue
		assert_true(is_equal_approx(float(spec["checkpoint"]),
			AuthoredStage.NO_CHECKPOINT),
			"%s has a checkpoint inside a sealed room" % spec["name"])


# --- The pads ------------------------------------------------------------------------

func test_the_hub_has_a_pad_for_each_boss_and_one_more_for_the_way_out() -> void:
	for i in GameState.BOSS_COUNT:
		assert_not_null(stage.pad_for(i), "no pad for boss %d" % i)
	assert_not_null(stage.exit_pad())
	# Two pads on the same cell would be one pad the player can never choose.
	var cells: Array[int] = []
	for cell in Switchgear.PAD_CELLS:
		assert_false(cells.has(int(cell)), "two pads on cell %d" % int(cell))
		cells.append(int(cell))
	assert_false(cells.has(Switchgear.EXIT_CELL),
		"the exit shares a cell with a fight")


## **No two plates overlap.** They no longer need a stride's worth of clearance
## -- a pad fires on a press of up, so brushing one on the way past does nothing
## -- but two that shared floor would put the player standing in both at once
## with no way to say which they meant.
func test_no_two_plates_overlap() -> void:
	var width := TeleportPad.SIZE_TILES.x
	var cells: Array[int] = []
	for cell in Switchgear.PAD_CELLS:
		cells.append(int(cell))
	cells.append(Switchgear.EXIT_CELL)
	cells.sort()
	for i in range(1, cells.size()):
		var apart := float(cells[i] - cells[i - 1])
		assert_true(apart > width,
			"plates at %d and %d are %.0f cells apart and each is %.1f wide"
				% [cells[i - 1], cells[i], apart, width])
	# And every plate is inside the room, including its own width.
	for cell in cells:
		assert_true(float(cell) - width * 0.5 >= 0.0
				and float(cell) + width * 0.5 <= float(AuthoredStage.ROOM_WIDTH),
			"a plate at cell %d hangs out of the room" % cell)


## **The hub's checkpoint is not under a plate.** A death anywhere in the stage
## puts the player back here, and respawning inside the exit's box on the frame
## the eighth boss went down would end the stage from under them.
func test_the_checkpoint_is_clear_of_every_plate() -> void:
	var hub: Dictionary = Switchgear.ROOMS[int(stage.hub_room_index())]
	var at := float(hub["checkpoint"])
	var width := TeleportPad.SIZE_TILES.x
	var cells: Array[int] = []
	for cell in Switchgear.PAD_CELLS:
		cells.append(int(cell))
	cells.append(Switchgear.EXIT_CELL)
	for cell in cells:
		assert_true(absf(at - float(cell)) > width * 0.5 + 0.5,
			"the checkpoint at %.1f is inside the plate at %d" % [at, cell])


## The exit is dark until all eight are down. A pad that looked live and refused
## would make the room a puzzle about the pad rather than about the eight.
func test_the_exit_is_dark_until_the_eighth_is_down() -> void:
	assert_false(stage.exit_pad().live, "the exit is lit on arrival")
	for i in GameState.BOSS_COUNT - 1:
		stage._on_refight_cleared(i, &"")
		assert_false(stage.exit_pad().live,
			"the exit lit with %d of %d down" % [i + 1, GameState.BOSS_COUNT])
	stage._on_refight_cleared(GameState.BOSS_COUNT - 1, &"")
	assert_true(stage.exit_pad().live, "the exit never lit")


## And a beaten boss's plate goes dark, which is the hub's whole readout: how
## many lights are left is how many fights are left.
func test_a_beaten_cells_plate_goes_dark() -> void:
	assert_true(stage.pad_for(3).live)
	stage._on_refight_cleared(3, &"")
	assert_false(stage.pad_for(3).live, "the plate stayed lit")
	assert_true(stage.is_beaten(3))
	assert_true(stage.pad_for(4).live, "an unbeaten plate went dark too")


## **Standing on a pad is not using it.** The player arrives on the return pad
## of every cell, and a pad that fired on overlap would send them straight back
## before they had seen the room.
func test_a_pad_the_player_lands_on_does_not_fire() -> void:
	var pad: TeleportPad = stage.pad_for(0)
	var player: Player = stage.get_node(^"Player")
	pad._on_body_entered(player)
	pad.disarm_until_empty()
	assert_false(pad.is_armed())
	var fired: Array[int] = []
	pad.used.connect(func(_p: TeleportPad) -> void: fired.append(1))
	assert_false(pad.use_now(), "a disarmed pad fired")
	assert_eq(fired.size(), 0)
	# Stepping off re-arms it, so it can be used deliberately.
	pad._on_body_exited(player)
	assert_true(pad.is_armed())


## **Standing on a plate is not choosing it.** Eight in one room means walking
## across most of them to reach the one you want, and a pad that fired on
## contact would take the first one brushed -- the room would ask a question and
## then answer it for you.
func test_standing_on_a_plate_does_nothing_until_you_ask() -> void:
	var pad: TeleportPad = stage.pad_for(4)
	var fired: Array[int] = []
	pad.used.connect(func(_p: TeleportPad) -> void: fired.append(1))
	pad._on_body_entered(stage.get_node(^"Player"))
	assert_true(pad.is_occupied())
	assert_eq(fired.size(), 0, "walking onto a plate used it")
	assert_true(pad.use_now(), "asking did not use it")
	assert_eq(fired.size(), 1)


## And asking from off the plate does nothing, so the press is about where you
## are standing rather than about the button.
func test_asking_from_off_a_plate_does_nothing() -> void:
	assert_false(stage.pad_for(1).use_now())


## A dark pad does nothing at all, armed or not.
func test_a_dark_pad_never_fires() -> void:
	var pad: TeleportPad = stage.exit_pad()
	var fired: Array[int] = []
	pad.used.connect(func(_p: TeleportPad) -> void: fired.append(1))
	pad._on_body_entered(stage.get_node(^"Player"))
	assert_false(pad.use_now(), "a dark pad fired")
	assert_eq(fired.size(), 0)


# --- The route ------------------------------------------------------------------------

## **The route the bot cannot take, taken.** Onto a pad, into the cell, back to
## the hub, and standing on the plate you left from.
func test_a_pad_puts_the_player_in_its_cell_and_the_return_brings_them_back() -> void:
	var player: Player = stage.get_node(^"Player")
	var hub: Room = stage.rooms()[int(stage.hub_room_index())]

	stage._on_pad_used(stage.pad_for(5))
	await tree.physics_frame
	var cell_index: int = stage.cell_room_index(5)
	assert_eq(stage.room, stage.rooms()[cell_index],
		"the pad left the player in %s" % stage.room.name)
	assert_true(stage.rooms()[cell_index].bounds_tiles.has_point(
			Vector2i(int(player.global_position.x / stage.tile_size()),
				int(player.global_position.y / stage.tile_size()))),
		"the player is outside the cell they were sent to")

	stage._on_return_used(stage._return_pads[5])
	await tree.physics_frame
	assert_eq(stage.room, hub, "the return left the player in %s" % stage.room.name)
	# On the plate they left from, so the hub is a place they are in rather than
	# a place they are put.
	var expected: float = float(stage.room_origin(int(stage.hub_room_index()))
		+ int(Switchgear.PAD_CELLS[5])) * stage.tile_size()
	assert_almost_eq(player.global_position.x, expected, stage.tile_size(),
		"came back to %.0f, left from %.0f" % [player.global_position.x, expected])


## A beaten cell's plate does not send you to look at an empty room.
func test_a_beaten_plate_does_not_teleport() -> void:
	stage._on_refight_cleared(2, &"")
	var was: Room = stage.room
	stage._on_pad_used(stage.pad_for(2))
	await tree.physics_frame
	assert_eq(stage.room, was, "a beaten plate moved the player")


## And the exit refuses while anything is still standing, so the stage cannot be
## finished early.
func test_the_exit_refuses_until_all_eight_are_down() -> void:
	var exited: Array[int] = []
	stage.stage_cleared.connect(func() -> void: exited.append(1))
	stage._on_exit_used(stage.exit_pad())
	await tree.physics_frame
	assert_eq(exited.size(), 0, "the stage ended with eight bosses standing")


# --- The difficulty is the bar, not the fights -----------------------------------------

## **The refights are the fights as shipped.** Making each of them harder is the
## obvious thing and it is the wrong one: the boss rush is a resource problem,
## and it is the only place in the game where the question is what you have left
## rather than what you can do. It stops being that question the moment the
## fights themselves become the difficulty.
func test_no_refight_is_sped_up() -> void:
	for arena in _arenas():
		var boss: Boss = (arena.boss_script as GDScript).new() as Boss
		tree.root.add_child(boss)
		await tree.physics_frame
		assert_true(is_equal_approx(boss.aggression, 1.0),
			"%s comes back at %.2f" % [boss.display_name, boss.aggression])
		boss.queue_free()
		await tree.physics_frame
