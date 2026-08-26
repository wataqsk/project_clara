# This script handles player interaction, detecting and triggering interactions.
# Object behavior and properties are defined in InteractionComponent, not here.
extends Node

@onready var interaction_controller: Node = %InteractionController
@onready var interaction_raycast: RayCast3D = %InteractionRaycast
@onready var player_camera: Camera3D = %Camera3D
@onready var interaction_hand: Marker3D = %InteractionHand
@onready var note_hand: Marker3D = %NoteHand
@onready var notes_overlay: Control = %NotesOverlay
@onready var note_content: RichTextLabel = %NoteContent

@onready var interactable_check: Area3D = $"../InteractableCheck"
@onready var inventory_controller: Node = %InventoryController/CanvasLayer/InventoryUI

@onready var default_reticle: TextureRect = %DefaultReticle
@onready var highlight_reticle: TextureRect = %HighlightReticle
@onready var interacting_reticle: TextureRect = %InteractingReticle

@onready var outline_material: Material = preload("res://materials/item_highlighter.tres")

var current_object: Object = null
var last_potential_object: Object = null
var interaction_component: Node = null
var _is_note_overlay_display: bool = false

signal invent_on_item_collected(item)

func _ready() -> void:
	# Centers each reticle on screen based on the viewport size and the reticle's texture size.
	default_reticle.position.x     = get_viewport().size.x / 2 - default_reticle.texture.get_size().x     / 2
	default_reticle.position.y     = get_viewport().size.y / 2 - default_reticle.texture.get_size().y     / 2
	highlight_reticle.position.x   = get_viewport().size.x / 2 - highlight_reticle.texture.get_size().x   / 2
	highlight_reticle.position.y   = get_viewport().size.y / 2 - highlight_reticle.texture.get_size().y   / 2
	interacting_reticle.position.x = get_viewport().size.x / 2 - interacting_reticle.texture.get_size().x / 2
	interacting_reticle.position.y = get_viewport().size.y / 2 - interacting_reticle.texture.get_size().y / 2

	# Tells a Control node to ignore mouse or touch events.
	# You'll need it if you place an icon on top of a button.
	default_reticle.mouse_filter     = Control.MOUSE_FILTER_IGNORE
	highlight_reticle.mouse_filter   = Control.MOUSE_FILTER_IGNORE
	interacting_reticle.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Connect this signal to the inventory's pickup handler.
	invent_on_item_collected.connect(inventory_controller.pickup_item)

	# Connect signals for entering and exiting the interactable check radius.
	interactable_check.body_entered.connect(_on_body_entered)
	interactable_check.body_exited.connect(_on_body_exited)

func _process(_delta: float) -> void:
	# Block interaction entirely while the inventory is open.
	if inventory_controller.visible:
		default_reticle.visible = false
		highlight_reticle.visible = false
		interacting_reticle.visible = false
		current_object = null
		return

	# Show the interacting reticle while the player is actively using the object.
	if interaction_component and interaction_component.is_interacting:
		_show_interacting_reticle()

	# If an object was being interacted with last frame, continue interacting this frame.
	if current_object:
		# End the interaction if the player moves too far from the object.
		if player_camera.global_transform.origin.distance_to(current_object.global_transform.origin) > interaction_component.max_interact_distance:
			if interaction_component:
				interaction_component.post_interact()
			current_object = null
			_show_default_reticle()

		if Input.is_action_pressed("right_click"):
			if interaction_component:
				interaction_component.alt_interact()
				current_object = null
				_show_default_reticle()
		elif Input.is_action_pressed("left_click"):
			if interaction_component:
				interaction_component.interact()
		# With input released, end the interaction and reset state.
		else:
			if interaction_component:
				interaction_component.post_interact()
				current_object = null
				# Interaction ended, go back to the default reticle.
				_show_default_reticle()

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

				last_potential_object = current_object
				# Looking at an interactable object, show the highlight reticle.
				_show_highlight_reticle()

				# Begin interaction when the player clicks on the object.
				# is_action_just_pressed prevents the raycast from triggering pickup multiple times in one click.
				if Input.is_action_just_pressed("left_click"):
					current_object = potential_object
					interaction_component.pre_interact(interaction_hand)

					# When picking up an item, connect its collected signal to this script.
					if interaction_component.interaction_type == interaction_component.InteractionType.ITEM:
						interaction_component.connect("item_collected", Callable(self, "_on_item_collected"))

					if interaction_component.interaction_type == interaction_component.InteractionType.NOTE:
						interaction_component.connect("note_collected", Callable(self, "_on_note_collected"))
		else:
			# Not looking at anything interactable, show the default reticle.
			_show_default_reticle()

func _input(event: InputEvent) -> void:
	if _is_note_overlay_display and event.is_action_just_pressed("left_click"):
		notes_overlay.visible = false
		_is_note_overlay_display = false
		var children = note_hand.get_children()
		for child in children:
			child.queue_free()

# TO-DO: Refactor into an enum-based method to avoid repetition.
func _show_default_reticle() -> void:
	default_reticle.visible = true
	highlight_reticle.visible = false
	interacting_reticle.visible = false

func _show_highlight_reticle() -> void:
	default_reticle.visible = false
	highlight_reticle.visible = true
	interacting_reticle.visible = false

func _show_interacting_reticle() -> void:
	default_reticle.visible = false
	highlight_reticle.visible = false
	interacting_reticle.visible = true

func _on_item_collected(item: Node) -> void:
	# Hide immediately so it doesn't flicker while queue_free() processes.
	item.visible = false
	_add_item_to_inventory(interaction_component.item_data)
	item.queue_free()

func _on_note_collected(note: Node3D) -> void:
	note.get_parent().remove_child(note)
	note_hand.add_child(note)
	note.transform.origin = note_hand.transform.origin
	note.position = Vector3(0.0, 0.0, 0.0)
	note.rotation_degrees = Vector3	(90, 10, 0)
	notes_overlay.visible = true
	_is_note_overlay_display = true
	var ic = note.get_node_or_null("InteractionComponent")
	note_content.bbcode_enabled = true
	note_content.text = ic.content

func _add_item_to_inventory(item_data: ItemData) -> void:
	# Only forward valid item data to the inventory, silently ignore otherwise.
	if item_data != null:
		invent_on_item_collected.emit(item_data)
		return
	print("ItemData not found.")

func on_item_equipped(item: Node3D) -> void:
	if item.get_parent() != null:
		item.get_parent().remove_child(item)
	else:
		var mesh = item.find_child("MeshInstance3D", true, false)
		if mesh:
			mesh.layers = 2
		var col = item.find_child("CollisionShape3D", true, false)
		if col:
			col.get_parent().remove_child(col)
			col.queue_free()

func _on_body_entered(body: Node3D) -> void:
	# Ignore the player itself entering the check radius.
	if body.name != "Player":
		var ic = body.get_node_or_null("InteractionComponent")
		# Only outline items and ignore other interactable types.
		if ic and ic.interaction_type == ic.InteractionType.ITEM:
			var mesh: MeshInstance3D = body.find_child("MeshInstance3D", true, false)
			mesh.material_overlay = outline_material

func _on_body_exited(body: Node3D) -> void:
	if body.name != "Player":
		var mesh: MeshInstance3D = body.find_child("MeshInstance3D", true, false)
		# Remove the outline if the object had one.
		if mesh:
			mesh.material_overlay = null
