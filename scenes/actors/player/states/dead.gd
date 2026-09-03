## Dead: frozen, burst, then the respawn.
##
## The sequence is counted in physics frames rather than run off a Timer so it
## advances on the same tick as everything else and a headless test can step it.
##
## The state owns the wait and the burst; it does not own *where* the player
## comes back, which is GameState's checkpoint. A stage that never set one falls
## back to where the player entered it.
extends State

## Frames the burst is left on screen before the player returns. The original
## holds on the explosion for about a second.
const RESPAWN_DELAY_FRAMES := 72

var _done := false


func enter(_msg: Dictionary = {}) -> void:
	var player: Player = host
	player.velocity = Vector2.ZERO
	# The character is gone -- the burst stands in for it. Hidden rather than
	# freed because the same node comes back at the checkpoint.
	player.sprite.visible = false
	_done = false
	var level := player.get_parent()
	if level != null:
		DeathExplosion.burst(level, player.global_position)


func exit() -> void:
	(host as Player).sprite.visible = true


func physics_update(_delta: float) -> StringName:
	var player: Player = host
	player.velocity = Vector2.ZERO
	if _done:
		return &""
	var machine: StateMachine = player.state_machine
	if machine.frames_in_state < RESPAWN_DELAY_FRAMES:
		return &""
	_done = true
	player.finish_death()
	return &""
