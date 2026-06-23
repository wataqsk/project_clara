# TO-DO: Add input buffering.
# TO-DO: Add jump cooldown.
# TO-DO: Remove hardcoded walking-down speed and walking-up-ramps speed.
# TO-DO: Tilt character sprite when walking up and down ramps.
# TO-DO: Find a way to handle stairs. Maybe: 2-raycast method or a plugin.
class_name Player extends CharacterBody3D

@export_category("Camera")
@export_group("Camera Sensitivity")
## How sensitive the camera is to mouse movement.
@export_range(0.0, 1.0, 0.05, "suffix:x") var camera_sensitivity: float = 0.25

@export_group("Camera Pitch")
## Maximum downward angle the camera can look.
@export_range(-90.0, 0.0, 5.0, "suffix:°") var camera_pitch_min : float = -30.0
## Maximum upward angle the camera can look.
@export_range(0.0, 90.0, 5.0, "suffix:°") var camera_pitch_max : float = 60.0


@export_category("Movement")
@export_group("Character Speed")
## How fast the character can move.
@export_range(0.0, 20.0, 0.5, "suffix:m/s") var move_speed : float = 8.0
## Acceleration controls how quickly the character reaches move_speed.
## Instead of hitting full speed in one frame, it ramps up smoothly.
## For example, the character reaches full speed in 0.4 seconds (8.0 / 20.0).
@export_range(0.0, 40.0, 0.5, "suffix:m/s²") var acceleration : float = 20.0
## Velocity threshold below which the character snaps to a stop.
@export_range(0.0, 2.0, 0.01, "suffix:m/s") var stopping_speed : float = 1.0

@export_group("Character Jump")
## How fast the character launches upward when jumping.
@export_range(0.0, 25.0, 0.5, "suffix:m/s") var jump_velocity : float = 12.0
## Short period after walking off a ledge where the player can still jump.
@export_range(0.0, 0.2, 0.01, "suffix:s") var coyote_time : float = 0.1

@export_group("Character Skin")
## How fast the character model rotates to face the movement direction.
@export_range(1.0, 20.0, 0.5, "suffix:°/s") var rotation_speed : float = 8.0

@export_group("Character Gravity")
## Multiplies character's gravity while falling.
@export_range(1.0, 10.0, 0.5, "suffix:x") var fall_multiplier: float = 4.0

@onready var _camera_pivot: Node3D = %CameraPivot
@onready var _camera: Camera3D = %Camera3D
@onready var _skin: Node3D = %Mannequin

var _camera_input_direction: Vector2 = Vector2.ZERO
# move_direction must be public because state_machine reads it.
# I couldn't find a way to work around this.
var move_direction: Vector3 = Vector3.ZERO
var _last_move_direction: Vector3 = Vector3.BACK
var _is_jumping: bool = false
var _was_on_floor: bool = false
var _coyote_timer: float = 0.0
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var state_machine: AnimationNodeStateMachinePlayback

func _ready() -> void:
	state_machine = $AnimationTree.get("parameters/Movement/playback") as AnimationNodeStateMachinePlayback

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		var is_captured = Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if is_captured else Input.MOUSE_MODE_CAPTURED

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
	_update_jump()
	_update_gravity(delta)
	move_and_slide()
	_update_debug()

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

func _update_jump() -> void:
	var can_jump := is_on_floor() or _coyote_timer > 0.0
	
	if Input.is_action_just_pressed("jump") and can_jump:
		velocity.y = jump_velocity
		_is_jumping = true
		_coyote_timer = 0.0

	# Landing check merged here for simplicity.
	# If landing logic grows, move it to its own method again.
	if is_on_floor() and _is_jumping:
		_is_jumping = false

func _update_movement(delta: float) -> void:
	var raw_input := Input.get_vector("move_left", "move_right", "move_up", "move_down")

	var forward := _camera.global_basis.z
	var right := _camera.global_basis.x
	
	move_direction = (forward * raw_input.y + right * raw_input.x)
	move_direction.y = 0.0

	# Cache direction before normalizing, skin keeps facing last direction when player stops.
	if move_direction.length_squared() > 0.0:
		_last_move_direction = move_direction.normalized()
		move_direction = move_direction.normalized()

	velocity = velocity.move_toward(move_direction * move_speed, acceleration * delta)
	
	# BACK (-Z) is Godot's default model forward
	# Change to FORWARD if skin was imported facing +Z
	var target_angle := Vector3.BACK.signed_angle_to(_last_move_direction, Vector3.UP)
	# lerp_angle is better than lerp for some magical reason...
	_skin.rotation.y = lerp_angle(_skin.rotation.y, target_angle, rotation_speed * delta)
 
	# This was causing the falling slowly problem.
	# Only the horizontal axis must be zero.
	if is_equal_approx(move_direction.length_squared(), 0.0) and velocity.length_squared() < stopping_speed:
		velocity.x = 0.0
		velocity.z = 0.0

func _update_debug() -> void:
	DebugDraw2D.set_text("FPS", Engine.get_frames_per_second())
	DebugDraw2D.set_text("Floor", "Yes" if is_on_floor() else "No")
