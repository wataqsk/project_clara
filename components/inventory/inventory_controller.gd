class_name InventoryController
extends Control

@onready var player_camera: Node3D = $"../../../CameraPivot"
@onready var interaction_controller: Node = $"../../../InteractionController"
@onready var interaction_hand: Marker3D = $"../../../CameraPivot/InteractionHand"
@onready var inventory_grid: GridContainer = %GridContainer
@onready var context_menu: PopupMenu = PopupMenu.new()

var item_slots_count: int = 20
var inventory_slot_prefab: PackedScene = load("res://components/inventory/inventory_slot.tscn")
var inventory_slots: Array[InventorySlot] = []
var inventory_full: bool = false

func _ready() -> void:
	# Populate the inventory with inventory slots. 
	# Attach all necessary signals.
	for i in item_slots_count:
		var slot = inventory_slot_prefab.instantiate() as InventorySlot
		inventory_grid.add_child(slot)
		slot.inventory_slot_id = i
		slot.on_item_swapped.connect(_on_item_swapped_on_slot)
		slot.on_item_double_clicked.connect(_on_item_double_clicked)
		slot.on_item_right_clicked.connect(_on_slot_right_clicked)
		inventory_slots.append(slot)

	# Initialize the context menu for right clicks.
	add_child(context_menu)
	context_menu.connect("id_pressed", Callable(self, "_on_context_menu_selected"))

## Helper method that returns true if there is any free inventory slots. 
## False if the inventory is full
func has_free_slot() -> bool:
	for slot in inventory_slots:
		if slot.slot_data == null:
			return true
	return false

## Places and item into the player inventory.
func pickup_item(item_data: ItemData) -> void:
	for slot in inventory_slots:
		if not slot.slot_filled:
			slot.fill_slot(item_data)
			inventory_full = not has_free_slot()
			return
	inventory_full = true

## Switches the place of two items in the inventory.
func _on_item_swapped_on_slot(from_slot_id: int, to_slot_id: int) -> void:
	var to_slot_item: ItemData = inventory_slots[to_slot_id].slot_data
	var from_slot_item: ItemData = inventory_slots[from_slot_id].slot_data
	inventory_slots[to_slot_id].fill_slot(from_slot_item)
	inventory_slots[from_slot_id].fill_slot(to_slot_item)

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	var slot: InventorySlot = inventory_slots[data]
	if slot.slot_data == null:
		return false
	return true

## Remove a given item from the inventory and spawns it back into the world.
func _drop_data(_at_position: Vector2, data: Variant) -> void:
	drop_collectable(data)
	inventory_full = not has_free_slot()

## Auto runs the "use/equip/view" option for this slot.
func _on_item_double_clicked(slot_id: int) -> void:
	var slot: InventorySlot = inventory_slots[slot_id]

	# If the slot is empty, dont perform any action.
	if slot.slot_data == null:
		return

	match _get_item_action_type(slot.slot_data):
		ActionData.ActionType.CONSUMABLE:
			# use_collectable(slot_id)
			print("Use Collectable")
		ActionData.ActionType.EQUIPPABLE:
			# equip_collectable(slot_id)
			print("Equip Collectable")
		ActionData.ActionType.INSPECTABLE:
			# inspect_collectable(slot_id)
			print("Inspect Collectable")

## Displays the context menu options specific to the given item type.
func _on_slot_right_clicked(slot_id: int) -> void:
	var slot: InventorySlot = inventory_slots[slot_id]
	
	# If the slot is empty, dont perform any action
	if slot.slot_data == null:
		return

	context_menu.clear()
	match _get_item_action_type(slot.slot_data):
		ActionData.ActionType.CONSUMABLE:
			context_menu.add_item("Use", 0)
			context_menu.add_item("Drop", 1)
		ActionData.ActionType.EQUIPPABLE:
			context_menu.add_item("Equip", 0)
			context_menu.add_item("Drop", 1)
		ActionData.ActionType.INSPECTABLE:
			context_menu.add_item("View", 0)
			context_menu.add_item("Drop", 1)

	# Put the slot_id in the meta data to be read when the player selects something.
	# The context menu doesnt automatically know which inventory slot its been displayed for.
	context_menu.set_meta("slot_id", slot_id)

	# Show the context menu relative to where the players mouse is.
	var mouse_pos: Vector2 = get_viewport().get_mouse_position()
	var rect: Rect2i = Rect2i(mouse_pos.floor(), Vector2i(1,1))
	context_menu.popup(rect)

