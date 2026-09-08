## The panel: its cycle, and the two properties the gimmick stands on.
##
## The cycle is checked as arithmetic rather than by standing on one for three
## seconds -- `phase_at` and `local_frame` are pure, which is what makes that
## possible and is why they are written that way. It is the same arrangement
## `tests/test_crusher_press.gd` uses on the press, and for the same reason: a
## timing bug found by watching is a timing bug found once.
##
## What is checked against the **real** numbers rather than against the comments:
##
##   * `BEAT_FRAMES` really is at least a jump's airtime, measured off
##     `PlayerTuning` by integrating the arc. If the jump is ever retuned this
##     fails here rather than shipping a path whose panels leave before the
##     player lands on them.
##   * a path is never empty and consecutive panels always overlap, walked frame
##     by frame across a whole cycle rather than reasoned about.
##
## Breakers' press shipped a comment whose arithmetic was wrong in exactly the
## direction that made the gimmick ask for nothing. This is the same class of
## number in the same position.
extends TestCase

const PanelBlock := preload("res://scenes/level/phase_block.gd")

var root: Node2D


func is_async() -> bool:
	return true


func before_each_async() -> void:
	root = Node2D.new()
	tree.root.add_child(root)
	await tree.physics_frame


func after_each_async() -> void:
	if is_instance_valid(root):
		root.queue_free()
	await tree.physics_frame


# --- The numbers ------------------------------------------------------------------

## **A beat is one jump**, and this is the half of that sentence that can go
## stale on its own.
func test_a_beat_is_at_least_a_jump() -> void:
	var tuning := PlayerTuning.new()
	var airtime := _jump_airtime(tuning)
	assert_true(float(PanelBlock.BEAT_FRAMES) >= airtime,
		"a beat is %d frames and a jump is airborne %.1f: a panel path could not be run"
			% [PanelBlock.BEAT_FRAMES, airtime])
	# And not *much* more than one, or the path stops being a rhythm and becomes
	# a queue. Half a jump of slack on top is the design.
	assert_true(float(PanelBlock.BEAT_FRAMES) <= airtime * 1.5,
		"a beat is %d frames against a %.1f-frame jump, which is waiting rather than crossing"
			% [PanelBlock.BEAT_FRAMES, airtime])


## The three durations have to tile the cycle exactly, or a set drifts out of
## step with itself over a long run and the drift is invisible until the room is
## uncrossable.
func test_solid_warning_and_gone_add_up_to_the_cycle() -> void:
	for length in range(3, 8):
		var panel := _panel(0, length)
		var untriggered := PanelBlock.SOLID_FRAMES - PanelBlock.WARN_FRAMES
		assert_eq(untriggered + panel.warn_frames + panel.respawn_frames,
			panel.cycle_frames(),
			"a %d-panel set's phases do not tile its cycle" % length)


## Exactly `SOLID_BEATS` panels stand at any moment. This is the grammar's whole
## claim -- the one you are on and the one you are going to, and nothing else.
func test_exactly_two_panels_of_a_path_are_solid_at_any_time() -> void:
	for length in range(3, 8):
		var cycle := length * PanelBlock.BEAT_FRAMES
		for frame in cycle:
			var standing := 0
			for index in length:
				if PanelBlock.is_solid_at(frame, index, length):
					standing += 1
			assert_eq(standing, PanelBlock.SOLID_BEATS,
				"%d of %d panels stand at frame %d of a %d-panel set"
					% [standing, length, frame, length])


## And they are always **adjacent**, which is the part that makes a path
## crossable rather than merely non-empty. Two panels standing at opposite ends
## of a set is a route with a hole in it.
func test_the_two_that_stand_are_always_next_to_each_other() -> void:
	for length in range(3, 8):
		var cycle := length * PanelBlock.BEAT_FRAMES
		for frame in cycle:
			var standing: Array[int] = []
			for index in length:
				if PanelBlock.is_solid_at(frame, index, length):
					standing.append(index)
			assert_eq(standing.size(), 2, "frame %d" % frame)
			var apart := posmod(standing[1] - standing[0], length)
			assert_true(apart == 1 or apart == length - 1,
				"panels %d and %d stand together at frame %d of %d, which is not a step"
					% [standing[0], standing[1], frame, length])


