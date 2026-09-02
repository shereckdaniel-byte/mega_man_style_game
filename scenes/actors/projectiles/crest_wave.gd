## Tide's floor wave: the attack the player answers by jumping.
##
## Everything here is in service of three readings, in this order of importance:
##
##   1. **Low.** The answer is to jump, so the silhouette has to sit on the deck
##      and never rise past the box. A wave you are not sure you can clear is a
##      wave you panic at.
##   2. **Coming at you.** Steep leading face, long tapering tail. A symmetric
##      shape gives the player no read on which way it is going, which matters
##      because Tide fires it from whichever side it is standing on.
##   3. **Water.** Foam along the crest, spray off the curl, and a tail that
##      fades -- otherwise it is a box moving sideways.
##
## Drawn rather than generated, like every other projectile in this game. A wave
## is mostly *motion*, and drawing it means the crest can undulate and the foam
## can travel for free, where a sprite would need an authored loop and a
## regeneration every time the size changed.
class_name CrestWave
extends EnemyShot

## Hitbox size in NES px. The silhouette is built to fit inside this, and
## `tests/test_crest_wave.gd` asserts it -- see the note on overhang below.
const WAVE_SIZE_NES := Vector2(18.0, 11.0)

## Frames per full undulation of the crest.
const BOB_PERIOD := 26.0
## How far the crest rises and falls, in NES px.
const BOB_NES := 0.7

## Width of the foam line along the crest, in NES px. Half of it sits either
## side of the crest points, which is why the crest rests further inside the box
## than the body alone would need.
const FOAM_WIDTH_NES := 1.2

const BODY_NEAR := Color(0.16, 0.52, 0.74)
const BODY_FAR := Color(0.10, 0.34, 0.52, 0.55)
const FOAM := Color(0.70, 0.95, 1.0)
const SPRAY := Color(0.88, 0.99, 1.0, 0.55)


func _ready() -> void:
	size_nes = WAVE_SIZE_NES
	super()


## The wave's outline in NES px, relative to its centre, travelling right.
##
## Kept as a function returning plain numbers rather than drawn inline so a test
## can check the one property that matters more than how it looks: **the shape
## stays inside the hitbox.** Art that overhangs its box means the player is
## clipped by something that visually missed, or walks through something that
## visually hit -- both worse than the rectangle this replaced.
##
## `phase` is 0..1 through the undulation.
static func outline(phase: float) -> PackedVector2Array:
	var half := WAVE_SIZE_NES * 0.5
	var bob := sin(phase * TAU) * BOB_NES
	# Rest heights are set so the full +/-BOB_NES swing stays inside the box.
	# The first draft put the crest at 0.6 above the top edge and the low half
	# of the cycle pushed it 0.1 px out -- caught by the box test, not by eye.
	return PackedVector2Array([
		# Tail: long, low, trailing well behind.
		Vector2(-half.x, half.y),
		Vector2(-half.x, half.y - 2.2),
		Vector2(-half.x * 0.62, half.y - 3.8 - bob * 0.3),
		Vector2(-half.x * 0.20, half.y - 6.0 - bob * 0.6),
		# The back of the crest, rounded rather than a straight ramp -- a
		# single edge from tail to peak is what made the first version read as
		# a doorstop instead of water.
		Vector2(half.x * 0.20, -half.y + 3.6 + bob * 0.9),
		Vector2(half.x * 0.48, -half.y + 1.6 + bob),
		# The peak, then the curl leaning *forward* over the leading face.
		# Rest height leaves room for the full bob *and* for half the foam line's
		# width, so neither the peak nor its white cap leaves the box.
		Vector2(half.x * 0.74, -half.y + BOB_NES + FOAM_WIDTH_NES * 0.5 + 0.2 + bob),
		# 0.90, not 0.96: the foam is stroked, so this point carries half a line
		# width past itself and at 0.96 the cap poked out of the leading edge.
		Vector2(half.x * 0.90, -half.y + 1.4 + bob * 0.7),
		# Under the curl: the face is undercut, which is the shape that says
		# "breaking wave" rather than "ramp".
		Vector2(half.x * 0.82, -half.y + 4.2),
		Vector2(half.x, -half.y + 6.4),
		Vector2(half.x * 0.88, half.y),
	])


## The crest line the foam is drawn along, front to back.
##
## A line rather than a closed strip. The first version built a strip by
## offsetting these points downward and closing the loop, which self-intersects
## exactly where the curl doubles back over the leading face -- the triangulator
## then dropped it and the foam simply never appeared. A polyline cannot fail
## that way, and at this size the difference is invisible anyway.
static func foam_outline(phase: float) -> PackedVector2Array:
	var body := outline(phase)
	var line := PackedVector2Array()
	for i in range(3, 9):
		line.append(body[i])
	return line


func _physics_process(delta: float) -> void:
	super(delta)
	queue_redraw()


func _draw() -> void:
	var scale_factor := _tuning.world_scale
	var flip: float = 1.0 if heading().x >= 0.0 else -1.0
	var phase := fposmod(float(frames_alive()) / BOB_PERIOD, 1.0)

	var body := _world_points(outline(phase), flip, scale_factor)
	# Per-vertex colour, so the tail fades out and the front stays solid. One
	# flat colour would make the whole thing read as a solid object.
	var shades := PackedColorArray()
	for i in body.size():
		shades.append(BODY_FAR if i < 4 else BODY_NEAR)
	draw_polygon(body, shades)

	draw_polyline(_world_points(foam_outline(phase), flip, scale_factor), FOAM,
		FOAM_WIDTH_NES * scale_factor)

	# Spray off the curl. It is allowed outside the box because it is faint
	# enough to read as spray rather than as the wave -- anything solid out
	# there would be lying about the hitbox.
	var half := WAVE_SIZE_NES * 0.5
	for i in 3:
		var t := phase + float(i) * 0.33
		var at := Vector2(
			(half.x * (0.55 + 0.35 * float(i)) * flip),
			-half.y - 1.2 - 2.4 * fposmod(t, 1.0)) * scale_factor
		draw_circle(at, (1.5 - 0.35 * float(i)) * scale_factor, SPRAY)


static func _world_points(points: PackedVector2Array, flip: float,
		scale_factor: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in points:
		out.append(Vector2(p.x * flip, p.y) * scale_factor)
	return out
