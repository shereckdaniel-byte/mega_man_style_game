## Moving along the ground. Instant-on, instant-off -- there is no acceleration
## and no friction in Mega Man.
extends State


func physics_update(_delta: float) -> StringName:
	var player: Player = host
	if not player.is_on_floor():
		return &"Fall"
	if player.slide_requested() and player.has_headroom():
		return &"Slide"
	if player.jump_requested() and player.can_jump_from_ground():
		return &"Jump"
	if player.input_direction() == 0:
		return &"Idle"
	player.apply_walk()
	return &""
