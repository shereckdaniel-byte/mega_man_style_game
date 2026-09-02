## Runs a set of State children for a host actor.
##
## States are plain child nodes, so the active state is visible in the remote
## scene tree while debugging and the set is editable without touching code.
class_name StateMachine
extends Node

signal state_changed(from: StringName, to: StringName)

## Name of the state to start in.
@export var initial_state: StringName = &"Idle"

var current: State = null
var previous_name: StringName = &""

## Physics frames spent in the current state. States use this for timed
## behaviour (slide duration, knockback lock) instead of a Timer, so everything
## advances on the physics tick and stays deterministic under a headless run.
var frames_in_state: int = 0

var _states: Dictionary = {}
var _host: Node = null


func setup(host: Node) -> void:
	_host = host
	for child in get_children():
		if child is State:
			var state := child as State
			state.host = host
			_states[StringName(state.name)] = state
	var start: StringName = initial_state if _states.has(initial_state) else _first_name()
	if start != &"":
		current = _states[start]
		frames_in_state = 0
		current.enter()


## Runs the active state, and keeps running whichever state it hands off to,
## so a transition takes effect on the frame it is decided rather than the frame
## after.
##
## This matters more than it looks. Without it, the frame a jump starts moves at
## the full launch velocity with no gravity applied, which puts the whole jump
## one integration step out of phase and overshoots the tuned apex by v/60 --
## about a third of a tile at 3x scale. Chains are bounded so a pair of states
## that hand back and forth cannot hang the frame.
const MAX_TRANSITIONS_PER_FRAME := 4


func physics_update(delta: float) -> void:
	if current == null:
		return
	for i in MAX_TRANSITIONS_PER_FRAME:
		var next := current.physics_update(delta)
		if next == &"":
			break
		if not transition_to(next):
			break
		if i == MAX_TRANSITIONS_PER_FRAME - 1:
			push_error("StateMachine: transition chain did not settle, stuck at %s"
				% current_name())
	frames_in_state += 1


func transition_to(next_name: StringName, msg: Dictionary = {}) -> bool:
	if not _states.has(next_name):
		push_error("StateMachine: no state named %s" % next_name)
		return false
	var from := current_name()
	if current != null:
		current.exit()
	previous_name = from
	current = _states[next_name]
	frames_in_state = 0
	current.enter(msg)
	state_changed.emit(from, next_name)
	return true


func current_name() -> StringName:
	return StringName(current.name) if current != null else &""


func has_state(state_name: StringName) -> bool:
	return _states.has(state_name)


func state_names() -> Array:
	return _states.keys()


func _first_name() -> StringName:
	var keys: Array = _states.keys()
	return keys[0] if not keys.is_empty() else &""
