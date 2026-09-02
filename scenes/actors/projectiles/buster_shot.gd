## A buster pellet.
##
## It *is* a Hitbox rather than containing one: a pellet is nothing but a moving
## point of damage, and an extra node would only add a transform to keep in
## step. Masking `enemy_hurtbox` and `world` is the convention from
## docs/ARCHITECTURE.md section 4 -- player shots stop at walls; enemy shots
## will not.
##
## Speed and the on-screen cap come from PlayerTuning: 5 px/frame and 3 live
## pellets. That cap is what limits the buster's damage over time, because
## Mega Man 3 has no charge shot to limit instead.
class_name BusterShot
extends Hitbox

## Pellet size in NES pixels, scaled up like every other world metric.
const SIZE_NES := Vector2(8.0, 6.0)
## How far past the view edge a pellet gets before giving up, in NES px.
const DESPAWN_MARGIN_NES := 32.0

const CORE_COLOUR := Color(0.96, 0.98, 1.0)
const EDGE_COLOUR := Color(0.45, 0.78, 1.0)

var _velocity := Vector2.ZERO
var _tuning: PlayerTuning
## Applied in _ready: a Node2D outside the tree has no global transform, so
## setting global_position at launch would be silently dropped.
var _spawn_position := Vector2.ZERO
var _direction := 1
var _weapon_id: StringName = &"buster"


## Called by whoever fires it, before it is added to the tree.
##
## The weapon id is passed in rather than read from the WeaponManager autoload,
## so a pellet carries the id of whatever actually fired it and this script has
## no dependency on a singleton. Autoload identifiers also only resolve once the
## project's autoloads are registered, which makes them a poor thing for a
## widely-preloaded script to reference.
func launch(from: Vector2, direction: int, tuning: PlayerTuning,
		p_weapon_id: StringName = &"buster") -> void:
	_tuning = tuning
	_spawn_position = from
	_direction = signi(direction) if direction != 0 else 1
	_weapon_id = p_weapon_id


func _ready() -> void:
	super()
	if _tuning == null:
		var autoload := get_node_or_null(^"/root/Tuning")
		_tuning = autoload.player if autoload != null else PlayerTuning.new()

	global_position = _spawn_position
	_velocity = Vector2(float(_direction) * _tuning.px_s(_tuning.shot_speed_pf), 0.0)

	amount = 1
	weapon_id = _weapon_id
	one_shot = true

	collision_layer = Layers.bit(Layers.PLAYER_ATTACK)
	collision_mask = Layers.mask([Layers.ENEMY_HURTBOX, Layers.WORLD])
	monitoring = true

	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = SIZE_NES * _tuning.world_scale
	shape.shape = rect
	add_child(shape)

	body_entered.connect(_on_body_entered)
	hit.connect(_on_hit)
	queue_redraw()


func _physics_process(delta: float) -> void:
	position += _velocity * delta
	if _off_screen():
		queue_free()


func _draw() -> void:
	var half := SIZE_NES * _tuning.world_scale * 0.5
	draw_rect(Rect2(-half, half * 2.0), EDGE_COLOUR)
	draw_rect(Rect2(-half * 0.55, half * 1.1), CORE_COLOUR)


## A pellet is spent on whatever it hits, whether or not that target was in
## i-frames at the time. Otherwise a shot fired into an invulnerable enemy would
## sail through, and the 3-shot cap would quietly mean something different
## depending on the target's state.
func _on_hit(_hurtbox: Hurtbox, _taken: int) -> void:
	queue_free()


func _on_body_entered(_body: Node2D) -> void:
	queue_free()


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
