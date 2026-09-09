## A block of ice Frost calves off itself: **the first boss attack in the game
## that can be destroyed.**
##
## Every other projectile in the roster is a thing to be somewhere else than.
## This one has a hurtbox and a small pool of health, so the answer to it is to
## shoot it -- which makes it the only pattern answered with the fire button.
## Rust asked for offence, but at the *boss*; this asks the player to spend a
## window on the attack instead, and choosing wrong costs the floor.
##
## Shot down, it bursts and nothing lands. Allowed to land, it shatters into two
## low shards that run outward along the deck -- so the price of ignoring it is
## paid on the ground, at ankle height, in both directions at once.
class_name IceBlock
extends CharacterBody2D

const SHARD := preload("res://scenes/actors/projectiles/enemy_shot.gd")

## How much shooting it takes.
##
## Three buster pellets, not two. At two the playthrough bot -- which fires on a
## fixed cadence anyway -- deleted every block without ever deciding to, so the
## pattern cost nothing and taught nothing. Three is long enough that shooting a
## block is a choice to spend a window on it, and still few enough that the
## buster alone is a real answer, which it has to be: this is the pattern whose
## whole point is that the fire button is the dodge.
const BLOCK_HP := 3
const SIZE_NES := Vector2(16.0, 16.0)
## Contact damage while it is falling.
const TOUCH_DAMAGE := 3
## What a shard does, and how fast it runs.
const SHARD_DAMAGE := 2
const SHARD_SPEED_PF := 3.2
## Shard size, in NES px. **Low**: wide enough to read and short enough that a
## jump clears it, which is the answer left to a player who let the block land.
const SHARD_NES := Vector2(12.0, 7.0)

const ICE := Color(0.70, 0.88, 0.98)
const RIME := Color(0.94, 1.0, 1.0)
const EDGE := Color(0.34, 0.56, 0.72)

var health: Health
var hurtbox: Hurtbox
var contact: Hitbox

var _tuning: PlayerTuning
var _spawn_position := Vector2.ZERO
var _floor_y := 0.0
var _shattered := false


func calve(from: Vector2, velocity_in: Vector2, floor_y: float,
		tuning: PlayerTuning) -> void:
	_spawn_position = from
	velocity = velocity_in
	_floor_y = floor_y
	_tuning = tuning


func _ready() -> void:
	if _tuning == null:
		var autoload := get_node_or_null(^"/root/Tuning")
		_tuning = autoload.player if autoload != null else PlayerTuning.new()
	global_position = _spawn_position

	# It collides with nothing: it is driven to a known floor line by the boss
	# that threw it, and a block that could land on a moving platform or wedge
	# in a corner would shatter somewhere the pattern never meant.
	collision_layer = 0
	collision_mask = 0

	var body := CollisionShape2D.new()
	var body_rect := RectangleShape2D.new()
	body_rect.size = SIZE_NES * _tuning.world_scale
	body.shape = body_rect
	add_child(body)

	health = Health.new()
	health.name = "Health"
	health.max_hp = BLOCK_HP
	health.current = BLOCK_HP
	add_child(health)
	health.died.connect(_on_shot_down)

	hurtbox = Hurtbox.new()
	hurtbox.name = "Hurtbox"
	hurtbox.collision_layer = Layers.bit(Layers.ENEMY_HURTBOX)
	hurtbox.collision_mask = 0
	# Found by sibling search rather than assigned: `Hurtbox.health` is a
	# *getter*, and `hurtbox.health = health` is assigning to a method -- which
	# GDScript reports as "cannot assign a new value to a constant", three words
	# away from anything that would make you look here. It compiled against a
	# cached build for a whole milestone and only failed once the class cache was
	# rebuilt. `_resolve_health` walks the parent's children, and the Health is
	# added above, so there is nothing to wire.
	var hurt_shape := CollisionShape2D.new()
	var hurt_rect := RectangleShape2D.new()
	hurt_rect.size = SIZE_NES * _tuning.world_scale
	hurt_shape.shape = hurt_rect
	hurtbox.add_child(hurt_shape)
	add_child(hurtbox)

	contact = Hitbox.new()
	contact.name = "Contact"
	contact.amount = TOUCH_DAMAGE
	contact.weapon_id = &"ice"
	contact.collision_layer = Layers.bit(Layers.ENEMY_ATTACK)
	contact.collision_mask = Layers.bit(Layers.PLAYER_HURTBOX)
	var touch_shape := CollisionShape2D.new()
	var touch_rect := RectangleShape2D.new()
	touch_rect.size = SIZE_NES * _tuning.world_scale
	touch_shape.shape = touch_rect
	contact.add_child(touch_shape)
	add_child(contact)
	queue_redraw()


func is_shattered() -> bool:
	return _shattered


func _physics_process(delta: float) -> void:
	if _shattered:
		return
	health.tick()
	contact.tick()
	velocity.y = minf(velocity.y + _tuning.px_s2(_tuning.gravity_pf) * delta,
		_tuning.px_s(_tuning.terminal_velocity_pf))
	global_position += velocity * delta
	if global_position.y >= _floor_y:
		global_position.y = _floor_y
		_land()


## Shot down. Nothing reaches the floor, which is the whole reward.
func _on_shot_down(_info: DamageInfo) -> void:
	_shattered = true
	queue_free()


## Landed. Two shards, one each way, low along the deck.
func _land() -> void:
	if _shattered:
		return
	_shattered = true
	var parent := get_parent()
	if parent != null:
		for way in [-1.0, 1.0]:
			var shard := SHARD.new() as EnemyShot
			shard.size_nes = SHARD_NES
			shard.launch(global_position + Vector2(0.0, -SHARD_NES.y * 0.5 * _tuning.world_scale),
				Vector2(way, 0.0), SHARD_SPEED_PF, SHARD_DAMAGE, _tuning)
			parent.add_child(shard)
	queue_free()


func _draw() -> void:
	var size := SIZE_NES * _tuning.world_scale
	var rect := Rect2(-size * 0.5, size)
	draw_rect(rect, EDGE)
	draw_rect(rect.grow(-size.x * 0.1), ICE)
	# A bright facet, so a block reads as ice rather than as a crate.
	draw_colored_polygon(PackedVector2Array([
		Vector2(-size.x * 0.3, size.y * 0.28),
		Vector2(0.0, -size.y * 0.32),
		Vector2(size.x * 0.16, -size.y * 0.32),
		Vector2(-size.x * 0.14, size.y * 0.28),
	]), RIME)
