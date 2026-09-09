## Sinkhole's gimmick: water you jump higher in and fall slower through.
##
## ### It is the only one of the four that helps
##
## Stage 5's wind is a cycle you time, stage 6's belt a constant you fight,
## stage 7's ice a floor that will not stop you. All three take something away.
## Water gives: gravity is weaker inside it, so the same jump goes higher and
## the fall back is slower, and **every crossing in a flooded room is easier
## than the same crossing dry.**
##
## That is not a soft ending, it is what makes the last stage's rooms authorable
## at all. A stage whose gimmick only ever helps can put geometry in front of
## the player that would be unreasonable on land -- long gaps, high ledges,
## ceilings worth reaching -- and the difficulty comes from the shape of the
## room rather than from a force fighting the controls. The stage's hard rooms
## are the **dry** ones, which is the inversion its whole layout is built on.
##
## ### The fairness rules
##
## Shorter than the other three's, because the direction of the effect removes
## most of the ways this could go wrong:
##
##   1. **It can only make a jump longer.** `buoyancy` scales gravity down and
##      never up, and it leaves jump velocity alone, so no authored gap is ever
##      harder wet than dry. Stage 5's wind could shorten an arc and made
##      two-cell gaps uncrossable; water structurally cannot, which is why there
##      is no margin rule here and why `tests/test_water_volume.gd` checks the
##      inequality rather than trusting it.
##   2. **Nothing lethal hangs over water.** A higher jump reaches ceilings the
##      player has spent seven stages learning they cannot reach, so a spike
##      that was safely out of range on land is not out of range here.
##      `tests/test_sinkhole.gd` holds the stage to it.
##   3. **It never drowns.** There is no air meter and no damage over time:
##      water in this game is a change of physics, not a hazard, and everything
##      dangerous in a flooded room is a thing that was put there.
class_name WaterVolume
extends Area2D

## How much of normal gravity applies inside, 0..1.
##
## A third is the genre's number and it is the right one: a jump reaches about
## three times its dry apex, which is a whole extra storey and unmistakable the
## first time it happens, and the fall is slow enough to steer without being
## slow enough to be boring.
const DEFAULT_BUOYANCY := 0.34

@export var buoyancy: float = DEFAULT_BUOYANCY
@export var width_tiles: float = 8.0
## How deep the pool is, in tiles, measured **down from the surface**.
@export var depth_tiles: float = 4.0

const BODY := Color(0.20, 0.44, 0.62, 0.44)
const SURFACE := Color(0.62, 0.88, 0.96, 0.85)
const GLINT := Color(0.86, 0.98, 1.0)

var _tuning: PlayerTuning
var _player: Player = null
var _frames := 0


## How high a jump reaches inside, in NES px, for a given buoyancy. Pure, so the
## level tests can ask without building a room.
##
## The discrete apex `PlayerTuning.jump_apex_nes_px` integrates a frame at a
## time under full gravity; weakening gravity by `b` scales the apex by `1 / b`,
## because the rise lasts `v / (g * b)` frames and covers `v^2 / (2 * g * b)`.
static func jump_apex_in_water(dry_apex_nes: float, at_buoyancy: float) -> float:
	return dry_apex_nes / maxf(at_buoyancy, 0.0001)


func _ready() -> void:
	var autoload := get_node_or_null(^"/root/Tuning")
	_tuning = autoload.player if autoload != null else PlayerTuning.new()

	collision_layer = 0
	collision_mask = Layers.bit(Layers.PLAYER_BODY)
	monitoring = true

	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	var tile := _tuning.tile_size()
	rect.size = Vector2(width_tiles, depth_tiles) * tile
	shape.shape = rect
	# Anchored at the pool's top-left, on the surface, so a stage places water
	# by saying where its surface is rather than where its middle would be.
	shape.position = Vector2(rect.size.x * 0.5, rect.size.y * 0.5)
	add_child(shape)

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	z_index = -4
	queue_redraw()


func has_swimmer() -> bool:
	return _player != null and is_instance_valid(_player)


func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		_player = body as Player


func _on_body_exited(body: Node2D) -> void:
	if body == _player:
		_player = null


func _physics_process(_delta: float) -> void:
	_frames += 1
	queue_redraw()
	if has_swimmer():
		_player.buoyancy = buoyancy


func _draw() -> void:
	var tile := _tuning.tile_size()
	var size := Vector2(width_tiles, depth_tiles) * tile
	draw_rect(Rect2(Vector2.ZERO, size), BODY)
	# The surface line, which is the only part a player needs to read precisely:
	# it is where their jump changes.
	draw_rect(Rect2(Vector2.ZERO, Vector2(size.x, tile * 0.16)), SURFACE)
	# A slow travelling glint along it, so the surface reads as water rather
	# than as a coloured box with a bright edge.
	var pitch := tile * 3.0
	var offset := fposmod(float(_frames) * 0.6, pitch)
	var at := offset - pitch
	while at < size.x:
		var x := clampf(at, 0.0, size.x)
		var w := minf(tile * 0.9, size.x - x)
		if w > 0.0:
			draw_rect(Rect2(Vector2(x, tile * 0.04), Vector2(w, tile * 0.1)),
				Color(GLINT, 0.7))
		at += pitch
