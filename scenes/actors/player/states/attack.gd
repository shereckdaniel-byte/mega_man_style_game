## The sword: a committed, close-range slash.
##
## Its whole shape is risk for reward. It out-damages a buster pellet three to
## one and costs no ammo, and in exchange the player stands still inside an
## enemy's reach for the length of the swing with no way to cancel out of it.
## Take that commitment away and there is no reason to ever fire the buster.
##
## Grounded only, for now. The clip is a planted two-blade lunge and reads wrong
## in mid-air, and an air slash would want its own animation and its own arc.
## Documented in docs/PLAN.md rather than left to be discovered.
extends State

## Frames the swing lasts. Shorter than the 25-frame clip: the tail of the
## animation is the recovery pose, and holding the player still through all of
## it makes the sword feel like it sticks.
const SWING_FRAMES := 20
## The window the blade is actually dangerous, within the swing. Damage before
## the arm has moved would let the player trade hits they visibly should not.
const ACTIVE_FROM := 5
const ACTIVE_TO := 14


func enter(_msg: Dictionary = {}) -> void:
	var player: Player = host
	# Planted: no drifting through the swing, and the direction is whatever the
	# player was facing when they committed.
	player.velocity.x = 0.0
	player.cancel_charge()
	player.begin_melee()


func exit() -> void:
	(host as Player).end_melee()


func physics_update(delta: float) -> StringName:
	var player: Player = host
	player.velocity.x = 0.0
	player.apply_gravity(delta)

	var frames: int = player.state_machine.frames_in_state
	player.set_melee_active(frames >= ACTIVE_FROM and frames <= ACTIVE_TO)

	# Walking off a ledge mid-swing drops you; the swing does not hold you up.
	if not player.is_on_floor():
		return &"Fall"
	if frames < SWING_FRAMES:
		return &""
	return &"Idle" if player.input_direction() == 0 else &"Walk"
