class_name MapStateIdle
extends BattleMapState

func enter() -> void:
	map.cursor.is_active = true
	map.overlay_layer.clear()

func on_cursor_accept(cell: Vector2i) -> void:
	if map.units_by_cell.has(cell):
		var unit: Unit = map.units_by_cell[cell]
		if unit.faction == Unit.Faction.PLAYER and not unit.has_acted:
			map.selected_unit = unit
			map.unit_original_cell = unit.grid_coord
			map.change_map_state(&"move")
