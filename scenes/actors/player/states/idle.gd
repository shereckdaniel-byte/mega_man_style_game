## Standing still on the ground.
extends State


func enter(_msg: Dictionary = {}) -> void:
	host.velocity.x = 0.0


func physics_update(_delta: float) -> StringName:
	var player: Player = host
	if not player.is_on_floor():
		return &"Fall"
	if player.slide_requested() and player.has_headroom():
		return &"Slide"
	# After the slide check: down+jump is a slide, and a melee bound to a third
	# button must not shadow it.
	if player.melee_requested() and player.can_melee():
		return &"Attack"
	if player.jump_requested() and player.can_jump_from_ground():
		return &"Jump"
	if player.on_ladder() and Input.is_action_pressed(&"move_up"):
		return &"Climb"
	if player.input_direction() != 0:
		return &"Walk"
	player.velocity.x = 0.0
	return &""