## **Why three is the minimum**, stated as a test rather than as a comment: with
## two panels the solid windows cover the whole cycle and the set is a permanent
## staircase that the table calls a disappearing one.
func test_a_two_panel_set_would_never_disappear() -> void:
	for frame in 2 * PanelBlock.BEAT_FRAMES:
		assert_true(PanelBlock.is_solid_at(frame, 0, 2) and PanelBlock.is_solid_at(frame, 1, 2),
			"a two-panel set has a gap at frame %d, so the minimum could be relaxed"
				% frame)


# --- The live node ----------------------------------------------------------------

## A panel is in the phase its beat says it is in **on the frame it is built**,
## not after a cycle of settling. Without the alignment every panel of a set
## starts solid together and the first path a player meets is the one that
## behaves differently from all the others.
func test_a_panel_starts_in_the_phase_its_beat_asks_for() -> void:
	var length := 4
	for index in length:
		var panel := _panel(index, length)
		assert_eq(panel.phase, PanelBlock.phase_at(0, index, length),
			"panel %d of %d starts in the wrong phase" % [index, length])
	# Beat 0 is the one standing; beat 2 is the far side of the cycle and is not.
	assert_true(_panel(0, length).is_solid(), "the first panel is not standing")
	assert_false(_panel(2, length).is_solid(), "the third panel is standing early")


## It runs on its clock and not on the player's foot. A lid under a panel would
## mean the sequence depended on where the player had been, which is the one
## thing a fixed cycle is for.
func test_a_panel_has_no_lid() -> void:
	var panel := _panel(0, 4)
	assert_false(panel.triggers_on_contact(),
		"a panel that waits to be stood on is not on a cycle")
	assert_true(panel.get_node_or_null(^"Lid") == null,
		"a panel built a contact sensor it must not have")


## **The mount is always drawn**, which is the fairness bound: the route is
## legible before it is committed to. `CrumblingBlock` hides itself when it goes
## and this must not, so the check is that visibility never says whether a panel
## is standing -- `is_solid()` does.
func test_a_gone_panel_is_still_on_screen() -> void:
	var panel := _panel(2, 4)
	assert_false(panel.is_solid(), "the panel under test is standing")
	assert_true(panel.visible,
		"a gone panel hid itself, so its mount is not there to be read")


## Solid-frames-left has to fall to zero exactly as the panel goes, because it
## is what the bot commits on.
func test_solid_frames_left_runs_out_with_the_panel() -> void:
	var panel := _panel(0, 4)
	assert_eq(panel.solid_frames_left(), PanelBlock.SOLID_FRAMES)
	var seen_zero := false
	for _frame in PanelBlock.SOLID_FRAMES + 4:
		await tree.physics_frame
		if not panel.is_solid():
			seen_zero = true
			assert_eq(panel.solid_frames_left(), 0,
				"a panel that has gone still reports time left")
			break
		assert_true(panel.solid_frames_left() > 0,
			"a standing panel reports no time left")
	assert_true(seen_zero, "the panel never went")


func test_the_cycle_is_one_beat_per_panel() -> void:
	for length in range(3, 8):
		assert_eq(_panel(0, length).cycle_frames(), length * PanelBlock.BEAT_FRAMES,
			"a %d-panel set's cycle is not %d beats" % [length, length])


# --- Helpers ---------------------------------------------------------------------

func _panel(index: int, length: int) -> PhaseBlock:
	var panel := PanelBlock.new() as PhaseBlock
	panel.beat_index = index
	panel.path_length = length
	root.add_child(panel)
	return panel


## Frames a full jump spends off the ground, integrated the way the engine does
## it (`v += g` then `y += v`) rather than from v/g. The gap between the two is
## the same one `PlayerTuning.jump_apex_px` exists to keep visible.
func _jump_airtime(tuning: PlayerTuning) -> float:
	var v := -tuning.jump_velocity_pf
	var y := 0.0
	for frame in range(1, 400):
		v = minf(v + tuning.gravity_pf, tuning.terminal_velocity_pf)
		y += v
		if v > 0.0 and y >= 0.0:
			return float(frame)
	return 0.0
