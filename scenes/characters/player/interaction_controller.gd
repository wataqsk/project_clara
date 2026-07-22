# This script handles player interaction, detecting and triggering interactions.
# Object behavior and properties are defined in InteractionComponent, not here.
extends Node

@onready var interaction_controller: Node = %InteractionController
@onready var interaction_raycast: RayCast3D = %InteractionRaycast
@onready var player_camera: Camera3D = %Camera3D
@onready var interaction_hand: Marker3D = %InteractionHand
@onready var interactable_check: Area3D = $"../InteractableCheck"
@onready var outline_material: Material = preload("res://scenes/materials/outline.tres")
@onready var default_reticle: TextureRect = %DefaultReticle

var current_object: Object = null
var last_potential_object: Object = null
var interaction_component: Node = null

func _ready() -> void:
	# THE MOUSE DOESN'T WORK VAI TOMAR NO CU
	default_reticle.position.x = get_viewport().size.x / 2 - default_reticle.texture.get_size().x / 2
	default_reticle.position.y = get_viewport().size.y / 2 - default_reticle.texture.get_size().y / 2

	interactable_check.body_entered.connect(_on_body_entered)
	interactable_check.body_exited.connect(_on_body_exited)

func _process(_delta: float) -> void:
	# If an object was being interacted with last frame, continue interacting this frame.
	if current_object:
		if Input.is_action_pressed("right_click"):
			if interaction_component:
				interaction_component.alt_interact()
				current_object = null
		elif Input.is_action_pressed("left_click"):
			if interaction_component:
				interaction_component.interact()
		# With input released, end the interaction and reset state.
		else:
			if interaction_component:
				interaction_component.post_interact()
				current_object = null

	# When there is no active interaction, check if the player can start one.
	else:
		var potential_object: Object = interaction_raycast.get_collider()
		# Check if the raycast is hitting something interactable.
		if potential_object and potential_object is Node:
			interaction_component = potential_object.get_node_or_null("InteractionComponent")

			# If found, check if interaction is currently allowed.
			if interaction_component:
				if interaction_component.can_interact == false:
					return

				# Begin interaction when the player clicks on the object.
				if Input.is_action_just_pressed("left_click"):
					current_object = potential_object
					interaction_component.pre_interact(interaction_hand)

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
