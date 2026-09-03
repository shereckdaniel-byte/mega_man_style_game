## The death burst: eight bolts flying out from where the actor was.
##
## Drawn rather than particle-system'd, and eight rather than "some", because
## the count and the even spacing are the recognisable part of it -- the
## original fires exactly eight in a fixed ring and lets them travel at a
## constant speed until the sequence ends. A GPUParticles2D with randomised
## angles reads as a puff of smoke instead.
##
## Frees itself, so a caller can spawn one and forget it.
class_name DeathExplosion
extends Node2D

const COUNT := 8
## Speed and lifetime in NES units, scaled like every other world metric.
const SPEED_PF := 2.0
const LIFETIME_FRAMES := 60
const BOLT_RADIUS_NES := 3.0

const CORE_COLOUR := Color(0.98, 0.99, 1.0)
const EDGE_COLOUR := Color(0.45, 0.78, 1.0)

var _frames := 0
var _scale := 4.5


func _ready() -> void:
	var autoload := get_node_or_null(^"/root/Tuning")
	if autoload != null:
		_scale = autoload.player.world_scale
	z_index = 50


func _physics_process(_delta: float) -> void:
	_frames += 1
	if _frames >= LIFETIME_FRAMES:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var distance := float(_frames) * SPEED_PF * _scale
	var radius := BOLT_RADIUS_NES * _scale
	# Fade out over the back half, so the ring thins rather than vanishing.
	var life := float(_frames) / float(LIFETIME_FRAMES)
	var alpha := 1.0 - maxf(0.0, (life - 0.5) * 2.0)
	for i in COUNT:
		var angle := TAU * float(i) / float(COUNT)
		var at := Vector2(cos(angle), sin(angle)) * distance
		draw_circle(at, radius, Color(EDGE_COLOUR, alpha))
		draw_circle(at, radius * 0.5, Color(CORE_COLOUR, alpha))


## Convenience for the common case: burst at a point in the given parent.
static func burst(parent: Node, at: Vector2) -> DeathExplosion:
	var explosion := DeathExplosion.new()
	parent.add_child(explosion)
	explosion.global_position = at
	return explosion
