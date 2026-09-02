## Hit points, the damage table lookup, and invulnerability frames.
##
## A component, not a base class: the player, every enemy and every boss get one
## as a child node, so nothing has to inherit from a common actor just to be
## damageable.
##
## 28 HP for the player and every boss, matching the original's 28-tick energy
## bar, so one bar segment is one HP and the HUD needs no scaling maths
## (docs/ARCHITECTURE.md section 5.3).
##
## Invulnerability is counted in physics frames and ticked by the owner rather
## than by _physics_process, for the same reason StateMachine is driven from the
## host: everything advances on one tick in one order, and a headless test can
## step it by hand.
class_name Health
extends Node

signal changed(current: int, maximum: int)
## `taken` is the damage actually applied, after the table and any clamping.
signal damaged(info: DamageInfo, taken: int)
signal healed(amount: int)
signal died(info: DamageInfo)

## The original's energy bar is 28 ticks. See section 5.3.
const BAR_TICKS := 28

@export var max_hp: int = BAR_TICKS
@export var damage_table: DamageTable
## Frames of immunity after a hit lands. 0 for most enemies -- the player's 90
## comes from PlayerTuning, which is where the number is tuned.
@export var invulnerable_frames: int = 0
## Lets a death sequence, a boss intro or a room transition switch damage off
## without unhooking the hurtbox.
@export var immune: bool = false

var current: int
var _invulnerable_left: int = 0


func _ready() -> void:
	if current <= 0:
		current = max_hp


## Applies one hit. Returns the damage actually taken, which is 0 when the hit
## was refused -- by i-frames, by immunity, or by the entity already being dead.
func take(info: DamageInfo) -> int:
	if immune or is_invulnerable() or is_dead():
		return 0

	var amount := info.amount
	if damage_table != null:
		amount = damage_table.damage_for(info.weapon_id, amount)
	if amount <= 0:
		return 0

	var taken := mini(amount, current)
	current -= taken
	_invulnerable_left = invulnerable_frames
	damaged.emit(info, taken)
	changed.emit(current, max_hp)
	if current <= 0:
		died.emit(info)
	return taken


func heal(amount: int) -> int:
	if amount <= 0 or is_dead():
		return 0
	var given := mini(amount, max_hp - current)
	if given <= 0:
		return 0
	current += given
	healed.emit(given)
	changed.emit(current, max_hp)
	return given


## Back to full, without firing `healed` -- this is a respawn, not a pickup.
func refill() -> void:
	current = max_hp
	_invulnerable_left = 0
	changed.emit(current, max_hp)


func kill(info: DamageInfo = null) -> void:
	if is_dead():
		return
	current = 0
	changed.emit(current, max_hp)
	died.emit(info if info != null else DamageInfo.new(max_hp))


func is_dead() -> bool:
	return current <= 0


func is_invulnerable() -> bool:
	return _invulnerable_left > 0


func invulnerable_frames_left() -> int:
	return _invulnerable_left


## Starts i-frames without a hit having landed, for a respawn's grace period.
func grant_invulnerability(frames: int) -> void:
	_invulnerable_left = maxi(_invulnerable_left, frames)


## Called once per physics frame by whatever owns this component.
func tick() -> void:
	if _invulnerable_left > 0:
		_invulnerable_left -= 1
