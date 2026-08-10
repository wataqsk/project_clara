# TO-DO: Add selectable SFXs.
# Attach this script to any object that should be interactable.
# Set the object reference and interaction type in the Inspector.
# This script is set per object in the Inspector.
extends Node

## Defines how the object behaves when the player interacts with it.
enum InteractionType {
	DEFAULT, ## placeholder with no behavior.
	ITEM     ## can be picked up by the player.
}

@export_category("Interaction")
@export_group("Properties")
## The Node3D this component makes interactable.
@export var object_ref: Node3D
## Determines what happens when the player interacts with this object.
@export var interaction_type: InteractionType = InteractionType.DEFAULT
##
@export var item_data: ItemData

@export_group("Pickup Properties")
## How strongly the object is pulled toward the player's hand.
@export_range(0.0, 20.0, 0.5, "suffix:m/s") var pull_force: float = 5.0
## How strongly the object is thrown when secondary interact is triggered.
@export_range(0.0, 50.0, 1.0, "suffix:m/s") var throw_force: float = 10.0
## Time before the player can interact with the thrown object again.
@export_range(0.0, 5.0, 0.1, "suffix:s") var throw_cooldown: float = 2.0
## Maximum distance the player can be from this object before interaction ends.
@export_range(0.5, 10.0, 0.5, "suffix:m") var max_interact_distance: float = 6.0

var can_interact: bool = true
var is_interacting: bool = false
var player_hand: Marker3D

# Signals
signal item_collected(item: Node)

# Called once when the player first initiates an interaction with this object.
func pre_interact(interaction_hand: Marker3D) -> void:
	is_interacting = true
	match interaction_type:
		InteractionType.DEFAULT:
			# Finds the player's hand reference for use during interaction.
			player_hand = interaction_hand

# Called every frame while the player is holding the interact input on this object.
func interact() -> void:
	if not can_interact:
		return
	match interaction_type:
		InteractionType.DEFAULT:
			_default_interact()
		InteractionType.ITEM:
			_collect_item()

# Called once when the player initiates an auxiliary interaction with this object.
func alt_interact() -> void:
	if not can_interact:
		return
	match interaction_type:
		InteractionType.DEFAULT:
			_default_throw()

# Called once when the player releases the interact input or moves out of range.
func post_interact() -> void:
	is_interacting = false

func _default_interact() -> void:
	var object_current_position: Vector3 = object_ref.global_transform.origin
	var player_hand_position: Vector3 = player_hand.global_transform.origin
	# Direction and distance from the object to the player's hand.
	var object_distance: Vector3 = player_hand_position - object_current_position

	# Only applies physics if the object is a RigidBody3D.
	var rigid_body_3d: RigidBody3D = object_ref as RigidBody3D
	
	# Heavier objects are harder to pull, mass divides the force.
	if rigid_body_3d:
		rigid_body_3d.set_linear_velocity(object_distance * (pull_force / rigid_body_3d.mass))

func _default_throw() -> void:
	var object_current_position: Vector3 = object_ref.global_transform.origin
	var player_hand_position: Vector3 = player_hand.global_transform.origin
	var _object_distance: Vector3 = player_hand_position - object_current_position

	var rigid_body_3d: RigidBody3D = object_ref as RigidBody3D

	if rigid_body_3d:
		# Throw in the direction the player's hand is facing.
		var throw_direction: Vector3 = player_hand.global_transform.basis.z.normalized()
		# Heavier objects are thrown with less force.
		var throw_strength: float = throw_force / rigid_body_3d.mass
		rigid_body_3d.set_linear_velocity(throw_direction * throw_strength)

		# Prevent immediately re-interacting with the thrown object.
		can_interact = false
		await get_tree().create_timer(throw_cooldown).timeout
		can_interact = true

func _collect_item() -> void:
	# Notify the item was collected, then remove it from the scene.
	emit_signal("item_collected", get_parent())
	get_parent().queue_free()
