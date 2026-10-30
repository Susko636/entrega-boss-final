class_name MapInteractionTrigger
extends Node

@export var trigger_cells: Array[Vector2i] = []
@export var is_active: bool = true

func _ready() -> void:
	add_to_group("interaction_triggers")

func trigger_interaction(_actor: Unit) -> void:
	pass
