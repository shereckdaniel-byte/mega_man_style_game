## Delivers a Rush Coil. See `ItemCourier` for why a utility weapon fires a
## courier rather than the item itself.
class_name CoilCourier
extends ItemCourier

const COIL := preload("res://scenes/actors/items/rush_coil.gd")


func delivers() -> GDScript:
	return COIL