## Performs whatever action the player chose from the context menu.
func _on_context_menu_selected(context_menu_choice: int) -> void:
	# Read in which inventory slot we are acting on.
	var slot_id = context_menu.get_meta("slot_id")
	var slot: InventorySlot = inventory_slots[slot_id]

	# If the slot is empty, dont perform any action.
	if slot.slot_data == null:
		return

	match _get_item_action_type(slot.slot_data): 
		ActionData.ActionType.CONSUMABLE:
			match context_menu_choice:
				0:  # use_collectable(slot_id)
					print("Use collectable.")
				1: drop_collectable(slot_id)
		ActionData.ActionType.EQUIPPABLE:
			match context_menu_choice:
				0: # equip_collectable(slot_id)
					print("Equip collectable.")
				1: drop_collectable(slot_id)
		ActionData.ActionType.INSPECTABLE:
			match context_menu_choice:
				0: # inspect_collectable(slot_id)
					print("Inspect collectable.")
				1: drop_collectable(slot_id)

## Use's a given collectable from the inventory. 
## Modifier actions are defind here
func use_collectable(slot_id: int) -> void:
	var slot: InventorySlot = inventory_slots[slot_id]
	var item_data: ItemData = slot.slot_data
	if slot.slot_data == null:
		return

	# Cache the item's action data.
	var action_data: ActionData = slot.slot_data.action_data

	# Health system not yet implemented.
	# Call the respective controller to handle the modifier's action
	# match action_data.modifier_name:
	# 	"health":
	# 		health_controller.add_health(action_data.modifier_value)

	# Collectable has been used, the inventory is no longer full
	inventory_full = false
	# Make the slot empty again
	slot.fill_slot(null)

## Drops the item from the provided slot, assuming it will be placed in a valid position.
## Otherwise, it remains in the inventory
func drop_collectable(slot_id: int) -> void:
	var slot: InventorySlot = inventory_slots[slot_id]
	var item_data: ItemData = slot.slot_data
	if item_data == null:
		return

	# Create an instance of the item based on its prefab and add it into the scene tree.
	var instance: PhysicsBody3D = item_data.item_model_prefab.instantiate() as PhysicsBody3D
	get_tree().current_scene.add_child(instance)

	# Get the space state
	var space_state: PhysicsDirectSpaceState3D  = player_camera.get_world_3d().direct_space_state

	# Determine if there are any obstacles preventing the player from dropping this object.
	# Draw a vector from the players face.
	var drop_distance: float = 2.0
	var forward_dir: Vector3 = -player_camera.global_transform.basis.z.normalized()
	var target_pos: Vector3 = player_camera.global_transform.origin + forward_dir * drop_distance

	# Check if the forward vector collides with anything.
	var obstacle_params = PhysicsRayQueryParameters3D.new()
	obstacle_params.from = player_camera.global_transform.origin
	obstacle_params.to = target_pos
	obstacle_params.exclude = [player_camera]

	# If there is an obstacle in the way (i.e. a wall) then do NOT drop the item.
	var obstacle_hit: Dictionary = space_state.intersect_ray(obstacle_params)
	if not obstacle_hit.is_empty():
		print("Cannot drop: path blocked")
		instance.queue_free()
		return

	# Draw a vector from the forward point, down to the ground.
	var ground_params = PhysicsRayQueryParameters3D.new()
	ground_params.from = target_pos + Vector3.UP * 2.0
	ground_params.to = target_pos - Vector3.UP * 5.0
	ground_params.exclude = [player_camera]

	# If there is ground in front of the player. (i.e. not dropping item off a cliff)
	var ground_hit: Dictionary = space_state.intersect_ray(ground_params)
	if not ground_hit:
		print("Cannot drop: no ground")
		instance.queue_free()
		return

	# Cache the valid place to drop an item.
	var ground_pos: Vector3 = ground_hit.position

	# Add some height to the object when it is dropped so there is movement to it.
	var buffer_height: float = 0.7

	# Place instance into the world physically
	if instance is RigidBody3D:
		# If the object is a rigid body, it can move/roll. 
		# Apply the buffer height to generate movement on impact.
		instance.global_transform.origin = ground_pos + Vector3.UP * buffer_height
		instance.freeze = false
		instance.gravity_scale = 1.0
		instance.rotation_degrees.x = randf() * 360
		instance.rotation_degrees.z = randf() * 360
	else:
		# If the object is a static body, it cant move or roll. 
		# Simply place it on the ground, with a small height.
		# increase to ensure there is no z-clipping with the floor.
		instance.global_transform.origin = ground_pos + Vector3.UP * 0.0001

	# Rotate item randomly on Y for variety.
	instance.rotation_degrees.y = randf() * 360

	# Collectable has been used, the inventory is no longer full.
	inventory_full = false
	# Make the slot empty again.
	slot.fill_slot(null)

## Helper method to return what type of action this item is expected to perform
func _get_item_action_type(item_data: ItemData) -> ActionData.ActionType:
	# If the item_data or its prefab are null, return invalid
	if not item_data or not item_data.item_model_prefab == null:
		return ActionData.ActionType.INVALID

	return item_data.action_data.action_type
