class_name StateMachine
extends Node

## The state to start in. Drag a child state node into this slot in the Inspector.
@export var initial_state: State

var current_state: State

func _ready() -> void:
	# Inject parent and self into every state so they don't need to fetch them manually.
	# This is why State.gd can't use @onready. References come from here, not the scene tree.
	var parent_node: Node = get_parent()
	for child: Node in get_children():
		if child is State:
			child.parent = parent_node
			child.state_machine = self

	# Wait and boot into the initial state.
	# enter(null) signals there's no previous state on the first frame.
	await owner.ready
	if initial_state:
		current_state = initial_state
		current_state.enter(null)

func _process(delta: float) -> void:
	if current_state:
		current_state.process(delta)

func _physics_process(delta: float) -> void:
	if current_state:
		current_state.physics_process(delta)
		DebugDraw2D.set_text("State", current_state.name)

## Called by states to request a transition. States never swap themselves directly.
## Passing the previous state lets the new state react to where it came from.
func transition_to(target_state: State) -> void:
	# Ignore redundant transitions to the same state.
	if target_state == current_state:
		return

	var previous := current_state
	current_state.exit()
	current_state = target_state
	current_state.enter(previous)
