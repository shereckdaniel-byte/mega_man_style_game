## Delivers a Rush Jet: a ride in flight mode, set off the way the player was
## looking.
class_name JetCourier
extends ItemCourier

const RIDE := preload("res://scenes/actors/items/rush_ride.gd")


func delivers() -> GDScript:
	return RIDE


func _configure_item(item: Node2D) -> void:
	var ride := item as RushRide
	if ride == null:
		return
	ride.mode = RushRide.Mode.FLIGHT
	ride.set_heading(direction())
