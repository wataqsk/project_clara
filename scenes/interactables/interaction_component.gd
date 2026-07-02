extends Node

enum InteractionType {
	DEFAULT
}

@export var object_ref: Node3D
@export var interaction_type: InteractionType = InteractionType.DEFAULT
@export var pull_force: float = 5.0
@export var throw_force: float = 10.0
@export var throw_cooldown: float = 2.0

var can_interact: bool = true
var is_interacting: bool = false
var player_hand: Marker3D

func preInteract(interaction_hand: Marker3D) -> void:
	is_interacting = true
	match interaction_type:
		InteractionType.DEFAULT:
			player_hand = interaction_hand

func interact() -> void:
	if not can_interact:
		return
	match interaction_type:
		InteractionType.DEFAULT:
			_default_interact()

func auxInteract() -> void:
	if not can_interact:
		return
	match interaction_type:
		InteractionType.DEFAULT:
			_default_throw()

func postInteract() -> void:
	is_interacting = false

func _default_interact() -> void:
	var object_current_position: Vector3 = object_ref.global_transform.origin
	var player_hand_position: Vector3 = player_hand.global_transform.origin
	var object_distance: Vector3 = player_hand_position - object_current_position

	var rigid_body_3d: RigidBody3D = object_ref as RigidBody3D
	if rigid_body_3d:
		rigid_body_3d.set_linear_velocity(object_distance * (pull_force / rigid_body_3d.mass))

func _default_throw() -> void:
	var object_current_position: Vector3 = object_ref.global_transform.origin
	var player_hand_position: Vector3 = player_hand.global_transform.origin
	var _object_distance: Vector3 = player_hand_position - object_current_position
	
	var rigid_body_3d: RigidBody3D = object_ref as RigidBody3D
	if rigid_body_3d:
		var throw_direction: Vector3 = player_hand.global_transform.basis.z.normalized()
		var throw_strength: float = throw_force / rigid_body_3d.mass
		rigid_body_3d.set_linear_velocity(throw_direction * throw_strength)

		can_interact = false
		await get_tree().create_timer(throw_cooldown).timeout
		can_interact = true
