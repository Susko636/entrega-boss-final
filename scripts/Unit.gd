class_name Unit
extends Node2D

@export var data: CharacterData

var grid_coord: Vector2i = Vector2i.ZERO

var has_acted: bool = false:
	set(value):
		has_acted = value
		modulate = Color(0.5, 0.5, 0.5) if has_acted else Color.WHITE
		
func _ready() -> void:
	grid_coord = Grid.world_to_grid(position)
	snap_to_grid()

func snap_to_grid() -> void:
	position = Grid.grid_to_world(grid_coord)


func follow_path(path: Array[Vector2i]) -> Signal:
	
	if path.is_empty():
		return get_tree().process_frame

	grid_coord = path.back()
	var tween: Tween = create_tween()

	for cell_step in path:
		var step_pos: Vector2 = Grid.grid_to_world(cell_step)
		tween.tween_property(self, "position", step_pos, 0.12).set_trans(Tween.TRANS_LINEAR)

	return tween.finished
