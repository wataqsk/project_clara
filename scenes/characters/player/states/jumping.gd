extends PlayerState

@export var falling: State

func enter(_previous_state: State) -> void:
	player.state_machine.travel("Jumping")

func physics_process(_delta: float) -> void:
	if player.velocity.y < 0.0:
		state_machine.transition_to(falling)
