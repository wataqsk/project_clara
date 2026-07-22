extends Node

@onready var _player: Player = owner

func _physics_process(_delta: float) -> void:
	DebugDraw2D.set_text("FPS", Engine.get_frames_per_second())
	DebugDraw2D.set_text("Floor", "Yes" if _player.is_on_floor() else "No")
	DebugDraw2D.set_text("State", _player.state_machine.get_current_node())
