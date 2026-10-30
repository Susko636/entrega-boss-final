class_name MapStateActionMenu
extends BattleMapState

func enter() -> void:
	
	map.cursor.is_active = false
	map.overlay_layer.clear()

	var can_attack: bool = map.has_adjacent_enemy(map.unit_destination_cell)
	var world_pos: Vector2 = Grid.grid_to_world(map.unit_destination_cell) + Vector2(64, 0)
	var menu_pos: Vector2 = map.get_viewport().get_canvas_transform() * world_pos
	map.unit_action_needed.emit(can_attack, menu_pos)
