## In-game HUD: the player's energy bar, and the slot the weapon bar will take
## in M5.
##
## A CanvasLayer so it does not scroll with the room, and so a stage only has to
## add it and hand it the player.
class_name Hud
extends CanvasLayer

## Inset from the top-left corner, in NES pixels.
const MARGIN_NES := Vector2(12.0, 12.0)

var energy: EnergyBar


func _ready() -> void:
	layer = 10
	var scale_factor := 4.5
	var autoload := get_node_or_null(^"/root/Tuning")
	if autoload != null:
		scale_factor = autoload.player.world_scale

	energy = EnergyBar.new()
	energy.name = "PlayerEnergy"
	energy.position = MARGIN_NES * scale_factor
	add_child(energy)


## Points the HUD at a player. Kept separate from _ready so a stage can build
## the HUD before or after the player exists.
func track(player: Player) -> void:
	energy.track(player.health)
	# A respawn refills the bar off-screen; animating it back up would run the
	# refill while the player is already standing there.
	player.respawned.connect(func() -> void: energy.snap_to(player.health.current))
