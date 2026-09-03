## Substation's darkness, and the three promises that keep it fair.
##
## A gimmick that removes information can always be made unfair, and the unfair
## version is the easy one to build. `DarkRoom`'s docstring states the rules that
## stop it; this file is what makes them rules rather than intentions.
extends TestCase

const DARK_ROOM := preload("res://scenes/level/dark_room.gd")

var dark: DarkRoom


func is_async() -> bool:
	return true


func before_each_async() -> void:
	dark = DARK_ROOM.new()
	tree.root.add_child(dark)
	await tree.physics_frame


func after_each_async() -> void:
	if is_instance_valid(dark):
		dark.queue_free()
	await tree.physics_frame


func test_it_starts_clear() -> void:
	assert_false(dark.is_active())
	assert_almost_eq(dark.darkness(), 0.0, 0.001)


func test_entering_a_dark_room_dims_it() -> void:
	dark.set_active(true)
	await _frames(dark.transition_frames + 4)
	assert_true(dark.darkness() > 0.5, "the lights did not go out")


func test_leaving_a_dark_room_clears_it() -> void:
	dark.set_active(true)
	await _frames(dark.transition_frames + 4)
	dark.set_active(false)
	await _frames(dark.transition_frames + 4)
	assert_almost_eq(dark.darkness(), 0.0, 0.001, "the darkness followed the player out")


## **Promise one: never fully black.** The floor line, the player and anything
## moving stay readable as silhouettes at every point in the cycle. Checked over
## two whole periods rather than at a sampled moment, because the interesting
## value is the peak and the peak is one frame wide.
func test_it_is_never_darker_than_the_cap() -> void:
	dark.set_active(true)
	var peak := 0.0
	for i in dark.period_frames * 2 + dark.transition_frames:
		await tree.physics_frame
		peak = maxf(peak, dark.darkness())
	assert_true(peak <= DARK_ROOM.MAX_DARKNESS + 0.001,
		"darkness peaked at %.3f, over the %.3f cap" % [peak, DARK_ROOM.MAX_DARKNESS])
	# And it does get properly dark -- a cap nothing approaches is not a gimmick.
	assert_true(peak > 0.6, "it never actually got dark (%.3f)" % peak)


## **Promise two: the flash is a rhythm, not a coin flip.** A player can move on
## it only if it is the same every time.
func test_the_flash_is_on_a_fixed_period() -> void:
	dark.set_active(true)
	var flashes: Array[int] = []
	dark.flashed.connect(func() -> void: flashes.append(dark.elapsed_frames()))
	for i in dark.period_frames * 3:
		await tree.physics_frame
	assert_true(flashes.size() >= 2, "expected at least two flashes, got %d" % flashes.size())
	for i in range(1, flashes.size()):
		assert_eq(flashes[i] - flashes[i - 1], dark.period_frames,
			"the flashes are not evenly spaced")


func test_the_room_is_lit_during_a_flash() -> void:
	dark.set_active(true)
	await _frames(dark.transition_frames + 4)
	# Walk to the start of the next cycle and into the flash's hold.
	var wait := dark.period_frames - dark.cycle_frame() + dark.flash_rise_frames + 1
	await _frames(wait)
	assert_true(dark.is_flashing(), "not flashing when the cycle says it should be")
	assert_true(dark.darkness() < 0.2,
		"the flash only reached %.3f -- it is meant to light the room" % dark.darkness())


## Entering restarts the cycle, so the room lights up on arrival and then goes
## dark -- the same order every time, rather than dropping the player into
## whatever phase the last room happened to be in.
func test_entering_restarts_the_cycle() -> void:
	dark.set_active(true)
	await _frames(80)
	dark.set_active(false)
	await _frames(4)
	dark.set_active(true)
	await tree.physics_frame
	assert_true(dark.cycle_frame() <= 2,
		"the cycle carried over from the last room (at %d)" % dark.cycle_frame())


## **Promise three: it is purely visual.** Nothing here is a body, an area or a
## hitbox, so nothing in a dark room can be killed by the dark.
func test_it_cannot_touch_anything() -> void:
	assert_true(dark is CanvasLayer, "a CanvasLayer has no place in the physics world")
	for child in dark.get_children():
		assert_false(child is CollisionObject2D,
			"%s is a collision object -- the darkness must not be able to hit anyone"
				% child.name)
		assert_false(child is Area2D, "%s is an Area2D" % child.name)


## It sits under the HUD. Being unable to see the level is the gimmick; being
## unable to read your own energy bar is an interface bug wearing its clothes.
func test_it_dims_the_level_and_not_the_hud() -> void:
	var hud := preload("res://scenes/ui/hud.gd").new()
	tree.root.add_child(hud)
	await tree.physics_frame
	assert_true(dark.layer < hud.layer,
		"the darkness (layer %d) is over the HUD (layer %d)" % [dark.layer, hud.layer])
	assert_true(dark.layer > 0, "the darkness must be over the level")
	hud.queue_free()


func _frames(count: int) -> void:
	for i in count:
		await tree.physics_frame
