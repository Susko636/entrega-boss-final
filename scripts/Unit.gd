class_name Unit
extends Node2D

@export var data: CharacterData

@export var color_rect: ColorRect

var grid_coord: Vector2i = Vector2i.ZERO

var current_hp: int = 10
var max_hp: int = 10

var has_acted: bool = false:
	set(value):
		has_acted = value
		modulate = Color(0.5, 0.5, 0.5) if has_acted else Color.WHITE

func _ready() -> void:
	grid_coord = Grid.world_to_grid(position)
	snap_to_grid()
	
	if data:
		max_hp = data.max_hp if "max_hp" in data else 10
		current_hp = max_hp

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
	
func take_damage(amount: int) -> bool:
	current_hp = maxi(0, current_hp - amount)
	print(data.character_name, " recibió ", amount, " de daño. HP restante: ", current_hp, "/", max_hp)
	
	var tween = create_tween()
	tween.tween_property(color_rect, "modulate", Color(2, 2, 2), 0.08)
	tween.tween_property(color_rect, "modulate", Color(1, 1, 1), 0.08)
	
	if current_hp <= 0:
		queue_free()
		return true
	return false
