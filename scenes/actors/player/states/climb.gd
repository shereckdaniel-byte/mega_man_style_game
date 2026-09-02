## On a ladder. Vertical only, and the animation advances only while moving --
## holding still on a ladder freezes the pose, as in the original.
extends State


func enter(_msg: Dictionary = {}) -> void:
	var player: Player = host
	player.velocity = Vector2.ZERO
	player.consume_jump_request()
	# Centre on the ladder so the climb does not drift.
	if not player.ladders.is_empty():
		player.global_position.x = player.ladders[0].global_position.x


func physics_update(_delta: float) -> StringName:
	var player: Player = host
	if not player.on_ladder():
		return &"Fall"

	# Jumping off a ladder drops you; it does not launch you.
	if player.jump_requested():
		player.consume_jump_request()
		return &"Fall"

	var vertical := 0
	if Input.is_action_pressed(&"move_up"):
		vertical -= 1
	if Input.is_action_pressed(&"move_down"):
		vertical += 1

	player.velocity.x = 0.0
	player.velocity.y = float(vertical) * player.tuning.px_s(player.tuning.climb_speed_pf)
	player.sprite.speed_scale = 1.0 if vertical != 0 else 0.0

	# Climbing down onto solid ground ends the climb.
	if vertical > 0 and player.is_on_floor():
		return &"Idle"
	return &""


func exit() -> void:
	(host as Player).sprite.speed_scale = 1.0
