extends PlayerState

@export var landing: State

func enter(_previous_state: State) -> void:
	player.state_machine.travel("Falling")

func physics_process(_delta: float) -> void:
	if player.is_on_floor() and not player.is_jumping:
		state_machine.transition_to(landing)
