## The sword: a committed, close-range slash.
##
## Its whole shape is risk for reward. It out-damages a buster pellet three to
## one and costs no ammo, and in exchange the player stands still inside an
## enemy's reach for the length of the swing with no way to cancel out of it.
## Take that commitment away and there is no reason to ever fire the buster.
##
## Works on the ground and in the air. The clip is a planted two-blade guard
## stance and it does read a little wrong mid-air -- an air swing really wants
## its own animation -- but a sword you cannot use while jumping is the worse
## problem by a distance, and half the things worth hitting are reached by
## jumping at them. The visual is a known compromise, recorded in SPRITES.
##
## An air swing does **not** hover. Gravity keeps running, the arc is unchanged,
## and landing mid-swing does not cut it short -- so the sword is never a way to
## hang in the air, which is what would make it a movement option rather than an
## attack.
extends State

## Frames the swing lasts. Shorter than the 25-frame clip: the tail of the
## animation is the recovery pose, and holding the player still through all of
## it makes the sword feel like it sticks.
const SWING_FRAMES := 20
## The window the blade is actually dangerous, within the swing. Damage before
## the arm has moved would let the player trade hits they visibly should not.
const ACTIVE_FROM := 5
const ACTIVE_TO := 14


var _airborne := false


func enter(_msg: Dictionary = {}) -> void:
	var player: Player = host
	_airborne = not player.is_on_floor()
	# Planted: no drifting through the swing, and the direction is whatever the
	# player was facing when they committed. In the air the existing horizontal
	# momentum is kept, because stopping it dead mid-jump would drop the player
	# out of the sky.
	if not _airborne:
		player.velocity.x = 0.0
	player.cancel_charge()
	player.begin_melee()


func exit() -> void:
	(host as Player).end_melee()


func physics_update(delta: float) -> StringName:
	var player: Player = host
	if not _airborne:
		player.velocity.x = 0.0
	player.apply_gravity(delta)

	var frames: int = player.state_machine.frames_in_state
	player.set_melee_active(frames >= ACTIVE_FROM and frames <= ACTIVE_TO)

	if frames < SWING_FRAMES:
		# Walking off a ledge mid-swing from a standing start drops you; the
		# swing does not hold you up.
		if not _airborne and not player.is_on_floor():
			return &"Fall"
		return &""
	if not player.is_on_floor():
		return &"Fall"
	return &"Idle" if player.input_direction() == 0 else &"Walk"
