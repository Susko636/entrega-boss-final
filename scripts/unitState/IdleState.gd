class_name UnitStateIdle
extends UnitState

func enter() -> void:
	if unit.sprite and unit.sprite.sprite_frames and unit.sprite.sprite_frames.has_animation("idle"):
		unit.sprite.play("idle")
