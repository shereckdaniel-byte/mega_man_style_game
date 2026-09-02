## Tide's floor wave: the shape, and the promise it makes about the hitbox.
##
## The interesting assertion here is not that it looks like a wave -- no test
## can check that -- but that **it does not lie**. Art that overhangs its own
## hitbox means the player is clipped by something that visually missed, or
## walks through something that visually connected. Both are worse than the
## rectangle this replaced, and both are exactly what happens when a silhouette
## is tuned by eye against a box nobody re-measured.
extends TestCase

const CrestWaveScript := preload("res://scenes/actors/projectiles/crest_wave.gd")

## Sampled across the undulation, because the crest moves and only some phases
## are near the edge.
const PHASES := [0.0, 0.125, 0.25, 0.375, 0.5, 0.625, 0.75, 0.875]


func test_the_body_never_leaves_the_hitbox() -> void:
	var half := CrestWave.WAVE_SIZE_NES * 0.5
	for phase: float in PHASES:
		for point: Vector2 in CrestWaveScript.outline(phase):
			assert_true(absf(point.x) <= half.x + 0.001,
				"phase %.3f: x=%.2f is outside the %.1f half-width"
					% [phase, point.x, half.x])
			assert_true(absf(point.y) <= half.y + 0.001,
				"phase %.3f: y=%.2f is outside the %.1f half-height"
					% [phase, point.y, half.y])


## The foam is a *stroked line*, so half its width sits outside the points it
## runs through. That half-width is the part most likely to poke out of the box
## unnoticed, which is why it is in the assertion rather than the points alone.
func test_the_foam_never_leaves_the_hitbox() -> void:
	var half := CrestWave.WAVE_SIZE_NES * 0.5
	var reach: float = CrestWave.FOAM_WIDTH_NES * 0.5
	for phase: float in PHASES:
		for point: Vector2 in CrestWaveScript.foam_outline(phase):
			assert_true(absf(point.x) + reach <= half.x + 0.001 \
					and absf(point.y) + reach <= half.y + 0.001,
				"phase %.3f: foam point %s plus its %.1f half-width leaves the box"
					% [phase, str(point), reach])


## The foam has to actually be a line. A single point, or none, means the crest
## run was indexed wrong and there is no white cap -- which is what happened
## when the outline gained points and the slice was not moved with it.
func test_the_foam_runs_along_the_crest() -> void:
	var line := CrestWaveScript.foam_outline(0.0)
	assert_true(line.size() >= 4, "the foam line has only %d points" % line.size())
	var span := 0.0
	for i in range(1, line.size()):
		span += line[i].distance_to(line[i - 1])
	assert_true(span > CrestWave.WAVE_SIZE_NES.x * 0.5,
		"the foam only covers %.1f px of an %.1f px wave" % [span, CrestWave.WAVE_SIZE_NES.x])


## It has to sit on the deck, because the answer to the pattern is to jump it.
## A wave floating a pixel off the ground reads as something you can walk under.
func test_the_wave_sits_on_its_own_base() -> void:
	var half := CrestWave.WAVE_SIZE_NES * 0.5
	for phase: float in PHASES:
		var lowest := -1000.0
		for point: Vector2 in CrestWaveScript.outline(phase):
			lowest = maxf(lowest, point.y)
		assert_almost_eq(lowest, half.y, 0.001,
			"phase %.3f: the wave's base is %.2f, not %.2f" % [phase, lowest, half.y])


## Asymmetric on purpose: Tide fires it from whichever side it is standing, and
## a symmetric blob tells the player nothing about which way it is travelling.
func test_the_wave_is_not_symmetrical() -> void:
	var points := CrestWaveScript.outline(0.0)
	var front_area := 0.0
	var back_area := 0.0
	var half := CrestWave.WAVE_SIZE_NES * 0.5
	for point: Vector2 in points:
		# Height above the base, on each side of the centre line.
		var height: float = half.y - point.y
		if point.x > 0.0:
			front_area += height
		elif point.x < 0.0:
			back_area += height
	assert_true(front_area > back_area * 1.3,
		"the front carries %.1f of height and the tail %.1f; it reads as a blob"
			% [front_area, back_area])


## The crest actually moves. If the bob were zero the shape would be static and
## the whole reason for drawing it rather than generating a sprite would be gone.
func test_the_crest_undulates() -> void:
	var a := CrestWaveScript.outline(0.25)
	var b := CrestWaveScript.outline(0.75)
	var moved := false
	for i in a.size():
		if absf(a[i].y - b[i].y) > 0.1:
			moved = true
			break
	assert_true(moved, "the crest is identical at both extremes of its cycle")


## The shape is built for the size the hitbox is actually created at.
func test_the_outline_matches_the_shipped_hitbox_size() -> void:
	assert_eq(CrestWave.WAVE_SIZE_NES, Vector2(18.0, 11.0))
