class_name InventoryController
extends Control

var item_slots_count: int = 20
var inventory_slot_prefab: PackedScene = load("res://components/inventory/inventory_slot.tscn")
@onready var inventory_grid: GridContainer = %GridContainer
var inventory_slots: Array[InventorySlot] = []
var inventory_full: bool = false

func _ready() -> void:
	for i in item_slots_count:
		var slot = inventory_slot_prefab.instantiate() as InventorySlot
		inventory_grid.add_child(slot)
		# add the slot id
		# link the drag / drop / use
		inventory_slots.append(slot)
