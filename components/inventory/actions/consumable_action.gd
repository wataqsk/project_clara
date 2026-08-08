class_name ConsumableAction
extends ActionData

@export var modifier_name: String
@export var modifier_value: int

func _init() -> void:
	action_type = ActionType.CONSUMABLE
