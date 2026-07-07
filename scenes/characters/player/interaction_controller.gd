extends Node

@onready var interaction_raycast: RayCast3D = %InteractionRaycast
@onready var player_camera: Camera3D = %Camera3D
@onready var interaction_hand: Marker3D = %InteractionHand

var current_object: Object
var interaction_component: Node

func _physics_process(_delta: float) -> void:
	if current_object:
		if Input.is_action_pressed("right_click"):
			if interaction_component:
				interaction_component.auxInteract()
				current_object = null
		elif Input.is_action_pressed("left_click"):
			if interaction_component:
				interaction_component.interact()
		else:
			if interaction_component:
				interaction_component.postInteract()
				current_object = null
	else:
		var potential_object: Object = interaction_raycast.get_collider()
		if potential_object and potential_object is Node:
			interaction_component = potential_object.get_node_or_null("InteractionComponent")
			if interaction_component:
				if interaction_component.can_interact == false:
					return
				if Input.is_action_pressed("left_click"):
					current_object = potential_object
					interaction_component.preInteract(interaction_hand)

					if interaction_component.interaction_type == interaction_component.InteractionType.ITEM:
						interaction_component.connect("item_collected", Callable(self, "_on_item_collected"))

func _on_item_collected(item: Node):
	# INVENTORY SYSTEM
	print("Player Collected: ", item)
