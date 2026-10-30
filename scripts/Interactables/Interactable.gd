class_name Interactable
extends Node2D

@export var grid_coord: Vector2i = Vector2i.ZERO
@export var is_active: bool = true

func _ready() -> void:
	add_to_group("interactables")
	snap_to_grid()

func snap_to_grid() -> void:
	position = Grid.grid_to_world(grid_coord)

func interact(actor: Unit) -> void:
	pass

func can_interact(actor: Unit) -> bool:
	return is_active
