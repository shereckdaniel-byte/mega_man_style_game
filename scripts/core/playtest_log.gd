## What a run of a stage actually cost, broken down by room and by cause.
##
## **Why this exists.** Stage 1's difficulty has been quoted three times from
## three single bot runs -- 4 HP, then 12 HP, then "eight deaths" -- and each
## figure was a bare number with nothing behind it. A bare number cannot be
## acted on: "the stage costs 12 HP" does not say whether that is one brutal
## room or twelve fair ones, and "eight deaths" does not say whether the bot
## drowned in the tide or walked off the crumbling planks it should not have
## taken. Both readings imply opposite changes, so the number settles nothing.
##
## This records the same run as a ledger instead: every point of health lost and
## every death, stamped with the room it happened in and the thing that did it.
## "12 HP" becomes "8 of it in Under East, all from the ferry gap" -- which is a
## sentence you can disagree with, and therefore one a playtester can answer.
##
## It is deliberately **not** a difficulty judgement. It counts what happened and
## says where; whether that is too much is a question for a person playing, and
## no amount of counting will answer it. See docs/PLAN.md, "The open question".
##
## Attached by the stage for a human run and by tools/playthrough.gd for a bot
## one, so both produce the same shape of report and the two can be read side by
## side. That comparison is the point: a cost the bot pays and a human does not
## is the bot's, and a cost they both pay is the stage's.
class_name PlaytestLog
extends Node

## One thing that happened to the player's health.
##
## A typed inner class rather than a Dictionary, for the reason DamageInfo gives:
## a mistyped key should be a parse error, not a silent zero in a report someone
## is about to make a design decision from.
class Event extends RefCounted:
	var frame: int
	var room: StringName
	var cause: StringName
	## Health lost. Equal to the player's remaining HP when `fatal`, since a
	## kill takes whatever is left.
	var amount: int
	var fatal: bool
	var position: Vector2

	func _init(p_frame: int, p_room: StringName, p_cause: StringName,
			p_amount: int, p_fatal: bool, p_position: Vector2) -> void:
		frame = p_frame
		room = p_room
		cause = p_cause
		amount = p_amount
		fatal = p_fatal
		position = p_position


## How long the player spent in a room, and how many times they entered it.
##
## Entries matter as much as frames: a room entered four times is a room the
## player kept dying before the end of, whatever the clock says.
class RoomStay extends RefCounted:
	var name: StringName
	var frames: int = 0
	var entries: int = 0

	func _init(p_name: StringName) -> void:
		name = p_name


## Causes, as they arrive on DamageInfo.weapon_id. Listed here so the report can
## order them consistently and so an unrecognised one is visible as itself
## rather than being folded into a bucket.
const CAUSE_CONTACT := &"contact"
const CAUSE_SHOT := &"enemy_shot"
const CAUSE_HAZARD := &"hazard"
const CAUSE_PIT := &"pit"
const CAUSE_TIDE := &"tide"

## How close an enemy must be, in tiles, to be named as the source of a contact
## hit.
##
## Contact damage means the enemy's box is overlapping the player's, so the
## nearest one is the one that did it -- for contact and for nothing else. An
## enemy shot's shooter is metres away and often off screen by the time the
## pellet lands, so shots are recorded as `enemy_shot` and left unattributed
## rather than guessed at. A wrong name in a report is worse than no name: it
## sends the reader to nerf the wrong enemy.
const CONTACT_NAMING_TILES := 2.0

var events: Array[Event] = []
var deaths: int = 0
var frames: int = 0

var _player: Player
var _stage: Stage
var _room: StringName = &"?"
var _stays: Array[RoomStay] = []
var _stay: RoomStay = null
## The player's health now, and immediately before the most recent change.
##
## The previous value is the one a death needs. `Health` emits `changed` before
## `died`, so by the time a death arrives the current figure is already 0, and
## the source's own number is no use either -- a spike carries 9999 and
## `Health.kill()` carries a full bar. Neither is a fact about the stage. What
## the death actually cost is whatever was on the bar the frame before.
var _hp: int = 0
var _hp_before: int = 0


## Starts recording. The stage is optional: without one every event lands in a
## single unnamed room, which is what the test room and the arena want.
func watch(p_player: Player, p_stage: Stage = null) -> void:
	_player = p_player
	_stage = p_stage
	_hp = p_player.health.current
	_hp_before = _hp
	p_player.health.damaged.connect(_on_damaged)
	p_player.health.died.connect(_on_died)
	p_player.health.changed.connect(_on_health_changed)
	if p_stage != null:
		p_stage.room_changed.connect(_on_room_changed)
		if p_stage.room != null:
			_on_room_changed(p_stage.room)


func _physics_process(_delta: float) -> void:
	frames += 1
	if _stay != null:
		_stay.frames += 1


