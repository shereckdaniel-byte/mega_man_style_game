## The charged buster blast.
##
## One script for both stages -- it is the same shot bigger and harder, not two
## different weapons -- with `charge_level` deciding size, damage and colour.
##
## It does **not** pierce. A charged shot that went through everything would be
## strictly better than every weapon in the arsenal, and passing through targets
## is the Quarry bore's archetype (docs/PLAN.md section 4). This one is spent on
## what it hits, like a pellet.
class_name ChargedShot
extends WeaponShot

## Size in NES px at each stage. A charged shot is easier to land as well as
## harder-hitting -- that is most of what makes it worth the wind-up, because
## in raw damage per frame tapping still wins.
const MID_SIZE_NES := Vector2(14.0, 12.0)
const FULL_SIZE_NES := Vector2(20.0, 18.0)

const MID_CORE := Color(0.85, 0.96, 1.0)
const MID_EDGE := Color(0.35, 0.70, 1.0)
const FULL_CORE := Color(1.0, 1.0, 1.0)
const FULL_EDGE := Color(0.30, 0.90, 1.0)

## 1 mid, 2 full. Set by the player before the shot enters the tree.
var charge_level: int = 2

var _velocity := Vector2.ZERO


func shot_size() -> Vector2:
	return FULL_SIZE_NES if charge_level >= 2 else MID_SIZE_NES


func _configure() -> void:
	# Damage and the weapon id are set here rather than by the shooter, because
	# WeaponShot._ready has already filled them in from the WeaponData by the
	# time anything outside can reach the node -- assigning them before
	# add_child is silently overwritten, and assigning them after works but
	# leaves two places that decide the same thing. `_configure` is the hook
	# that runs at the right moment.
	if data != null:
		amount = data.damage_for_level(charge_level)
		# The charged id, never the weapon's own: a blast tagged `buster` looks
		# up the 1 that tap fire is meant to do and the charge does nothing.
		weapon_id = data.charged_id()

	# Slightly faster than a pellet at full charge, so a held shot reads as
	# heavier rather than merely larger.
	var base := number(&"speed_pf", tuning().shot_speed_pf)
	var speed: float = base * (1.15 if charge_level >= 2 else 1.05)
	_velocity = Vector2(float(direction()) * tuning().px_s(speed), 0.0)


func _advance(delta: float) -> void:
	position += _velocity * delta
	queue_redraw()


func _draw() -> void:
	var half := shot_size() * tuning().world_scale * 0.5
	var edge := FULL_EDGE if charge_level >= 2 else MID_EDGE
	var core := FULL_CORE if charge_level >= 2 else MID_CORE
	# A soft pulse so a blast in flight reads as energy rather than a brick.
	var pulse := 0.85 + 0.15 * sin(float(frames_alive()) * 0.5)
	draw_circle(Vector2.ZERO, half.x * pulse, edge)
	draw_circle(Vector2.ZERO, half.x * 0.55 * pulse, core)
