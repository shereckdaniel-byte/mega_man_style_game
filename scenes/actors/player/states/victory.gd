## The pose after a boss falls.
##
## Pure punctuation: no input, no damage, nothing to do but watch. That is the
## point of it -- the fight has been a minute of reacting, and the beat where
## nothing is asked of the player is what makes the win land.
##
## Ends on its own rather than on a button, because a celebration you can skip
## before it plays is a celebration most players never see.
extends State

## Frames to hold if the clip has no natural end. The `victory` animation does
## not loop, so normally the animation decides and this is the backstop for art
## that has not been made yet -- the same reason the teleport state has one.
const HOLD_FRAMES := 110


func enter(_msg: Dictionary = {}) -> void:
	var player: Player = host
	player.velocity = Vector2.ZERO
	player.cancel_charge()


func physics_update(delta: float) -> StringName:
	var player: Player = host
	player.velocity.x = 0.0
	player.apply_gravity(delta)

	var frames: SpriteFrames = player.sprite.sprite_frames
	var has_clip: bool = frames != null and frames.has_animation(anim_name)
	if not has_clip:
		# No art for it: hold briefly so the sequence still has a beat, then move
		# on rather than stalling on an animation that will never finish.
		if player.state_machine.frames_in_state >= HOLD_FRAMES:
			return &"TeleportOut"
		return &""

	if player.sprite.is_playing() \
			and player.state_machine.frames_in_state < HOLD_FRAMES:
		return &""
	return &"TeleportOut"
