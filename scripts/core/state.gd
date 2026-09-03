## Base class for a state in a StateMachine.
##
## One script per state keeps each one short enough to read in full, and lets
## enter/exit work live next to the logic that needs it.
class_name State
extends Node

## The actor this state drives. Injected by StateMachine on ready.
var host: Node = null

## Animation this state asks the sprite to play. The `_shoot` suffix is added by
## the player, not by the state -- see Player._sprite_animation().
@export var anim_name: StringName = &"idle"

## Whether the buster can be fired from this state. False for the states where
## the arms are busy or the player is not in control: sliding, knockback, death
## and the teleport-in. Declared per state rather than as a list in the player,
## so adding a state means answering the question in the same place you set its
## animation.
@export var can_shoot: bool = true


## `msg` carries hand-off data, e.g. {"from_damage": true}.
func enter(_msg: Dictionary = {}) -> void:
	pass


func exit() -> void:
	pass


## Called from the host's _physics_process. Return a state name to transition,
## or &"" to stay.
func physics_update(_delta: float) -> StringName:
	return &""
