class_name Main
extends Node

@onready var battle_map: BattleMap = $SceneContainer/BattleMap
@onready var action_menu: ActionMenu = $UI_Layer/ActionMenu
@onready var combat_hud: CombatHUD = $UI_Layer/CombatHUD

func _ready() -> void:
	
	battle_map.unit_action_needed.connect(_on_unit_action_needed)
	action_menu.action_selected.connect(_on_action_selected)
	action_menu.cancelled.connect(_on_action_cancelled)
	
	battle_map.combat_forecast_requested.connect(_on_combat_forecast_requested)
	battle_map.combat_forecast_cleared.connect(_on_combat_forecast_cleared)

func _on_unit_action_needed(can_attack: bool, menu_pos: Vector2) -> void:
	action_menu.open(can_attack, menu_pos)

func _on_action_selected(action: String) -> void:
	action_menu.close()
	battle_map.execute_action(action)

func _on_action_cancelled() -> void:
	action_menu.close()
	battle_map.cancel_move()
	
func _on_combat_forecast_requested(attacker: Unit, defender: Unit) -> void:
	combat_hud.display_forecast(attacker, defender)

func _on_combat_forecast_cleared() -> void:
	combat_hud.close()
