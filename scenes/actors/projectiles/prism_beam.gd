## A beam of light with somewhere to be. Prism's Split and Facets are both this
## class; what separates them is one field.
##
## Every projectile in the game so far arrives once, from where it was fired, and
## is finished with. A beam has a **second act**: it reaches something and does
## something there, and the thing it does is the pattern. So the travelling is
## shared and the edge behaviour is the difference:
##
##   * `SPLIT` -- reaches the far wall and becomes two beams coming back, one
##     along the floor and one up at head height. This is Prism's signature and
##     the weapon the player is handed for beating it.
##   * `REFLECT` -- turns round and goes back, up to `bounces` times. Between two
##     planted mirrors that is a corridor the beam rattles inside.
##   * `EXPIRE` -- stops. What the halves of a split are, so a split cannot
##     split again and fill the arena.
##
## ### Why the high half waits at the wall
##
## The two have to arrive apart, or the pattern is unanswerable: the low beam
## must be jumped and the high one must be stood under, and no player is both at
## one instant. Arriving apart makes it a two-beat answer -- jump, land, stay
## down -- which is readable.
##
## **The separation is a delay, not a speed difference**, and that is the second
## version of this. The first made the high half slower, which works out to
## `distance / v_high - distance / v_low` frames of separation -- so it depended
## on how far from the wall the player happened to be standing, and
## `tests/test_prism.gd` failed it at close range: 33 frames apart with a jump
## airborne for 40, which is precisely the case the paragraph above promises
## cannot happen. Slowing the high half enough to fix the near case left it
## barely outpacing a walk.
##
## So both halves travel at the same readable speed and the high one is **held at
## the wall** for `HIGH_DELAY_FRAMES` first. The separation is then a constant,
## the same wherever the player is standing, and it is visible -- the beam sits
## at the wall glowing before it sets off, which is a tell rather than a
## surprise.
class_name PrismBeam
extends EnemyShot

## What the beam does when it reaches the edge of its span.
enum OnEdge { SPLIT, REFLECT, EXPIRE }

## The beam's own box. **Not `SIZE_NES`**: `EnemyShot` already declares that
## name, and a subclass that reuses it fails to compile the whole script -- which
## shows up not as an error about this line but as `.new()` not existing on the
## preload, three files away, at runtime.
const BEAM_NES := Vector2(15.0, 5.0)

## Travel speeds in NES px/frame.
const CAST_SPEED_PF := 3.4
const SPLIT_SPEED_PF := 3.8
const REFLECT_SPEED_PF := 3.0

## Frames the high half waits at the wall before setting off. A jump is airborne
## about 40 (`PhaseBlock.BEAT_FRAMES`), so this is one jump plus enough to land
## and settle -- which is exactly the two-beat answer the pattern is asking for.
## Distance-independent by construction: see the docstring.
const HIGH_DELAY_FRAMES := 52

## Heights the two halves of a split come back at, in NES px above the floor,
## measured to the beam's **centre**.
##
## The low one is at 5, so its top edge is at 7.5 and a standing player (24 NES
## px) or a sliding one (14) is caught: the only answer is to leave the ground.
## The high one is at 34, so its underside is at 31.5 -- clear of a standing head
## by seven and a half pixels, and squarely in the path of anybody still in the
## air from the last one. Standing still is the answer to exactly one of them,
## which is the point.
const LOW_HEIGHT_NES := 5.0
const HIGH_HEIGHT_NES := 34.0

const CORE := Color(1.0, 1.0, 0.96)
const HALO := Color(0.62, 0.86, 1.0)

## Left and right limits of the beam's travel, in world x. Set by whoever fires
## it -- the arena's walls for a Split, the planted mirrors for a Facet.
var span := Vector2.ZERO
var on_edge: OnEdge = OnEdge.EXPIRE
## Reflections left. Only read in `REFLECT`.
var bounces := 0
## The floor the split's halves are measured from, in world y.
var floor_y := 0.0
## Frames the beam waits where it was launched before it starts travelling. Zero
## for everything except the high half of a split -- see the docstring.
var hold_frames := 0

var _finished := false


## Everything a beam needs that `EnemyShot.launch` does not cover. Called after
## `launch` and before the beam is added to the tree.
func aim(p_span: Vector2, p_on_edge: OnEdge, p_bounces: int, p_floor_y: float) -> void:
	span = Vector2(minf(p_span.x, p_span.y), maxf(p_span.x, p_span.y))
	on_edge = p_on_edge
	bounces = p_bounces
	floor_y = p_floor_y


func _ready() -> void:
	size_nes = BEAM_NES
	super()
	weapon_id = &"prism_beam"
	# **Not one_shot.** A beam that reflects passes the player more than once and
	# has to be able to hurt them on each pass; the i-frames are what stop that
	# being a shredder, the same way they do for contact damage.
	one_shot = on_edge != OnEdge.REFLECT
	if not one_shot:
		repeat_delay_frames = 30
		# `EnemyShot` frees itself on any hit. A reflecting beam outlives the
		# player it touched, so that connection has to be undone here rather
		# than never made -- the base class is right for every other projectile.
		for connection in hit.get_connections():
			hit.disconnect(connection["callable"])


