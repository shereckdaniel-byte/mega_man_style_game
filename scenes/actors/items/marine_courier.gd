## Delivers a Rush Marine: a ride in submarine mode, which does nothing at all
## until it is in water. That refusal is deliberate and visible -- see
## `RushRide`.
class_name MarineCourier
extends ItemCourier

const RIDE := preload("res://scenes/actors/items/rush_ride.gd")


func delivers() -> GDScript:
	return RIDE


func _configure_item(item: Node2D) -> void:
	var ride := item as RushRide
	if ride == null:
		return
	ride.mode = RushRide.Mode.SUBMARINE
	ride.set_heading(direction())
