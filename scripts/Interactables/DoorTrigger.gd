class_name DoorTrigger
extends MapInteractionTrigger

@export var door_collider: CollisionShape2D

func trigger_interaction(actor: Unit) -> void:
	if not is_active:
		return
	if door_collider:
		door_collider.set_deferred("disabled", true)
	is_active = false
