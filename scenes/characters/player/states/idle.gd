extends PlayerState

@export var walking: State
@export var jumping: State
@export var falling: State

func enter(_previous_state: State) -> void:
	player.state_machine.travel("Idle")

func physics_process(_delta: float) -> void:
	if not player.is_on_floor():
		state_machine.transition_to(falling)
		return
	if player.move_direction.length_squared() > 0.0:
		state_machine.transition_to(walking)
		return
	if player.is_jumping:
		state_machine.transition_to(jumping)
