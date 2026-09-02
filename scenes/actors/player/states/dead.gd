## Frozen, waiting on the respawn sequence. Explosion and respawn land in M3.
extends State


func enter(_msg: Dictionary = {}) -> void:
	var player: Player = host
	player.velocity = Vector2.ZERO


func physics_update(_delta: float) -> StringName:
	(host as Player).velocity = Vector2.ZERO
	return &""
