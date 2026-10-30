class_name UnitStateWalk
extends UnitState

func enter() -> void:
	
	if unit.sprite and unit.sprite.sprite_frames and unit.sprite.sprite_frames.has_animation("walk"):
		unit.sprite.play("walk")
