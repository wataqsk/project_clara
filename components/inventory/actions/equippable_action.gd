class_name EquippableAction
extends ActionData

@export var one_time_use: bool = true
@export var sucess_text: String = "Door Unlocked"

func _init() -> void:
	action_type = ActionType.EQUIPPABLE
