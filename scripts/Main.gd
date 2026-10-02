class_name Main
extends Node

@onready var battle_map: BattleMap = $SceneContainer/BattleMap
@onready var action_menu: ActionMenu = $UI_Layer/ActionMenu

func _ready() -> void:
	# Conectamos las señales del mapa y del menú
	battle_map.unit_action_needed.connect(_on_unit_action_needed)
	action_menu.action_selected.connect(_on_action_selected)
	action_menu.cancelled.connect(_on_action_cancelled)

# Se ejecuta cuando la unidad termina de caminar y necesita elegir acción
func _on_unit_action_needed(can_attack: bool, menu_pos: Vector2) -> void:
	action_menu.open(can_attack, menu_pos)

# Se ejecuta cuando el jugador elige "Atacar" o "Esperar"
func _on_action_selected(action: String) -> void:
	action_menu.close()
	battle_map.execute_action(action)

# Se ejecuta si el jugador cancela el menú para deshacer el movimiento
func _on_action_cancelled() -> void:
	action_menu.close()
	battle_map.cancel_move()
