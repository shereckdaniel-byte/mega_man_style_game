## The beam-down at stage start and beam-up at stage clear.
##
## One of only two places where the animation owns the duration rather than the
## controller -- everything else drives timing from the state machine.
extends State


func enter(_msg: Dictionary = {}) -> void:
	var player: Player = host
	player.velocity = Vector2.ZERO


func physics_update(_delta: float) -> StringName:
	var player: Player = host
	player.velocity = Vector2.ZERO
	var frames: SpriteFrames = player.sprite.sprite_frames
	if frames == null or not frames.has_animation(anim_name):
		# The art does not exist yet (SPRITES.md section 4); do not stall the
		# game waiting for an animation that will never finish.
		return &"Idle"
	if not player.sprite.is_playing():
		return &"Idle"
	return &""
