# State is the interface. It defines what every state must be able to do.
# On its own it does nothing. Each state overrides only what it needs.
class_name State
extends Node

# Injected by StateMachine on _ready(). It gives every state access to the character.
# Do NOT use @onready here. This node isn't the owner, so @onready won't work.
var parent: CharacterBody3D

# Injected by StateMachine on _ready(). Lets states trigger transitions directly.
var state_machine: StateMachine

# Called once when entering this state. 
# Receives the previous state for context.
func enter(_previous_state: State) -> void:
	pass

# Called once when leaving this state. 
# Clean up anything enter() set up.
func exit() -> void:
	pass

func process(_delta: float) -> void:
	pass

func physics_process(_delta: float) -> void:
	pass
