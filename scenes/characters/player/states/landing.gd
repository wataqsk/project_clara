extends PlayerState

@export var idle: State
@export var walking: State

func enter(_previous_state: State) -> void:
	player.state_machine.travel("Landing")

func physics_process(_delta: float) -> void:
	if player.move_direction.length_squared() > 0.0:
		state_machine.transition_to(walking)
		return
	if player.move_direction.length_squared() == 0.0:
		state_machine.transition_to(idle)
		return
