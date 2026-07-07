extends Node

@onready var interaction_raycast: RayCast3D = %InteractionRaycast
@onready var player_camera: Camera3D = %Camera3D
@onready var interaction_hand: Marker3D = %InteractionHand
@onready var interactable_check: Area3D = $"../InteractableCheck"

@onready var outline_material: Material = preload("res://scenes/materials/outline.tres")

var current_object: Object
var interaction_component: Node

func _ready() -> void:
	interactable_check.body_entered.connect(_on_body_entered)
	interactable_check.body_exited.connect(_on_body_exited)

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
				if Input.is_action_just_pressed("left_click"):
					current_object = potential_object
					interaction_component.preInteract(interaction_hand)

					if interaction_component.interaction_type == interaction_component.InteractionType.ITEM:
						interaction_component.connect("item_collected", Callable(self, "_on_item_collected"))

func _on_item_collected(item: Node):
	# INVENTORY SYSTEM
	print("Player Collected: ", item)

func _on_body_entered(body: Node3D) -> void:
	if body.name != "Player":
		var name = body.name
		var ic = body.get_node_or_null("InteractionComponent")
		if ic and ic.interaction_type == ic.InteractionType.ITEM:
			var mesh: MeshInstance3D = body.find_child("MeshInstance3D", true, false)
			mesh.material_overlay = outline_material

func _on_body_exited(body: Node3D) -> void:
	if body.name != "Player":
		var mesh: MeshInstance3D = body.find_child("MeshInstance3D", true, false)
		if mesh: 
			mesh.material_overlay = null
