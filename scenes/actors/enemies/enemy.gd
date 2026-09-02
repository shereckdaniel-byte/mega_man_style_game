## Base class for every enemy.
##
## Deliberately thin. An enemy is a body with a Health, a Hurtbox the player's
## shots can find, and a contact Hitbox that hurts the player — the behaviour
## that makes it a walker or a turret is a subclass overriding `behave()`.
##
## Everything shared lives here because it is the same for all six archetypes:
## the damage table lookup, the death burst, the contact damage tick, and the
## fact that a dead enemy stops behaving immediately rather than on the next
## frame.
class_name Enemy
extends CharacterBody2D

signal died(enemy: Enemy)

## Contact damage in the original is per-enemy and small; the player's 90 i-frames
## are what stop it draining the bar. 2 of 28 is a typical NES touch.
@export var contact_damage: int = 2
@export var max_hp: int = 3
@export var damage_table: DamageTable
## Enemies drift with gravity unless they fly. Flyers set this false.
@export var affected_by_gravity: bool = true
## Bosses, mini-bosses and gimmick platforms opt out of despawning
## (ARCHITECTURE section 5.5).
@export var persistent: bool = false

var health: Health
var hurtbox: Hurtbox
var contact: Hitbox
var tuning: PlayerTuning
## Set by the SpawnMarker that created this enemy, so the marker can be re-armed
## when the enemy is freed rather than leaving a hole in the room.
var spawn_marker: Node = null

var _dead := false


func _ready() -> void:
	var autoload := get_node_or_null(^"/root/Tuning")
	tuning = autoload.player if autoload != null else PlayerTuning.new()

	collision_layer = Layers.bit(Layers.ENEMY_BODY)
	collision_mask = Layers.mask([Layers.WORLD, Layers.PLATFORM])

	_build_health()
	_build_hurtbox()
	_build_contact()
	setup()


## Subclass hook for one-time setup, after the shared components exist.
func setup() -> void:
	pass


## Subclass hook: one frame of behaviour. Not called once dead.
func behave(_delta: float) -> void:
	pass


func _physics_process(delta: float) -> void:
	if _dead:
		return
	health.tick()
	contact.tick()
	if affected_by_gravity:
		velocity.y = minf(
			velocity.y + tuning.px_s2(tuning.gravity_pf) * delta,
			tuning.px_s(tuning.terminal_velocity_pf))
	behave(delta)
	move_and_slide()


func is_dead() -> bool:
	return _dead


## Frees the enemy without the death burst or the drop — the off-screen despawn,
## which is not a kill and must not count as one.
func despawn() -> void:
	if spawn_marker != null and is_instance_valid(spawn_marker):
		spawn_marker.rearm()
	queue_free()


func _on_died(_info: DamageInfo) -> void:
	if _dead:
		return
	_dead = true
	# The burst is parented to the level, not to the enemy: queue_free() takes
	# the enemy's children with it and the explosion would vanish on the frame
	# it was created.
	var level := get_parent()
	if level != null:
		DeathExplosion.burst(level, global_position)
	# A killed enemy does NOT re-arm its marker: re-arming on death would let a
	# player farm one enemy by standing still, where the original requires
	# scrolling it off screen and back. The marker has to be TOLD, because it
	# cannot work this out by looking -- on Godot 4.7 a freed reference compares
	# equal to null, so a corpse and an empty slot look identical from outside.
	if spawn_marker != null and is_instance_valid(spawn_marker) \
			and spawn_marker.has_method("mark_spent"):
		spawn_marker.mark_spent()
	died.emit(self)
	queue_free()


func _build_health() -> void:
	health = Health.new()
	health.name = "Health"
	health.max_hp = max_hp
	health.current = max_hp
	health.damage_table = damage_table
	add_child(health)
	health.died.connect(_on_died)


func _build_hurtbox() -> void:
	hurtbox = Hurtbox.new()
	hurtbox.name = "Hurtbox"
	hurtbox.collision_layer = Layers.bit(Layers.ENEMY_HURTBOX)
	hurtbox.collision_mask = 0
	hurtbox.add_child(_box_shape())
	add_child(hurtbox)


func _build_contact() -> void:
	contact = Hitbox.new()
	contact.name = "Contact"
	contact.amount = contact_damage
	contact.weapon_id = &"contact"
	# Contact damage keeps applying while the boxes overlap; one_shot would make
	# an enemy harmless after the player's first i-frames expired on top of it.
	contact.one_shot = false
	contact.collision_layer = Layers.bit(Layers.ENEMY_ATTACK)
	contact.collision_mask = Layers.bit(Layers.PLAYER_HURTBOX)
	contact.add_child(_box_shape())
	add_child(contact)


## Default box, sized from the body's own collision shape so a subclass only has
## to set that one shape and the hurt/contact boxes follow.
func _box_shape() -> CollisionShape2D:
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = body_size()
	shape.shape = rect
	shape.position.y = -rect.size.y * 0.5
	return shape


## Size of the enemy's box in world pixels. Subclasses override; the default is
## one tile, which is the size of most NES small fry.
func body_size() -> Vector2:
	return Vector2(tuning.tile_size(), tuning.tile_size())
