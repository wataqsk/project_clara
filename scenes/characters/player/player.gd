class_name Player 
extends CharacterBody3D

@export_category("Camera")
@export_group("Camera Sensitivity")
## How sensitive the camera is to mouse movement.
@export_range(0.0, 1.0, 0.05) var camera_sensitivity:float = 0.25

@export_group("Camera Pitch")
## Maximum downward angle the camera can look.
@export_range(-90.0, 0.0, 5.0, "suffix:°") var camera_pitch_min:float = -80.0
## Maximum upward angle the camera can look.
@export_range(0.0, 90.0, 5.0, "suffix:°") var camera_pitch_max:float = 80.0

@export_category("Movement")
@export_group("Character Speed")
## How fast the character can move.
@export_range(0.0, 20.0, 0.5, "suffix:m/s") var move_speed:float = 4.0
## How quickly the character reaches maximum speed.
@export_exp_easing("positive_only") var acceleration:float = 10.0

@export_group("Character Jump")
## How fast the character launches upward when jumping.
@export_range(0.0, 25.0, 0.5, "suffix:m/s") var jump_velocity:float = 9.0

## How long the jump input is remembered before landing.
@export_range(0.0, 0.5, 0.05, "suffix:s") var jump_buffer_time: float = 0.15

## The short period where the player can still jump after walking off a ledge.
@export_range(0.0, 0.2, 0.01, "suffix:s") var coyote_time:float = 0.1

@export_group("Character Model")
## How fast the character model rotates to face the movement direction.
@export_range(1.0, 20.0, 0.5, "suffix:°/s") var rotation_speed:float = 8.0

@export_group("Character Gravity")
## Multiplies character's gravity while falling.
@export_range(1.0, 10.0, 0.5, "suffix:x") var fall_multiplier: float = 3.0

@export var note_sway_amount: float = 0.1

var _camera_input_direction: Vector2 = Vector2.ZERO
## Current movement direction, read by state machine.
var move_direction: Vector3 = Vector3.ZERO	
## Last non-zero direction, keeps skin facing forward when idle.
var _last_move_direction: Vector3 = Vector3.BACK
var is_jumping: bool = false
var _was_on_floor: bool = false
var _jump_buffer_timer: float = 0.0
var _coyote_timer: float = 0.0
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var state_machine: AnimationNodeStateMachinePlayback

@onready var _camera: Camera3D = %Camera3D
@onready var _camera_pivot: Node3D = %CameraPivot
@onready var _interaction_controller: Node = %InteractionController
@onready var _interaction_raycast: RayCast3D = %InteractionRaycast
@onready var _inventory_controller: Node = %InventoryController/CanvasLayer/InventoryUI
@onready var _skin: Node3D = %Mannequin
@onready var note_hand: Marker3D = %NoteHand

func _ready() -> void:
	state_machine = $AnimationTree.get("parameters/Movement/playback") as AnimationNodeStateMachinePlayback

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		var is_captured = Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if is_captured else Input.MOUSE_MODE_CAPTURED

	# Open inventory: show mouse for UI interaction, disable interact raycast.
	if event.is_action_pressed("inventory"):
		_inventory_controller.visible = true
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		_interaction_raycast.enabled = false

	# Close inventory: hide UI, re-enable raycast, and recapture mouse.
	elif event.is_action_released("inventory"):
		_inventory_controller.visible = false
		_interaction_raycast.enabled = true
		# Only recapture the mouse if the player isn't mid-interaction.
		if not _interaction_controller.current_object:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _unhandled_input(event: InputEvent) -> void:
	var is_camera_motion := (
		event is InputEventMouseMotion and
		Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED
	)
	if is_camera_motion:
		_camera_input_direction += event.screen_relative * camera_sensitivity

func _physics_process(delta: float) -> void:
	_update_camera(delta)
	_update_movement(delta)
	_update_coyote_time(delta)
	_update_jump(delta)
	_update_gravity(delta)
	move_and_slide()
	_note_tilt_and_sway(move_direction, delta)

func _update_camera(delta: float) -> void:
	_camera_pivot.rotation.x += _camera_input_direction.y * delta
	_camera_pivot.rotation.x = clamp(
		_camera_pivot.rotation.x,
		deg_to_rad(camera_pitch_min),
		deg_to_rad(camera_pitch_max)
	)
	_camera_pivot.rotation.y -= _camera_input_direction.x * delta
	_camera_input_direction = Vector2.ZERO

func _update_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta
		if velocity.y < 0:
			velocity.y -= gravity * fall_multiplier * delta

func _update_coyote_time(delta: float) -> void:
	if is_on_floor():
		_coyote_timer = 0.0
	elif _was_on_floor:
		_coyote_timer = coyote_time

	if _coyote_timer > 0.0:
		_coyote_timer -= delta

	_was_on_floor = is_on_floor()

func _update_jump(delta: float) -> void:
	if Input.is_action_just_pressed("jump"):
		_jump_buffer_timer = jump_buffer_time

	if _jump_buffer_timer > 0.0:
		_jump_buffer_timer -= delta

	var can_jump := is_on_floor() or _coyote_timer > 0.0

	if _jump_buffer_timer > 0.0 and can_jump:
		velocity.y = jump_velocity
		is_jumping = true
		_coyote_timer = 0.0
		_jump_buffer_timer = 0.0

	# Landing check merged here for simplicity.
	# If landing logic grows, move it to its own method again.
	if is_on_floor() and is_jumping:
		is_jumping = false

func _update_movement(delta: float) -> void:
	var raw_input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var forward := _camera.global_basis.z
	var right := _camera.global_basis.x

	# Combines input with camera axes into a world-space direction.
	# Y zeroed so camera pitch doesn't push the character up or down.
	move_direction = (forward * raw_input.y + right * raw_input.x)
	move_direction.y = 0.0

	# Normalizes so diagonal movement isn't faster.
	move_direction = move_direction.normalized()

	# Smoothly accelerate toward target velocity.
	velocity = velocity.move_toward(move_direction * move_speed, acceleration * delta)

	# Cache last non-zero direction so skin keeps facing forward when the player stops.
	if move_direction.length() > 0.2:
		_last_move_direction = move_direction

	# Rotates the model to face movement direction. 
	# BACK (-Z) is Godot's default model forward.
	# Change to FORWARD if skin was imported facing +Z.
	var target_angle := Vector3.BACK.signed_angle_to(_last_move_direction, Vector3.UP)
	_skin.rotation.y = lerp_angle(_skin.rotation.y, target_angle, rotation_speed * delta)

func _note_tilt_and_sway(move_direction: Vector3, delta: float) -> void:
	if note_hand:
		note_hand.rotation.x = lerp(note_hand.rotation.x, move_direction.y * note_sway_amount, 10*delta)
		note_hand.rotation.z = lerp(note_hand.rotation.z, move_direction.x * note_sway_amount, 10*delta)
