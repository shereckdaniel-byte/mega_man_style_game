## A buster pellet: straight, fast, one damage, three on screen.
##
## Everything that makes it a projectile lives in WeaponShot. What is left here
## is the whole of what makes it the *buster* -- it goes in a straight line and
## it is drawn as a two-tone pellet. That is the shape a new weapon should be
## able to keep to.
##
## Speed and the on-screen cap come from PlayerTuning: 5 px/frame and 3 live
## pellets, and that cap is what limits the buster's damage over time.
##
## There *is* a charge now (ChargedShot), but it does not change that: a charged
## blast is slower damage per frame than tapping, so the cap on pellets is still
## the ceiling. See docs/PLAN.md section 2a.
class_name BusterShot
extends WeaponShot

## Pellet size in NES pixels, scaled up like every other world metric.
const SIZE_NES := Vector2(8.0, 6.0)

const CORE_COLOUR := Color(0.96, 0.98, 1.0)
const EDGE_COLOUR := Color(0.45, 0.78, 1.0)

var _velocity := Vector2.ZERO


func shot_size() -> Vector2:
	return SIZE_NES


func _configure() -> void:
	var speed := number(&"speed_pf", tuning().shot_speed_pf)
	_velocity = Vector2(float(direction()) * tuning().px_s(speed), 0.0)


func _advance(delta: float) -> void:
	position += _velocity * delta


func _draw() -> void:
	var half := SIZE_NES * tuning().world_scale * 0.5
	draw_rect(Rect2(-half, half * 2.0), EDGE_COLOUR)
	draw_rect(Rect2(-half * 0.55, half * 1.1), CORE_COLOUR)
