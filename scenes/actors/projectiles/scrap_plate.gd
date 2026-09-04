## Rust's Scrap: the one projectile in the game you are meant to shoot.
##
## **Why a shootable projectile exists at all.** Every attack in this game so far
## is answered by moving -- Tide's three timings, Arc's movement, timing and
## position. That is a complete vocabulary for dodging and no vocabulary at all
## for the other half of an action game. A hull plate the size of the player,
## thrown slowly, that can be destroyed before it arrives, asks the player to
## *shoot at the right moment* instead of to stand in the right place. It is the
## first pattern in the roster whose answer is offence.
##
## It is answerable with the buster alone (`PLATE_HP` is one buster pellet), so
## it keeps the rule that no pattern requires a weapon the player may not have.
##
## ### It is a Hitbox that also has a Hurtbox
##
## Which is the unusual part. `EnemyShot` is a pure Hitbox -- a moving point of
## damage with nothing to hit back at. This adds a `Health` and a `Hurtbox`
## beside it, so the same node both deals damage and takes it. The Hurtbox finds
## its Health by looking through its parent's children, which is why the Health
## is a sibling and not a grandchild.
class_name ScrapPlate
extends EnemyShot

## Buster pellets to break it. One: this must be answerable by the weapon every
## player has, on the frame they see it coming.
const PLATE_HP := 1

const PLATE_NES := Vector2(20.0, 18.0)
## Spin, in degrees per frame. Cosmetic, but it is what says "thrown" rather
## than "fired" and therefore what says the arc is worth watching.
const SPIN_DEG := 3.2

const PLATE := Color(0.46, 0.33, 0.26)
const PLATE_LIT := Color(0.62, 0.44, 0.31)
const RUST := Color(0.80, 0.44, 0.18)
const EDGE := Color(0.18, 0.14, 0.13)

var _health: Health
var _hurtbox: Hurtbox


func _ready() -> void:
	size_nes = PLATE_NES
	# It is thrown *through* the arena, not at a wall, and stopping on terrain
	# would have it die on the arena floor before it ever reached the player.
	stops_at_walls = false
	super()

	_health = Health.new()
	_health.name = "Health"
	_health.max_hp = PLATE_HP
	add_child(_health)
	_health.died.connect(_on_broken)

	_hurtbox = Hurtbox.new()
	_hurtbox.name = "Hurtbox"
	_hurtbox.collision_layer = Layers.bit(Layers.ENEMY_HURTBOX)
	_hurtbox.collision_mask = 0
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = PLATE_NES * _scale()
	shape.shape = rect
	_hurtbox.add_child(shape)
	add_child(_hurtbox)


func health() -> Health:
	return _health


func _physics_process(delta: float) -> void:
	super(delta)
	rotation += deg_to_rad(SPIN_DEG)
	queue_redraw()


## Broken by a shot. Freed rather than exploded: a plate that left debris would
## be a second attack the player did not choose to create by shooting it, which
## would make shooting it the wrong move.
func _on_broken(_info: DamageInfo) -> void:
	queue_free()


func _scale() -> float:
	var autoload := get_node_or_null(^"/root/Tuning")
	return autoload.player.world_scale if autoload != null else 4.5


## A torn plate, not a pellet. The silhouette has to say "big, slow, breakable"
## from across the arena -- `EnemyShot` draws a small round shot and this is the
## opposite of one in every respect.
func _draw() -> void:
	var size := PLATE_NES * _scale()
	var half := size * 0.5
	var points := PackedVector2Array([
		Vector2(-half.x, -half.y * 0.72),
		Vector2(-half.x * 0.32, -half.y),
		Vector2(half.x * 0.78, -half.y * 0.84),
		Vector2(half.x, half.y * 0.28),
		Vector2(half.x * 0.30, half.y),
		Vector2(-half.x * 0.80, half.y * 0.66),
	])
	draw_colored_polygon(points, PLATE)
	draw_colored_polygon(PackedVector2Array([
		points[0], points[1], points[2], Vector2(0.0, -half.y * 0.1),
	]), PLATE_LIT)
	# Rivets, which are the same detail the tileset uses -- the plate reads as a
	# piece of the level that has been torn off, because that is what it is.
	var rivet := maxf(size.y * 0.07, 2.0)
	for at in [Vector2(-half.x * 0.55, -half.y * 0.25), Vector2(0.0, half.y * 0.30),
			Vector2(half.x * 0.52, -half.y * 0.35)]:
		draw_circle(at, rivet, RUST)
	draw_polyline(points + PackedVector2Array([points[0]]), EDGE,
		maxf(size.y * 0.06, 2.0))
