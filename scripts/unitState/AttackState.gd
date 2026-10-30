class_name UnitStateAttack
extends UnitState

func enter() -> void:
	if unit.sprite and unit.sprite.sprite_frames and unit.sprite.sprite_frames.has_animation("attack"):
		unit.sprite.play("attack")
