## Where an entity takes damage. Pairs with Hitbox.
##
## Deliberately passive: it monitors nothing and only ever gets called *by* a
## Hitbox that found it. One side of the pair has to do the looking, and making
## it the attacker means a resting enemy costs no overlap checks.
class_name Hurtbox
extends Area2D

## Fires whether or not the hit did damage; `taken` is 0 when it was refused.
signal took_damage(info: DamageInfo, taken: int)

## The Health this forwards to. Left empty, it looks for a sibling or a child of
## the owner, which is the usual layout and saves wiring it up in every scene.
@export var health_path: NodePath

var _health: Health


func _ready() -> void:
	monitoring = false
	monitorable = true
	_health = _resolve_health()
	if _health == null:
		push_error("Hurtbox at %s found no Health" % get_path())


## Called by Hitbox. Returns the damage actually taken.
func receive(info: DamageInfo) -> int:
	if _health == null:
		return 0
	var taken := _health.take(info)
	took_damage.emit(info, taken)
	return taken


func health() -> Health:
	return _health


func _resolve_health() -> Health:
	if not health_path.is_empty():
		return get_node_or_null(health_path) as Health
	var parent := get_parent()
	if parent != null:
		for sibling in parent.get_children():
			if sibling is Health:
				return sibling
	return null
