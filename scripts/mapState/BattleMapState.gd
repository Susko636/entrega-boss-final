class_name BattleMapState
extends RefCounted

var map: BattleMap

func enter() -> void:
	pass

func exit() -> void:
	pass

func on_cursor_cell_changed(_cell: Vector2i) -> void:
	pass

func on_cursor_accept(_cell: Vector2i) -> void:
	pass

func on_cursor_cancel(_cell: Vector2i) -> void:
	pass
