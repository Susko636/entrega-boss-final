class_name MapStateGameOver
extends BattleMapState

func enter() -> void:
	map.cursor.is_active = false
	map.cursor.set_process_unhandled_input(false)
	map.cursor.set_process_input(false)
	map.cursor.hide()
	map.overlay_layer.clear()
