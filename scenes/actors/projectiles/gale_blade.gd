## A blade Gale throws. Two jobs, one script, chosen by `returns`.
##
##   * **Returning** (Crosswind): it flies out, turns at its range, and comes
##     back to the point it was thrown from. The point is fixed at the throw
##     rather than tracking Gale, so the return leg is a line the player can
##     read the moment the blade turns -- a blade that chased its owner would be
##     a second unknown in a pattern whose whole ask is where to stand.
##   * **Straight** (Rotor): it crosses and leaves. The wall of them is the
##     attack; each blade is a lane.
##
## The player's own Gale Cutter homes at the player instead, and that difference
## is deliberate: the boss's blades come back to *it*, so the strip they never
## occupy is the one around Gale. The weapon the player is handed reverses the
## geometry, which is the same trade Rust Bloom and Prism Ray are built on.
class_name GaleBlade
extends EnemyShot

const BLADE_NES := Vector2(11.0, 11.0)
## Degrees of drawn spin per frame at 60 Hz. Cosmetic.
const SPIN_DEG := 26.0

const BODY := Color(0.58, 0.80, 0.90)
const EDGE := Color(0.90, 0.98, 1.0)

## Set before the blade enters the tree. False makes it a straight blade.
var returns := false

var _return_to := Vector2.ZERO
var _range_px := 0.0
var _travelled := 0.0
var _returning := false


## Distance out before it turns, in world px. Ignored when `returns` is false.
func set_return(to: Vector2, range_px: float) -> void:
	returns = true
	_return_to = to
	_range_px = range_px


func is_returning() -> bool:
	return _returning


func _ready() -> void:
	size_nes = BLADE_NES
	super()


func _physics_process(delta: float) -> void:
	if returns and not _returning:
		_travelled += _velocity.length() * delta
		if _travelled >= _range_px:
			_turn()
	super(delta)
	rotation += deg_to_rad(SPIN_DEG) * delta * 60.0
	# A returning blade that has arrived has nothing left to do, and one that
	# parks on its own start point is a hazard nobody threw.
	if _returning and global_position.distance_to(_return_to) < size_nes.x * _tuning.world_scale * 0.5:
		queue_free()


func _turn() -> void:
	_returning = true
	var home := _return_to - global_position
	if home.length() < 0.001:
		queue_free()
		return
	_velocity = home.normalized() * _velocity.length()


func _draw() -> void:
	var half := BLADE_NES.x * 0.5 * _tuning.world_scale
	for turn in [0.0, PI * 0.5]:
		var along := Vector2.RIGHT.rotated(turn)
		var across := Vector2.DOWN.rotated(turn)
		draw_colored_polygon(PackedVector2Array([
			along * half,
			across * half * 0.32,
			-along * half * 0.32,
			-across * half * 0.32,
		]), BODY)
	draw_circle(Vector2.ZERO, half * 0.28, EDGE)
