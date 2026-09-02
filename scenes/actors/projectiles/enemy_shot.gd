## An enemy projectile.
##
## The mirror of BusterShot, with one deliberate difference: it masks
## `player_hurtbox` only, so it **passes through walls**. That is the convention
## from ARCHITECTURE section 4 and it is faithful — many NES enemy shots ignore
## terrain, and a turret whose shots died on the scenery it is standing behind
## would be harmless.
##
## `stops_at_walls` exists for the enemies that should be the exception, rather
## than making the next author copy this file to get one.
class_name EnemyShot
extends Hitbox

const SIZE_NES := Vector2(6.0, 6.0)
const DESPAWN_MARGIN_NES := 48.0

const CORE_COLOUR := Color(1.0, 0.95, 0.85)
const EDGE_COLOUR := Color(1.0, 0.62, 0.30)

## Set true for a shot that should be blocked by terrain.
@export var stops_at_walls := false

var _velocity := Vector2.ZERO
var _tuning: PlayerTuning
var _spawn_position := Vector2.ZERO
var _damage := 2


## Called before the shot enters the tree. Direction is a vector, not a sign:
## turrets fire along an axis but a spawner's drones leave at an angle.
func launch(from: Vector2, direction: Vector2, speed_pf: float, damage: int,
		tuning: PlayerTuning) -> void:
	_tuning = tuning
	_spawn_position = from
	_damage = damage
	var heading := direction.normalized() if direction.length() > 0.001 else Vector2.RIGHT
	_velocity = heading * tuning.px_s(speed_pf)


func _ready() -> void:
	super()
	if _tuning == null:
		var autoload := get_node_or_null(^"/root/Tuning")
		_tuning = autoload.player if autoload != null else PlayerTuning.new()

	global_position = _spawn_position
	amount = _damage
	weapon_id = &"enemy_shot"
	one_shot = true

	collision_layer = Layers.bit(Layers.ENEMY_ATTACK)
	collision_mask = Layers.bit(Layers.PLAYER_HURTBOX)
	if stops_at_walls:
		collision_mask |= Layers.bit(Layers.WORLD)
		body_entered.connect(func(_b: Node2D) -> void: queue_free())
	monitoring = true

	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = SIZE_NES * _tuning.world_scale
	shape.shape = rect
	add_child(shape)

	hit.connect(func(_h: Hurtbox, _t: int) -> void: queue_free())
	queue_redraw()


func _physics_process(delta: float) -> void:
	position += _velocity * delta
	if _off_screen():
		queue_free()


func _draw() -> void:
	var radius := SIZE_NES.x * _tuning.world_scale * 0.5
	draw_circle(Vector2.ZERO, radius, EDGE_COLOUR)
	draw_circle(Vector2.ZERO, radius * 0.5, CORE_COLOUR)


func _off_screen() -> bool:
	var viewport := get_viewport()
	if viewport == null:
		return false
	var camera := viewport.get_camera_2d()
	if camera == null:
		return false
	var margin := DESPAWN_MARGIN_NES * _tuning.world_scale
	var view := viewport.get_visible_rect().size / camera.zoom
	var centre := camera.get_screen_center_position()
	return absf(global_position.x - centre.x) > view.x * 0.5 + margin \
		or absf(global_position.y - centre.y) > view.y * 0.5 + margin