## Total health lost, deaths included.
##
## Deaths are counted at the health the player actually had, not at the nominal
## damage: a spike carries 9999 and a pit carries a full bar, and adding either
## to a running total produces a figure about the implementation rather than
## about the stage.
func hp_lost() -> int:
	var total := 0
	for e in events:
		total += e.amount
	return total


func hp_lost_in(room: StringName) -> int:
	var total := 0
	for e in events:
		if e.room == room:
			total += e.amount
	return total


func deaths_in(room: StringName) -> int:
	var n := 0
	for e in events:
		if e.room == room and e.fatal:
			n += 1
	return n


## Health lost per cause, as {cause: hp}.
func by_cause() -> Dictionary:
	var out := {}
	for e in events:
		out[e.cause] = int(out.get(e.cause, 0)) + e.amount
	return out


## Deaths per cause, as {cause: count}.
func deaths_by_cause() -> Dictionary:
	var out := {}
	for e in events:
		if e.fatal:
			out[e.cause] = int(out.get(e.cause, 0)) + 1
	return out


## The rooms in the order they were first entered.
func stays() -> Array[RoomStay]:
	return _stays


## One line for grepping across repeated runs. The spread across runs is the
## thing a single run cannot show, and it is the reason no single run should be
## quoted as the stage's cost.
func summary_line() -> String:
	return "SUMMARY hp_lost=%d deaths=%d frames=%d rooms=%d" % [
		hp_lost(), deaths, frames, _stays.size()]


## The report a person reads.
func report() -> PackedStringArray:
	var out := PackedStringArray()
	out.append("-- playtest ledger ------------------------------------------")
	out.append("total   %d HP lost, %d death%s, %d frames (%.1f s)" % [
		hp_lost(), deaths, "" if deaths == 1 else "s", frames, frames / 60.0])
	out.append("")
	out.append("room                  entries    time     HP    deaths")
	for stay in _stays:
		out.append("  %-18s %5d %8.1fs %6d %9d" % [
			stay.name, stay.entries, stay.frames / 60.0,
			hp_lost_in(stay.name), deaths_in(stay.name)])
	out.append("")
	out.append("cause                             HP    deaths")
	var costs := by_cause()
	var kills := deaths_by_cause()
	var causes := costs.keys()
	causes.sort_custom(func(a: StringName, b: StringName) -> bool:
		return int(costs[a]) > int(costs[b]))
	for cause in causes:
		out.append("  %-28s %6d %9d" % [
			cause, int(costs[cause]), int(kills.get(cause, 0))])
	if events.is_empty():
		out.append("  (nothing -- the player was never hit)")
	out.append("")
	out.append("deaths, in order")
	var any := false
	for e in events:
		if not e.fatal:
			continue
		any = true
		out.append("  f%-6d %-18s %-14s at (%.0f, %.0f)" % [
			e.frame, e.room, e.cause, e.position.x, e.position.y])
	if not any:
		out.append("  (none)")
	out.append("-------------------------------------------------------------")
	return out


func _on_room_changed(room: Room) -> void:
	_room = StringName(room.name)
	for stay in _stays:
		if stay.name == _room:
			stay.entries += 1
			_stay = stay
			return
	var fresh := RoomStay.new(_room)
	fresh.entries = 1
	_stays.append(fresh)
	_stay = fresh


func _on_health_changed(current: int, _maximum: int) -> void:
	_hp_before = _hp
	_hp = current


func _on_damaged(info: DamageInfo, taken: int) -> void:
	# A hit that reduced health to zero arrives here *and* at `_on_died`; only
	# the death records it, so the cost is not counted twice.
	if _player.health.is_dead():
		return
	_record(info, taken, false)


func _on_died(info: DamageInfo) -> void:
	deaths += 1
	_record(info, maxi(_hp_before, 0), true)


func _record(info: DamageInfo, amount: int, fatal: bool) -> void:
	var cause: StringName = info.weapon_id if info != null else &"?"
	var at := _player.global_position
	if cause == CAUSE_CONTACT:
		var named := _enemy_at(at)
		if named != &"":
			cause = named
	events.append(Event.new(frames, _room, cause, amount, fatal, at))


## The enemy overlapping the player, by the name its art was built from.
##
## Best effort, and only ever called for contact damage, where "overlapping" is
## what contact damage means. Returns empty when nothing is close enough or when
## two candidates are, because "Gullbot" in a report is a claim and "contact" is
## only a category -- a wrong claim costs more than a missing one.
func _enemy_at(point: Vector2) -> StringName:
	if _stage == null:
		return &""
	var reach := CONTACT_NAMING_TILES * _player.tuning.tile_size()
	var found: StringName = &""
	for child in _stage.get_children():
		if not (child is Enemy):
			continue
		var enemy := child as Enemy
		if enemy.global_position.distance_to(point) > reach:
			continue
		if found != &"":
			return &""
		found = StringName(enemy.name)
	return found