func _physics_process(delta: float) -> void:
	if hold_frames > 0:
		# Held at the wall. `EnemyShot._physics_process` is skipped rather than
		# called with a zero delta, because it is also what despawns a shot that
		# has left the view -- and a beam waiting on the far wall is exactly the
		# thing that must not be despawned for being over there.
		hold_frames -= 1
		queue_redraw()
		return
	super(delta)
	if _finished or is_queued_for_deletion():
		return
	# A reflecting beam is not `one_shot`, and a Hitbox that is not one_shot only
	# lands repeat hits if somebody ticks it (see `Hitbox.tick`). Without this a
	# player who simply stood still in the corridor would be hit on the pass that
	# began the overlap and never again.
	if not one_shot:
		tick()
	if span.y - span.x < 0.001:
		return
	if global_position.x <= span.x and heading().x < 0.0:
		_reach_edge(span.x)
	elif global_position.x >= span.y and heading().x > 0.0:
		_reach_edge(span.y)


func _reach_edge(at_x: float) -> void:
	match on_edge:
		OnEdge.REFLECT:
			bounces -= 1
			global_position.x = at_x
			_reverse()
			if bounces <= 0:
				on_edge = OnEdge.EXPIRE
		OnEdge.SPLIT:
			_finished = true
			_split(at_x)
			queue_free()
		OnEdge.EXPIRE:
			_finished = true
			queue_free()


## The two halves, launched back the way the beam came.
##
## Spawned into the beam's own parent -- the level -- rather than as children of
## the beam, which is about to be freed. Parenting them to it would take them
## with it, and the pattern would be a beam that hits a wall and stops.
func _split(at_x: float) -> void:
	var parent := get_parent()
	if parent == null:
		return
	var back := -signf(heading().x)
	if back == 0.0:
		back = -1.0
	for spec in [[LOW_HEIGHT_NES, 0], [HIGH_HEIGHT_NES, HIGH_DELAY_FRAMES]]:
		var half := (get_script() as GDScript).new() as PrismBeam
		half.launch(Vector2(at_x, floor_y - float(spec[0]) * _scale()),
			Vector2(back, 0.0), SPLIT_SPEED_PF, amount, _beam_tuning())
		half.aim(span, OnEdge.EXPIRE, 0, floor_y)
		half.hold_frames = int(spec[1])
		parent.add_child(half)


## Turns the beam round.
##
## Re-launching rather than negating a velocity: `EnemyShot` owns the velocity
## and this class should not reach into it. `launch` also records a spawn
## position, but that is only applied in `_ready` -- the beam is already in the
## tree, so where it is now is where it stays.
func _reverse() -> void:
	launch(global_position, Vector2(-signf(heading().x), 0.0), REFLECT_SPEED_PF,
		amount, _beam_tuning())
	rearm()


func _beam_tuning() -> PlayerTuning:
	var autoload := get_node_or_null(^"/root/Tuning")
	return autoload.player if autoload != null else PlayerTuning.new()


func _scale() -> float:
	return _beam_tuning().world_scale


## A bar of light, not a pellet. Drawn along the direction of travel with a soft
## halo, so a beam reads as light rather than as a thrown object -- and so the
## high one and the low one are the same object at two heights, which is the
## thing the player has to notice.
func _draw() -> void:
	var scale := _scale()
	var half := Vector2(size_nes.x * 0.5, size_nes.y * 0.5) * scale
	if hold_frames > 0:
		# Gathering at the wall: a pulsing bloom that grows as it is about to
		# leave. It has to read as charging rather than as a beam that got stuck,
		# so it is drawn wider and softer than a travelling one and never at full
		# core brightness.
		var swell := 0.55 + 0.45 * sin(float(hold_frames) * 0.35)
		draw_rect(Rect2(-half * Vector2(0.9, 3.0 * swell),
			half * 2.0 * Vector2(0.9, 3.0 * swell)), Color(HALO, 0.34))
		draw_rect(Rect2(-half * Vector2(0.7, 1.1), half * 2.0 * Vector2(0.7, 1.1)),
			Color(HALO, 0.75))
		return
	var flat := absf(heading().x) >= absf(heading().y)
	if not flat:
		half = Vector2(half.y, half.x)
	draw_rect(Rect2(-half * Vector2(1.35, 2.1), half * 2.0 * Vector2(1.35, 2.1)),
		Color(HALO, 0.28))
	draw_rect(Rect2(-half, half * 2.0), HALO)
	draw_rect(Rect2(-half * Vector2(1.0, 0.45), half * 2.0 * Vector2(1.0, 0.45)),
		CORE)
