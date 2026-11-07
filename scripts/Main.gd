class_name Main
extends Node

@export var level_scenes: Array[PackedScene] = []

@onready var scene_container: Node = $SceneContainer
@onready var action_menu: ActionMenu = $UI_Layer/ActionMenu
@onready var combat_hud: CombatHUD = $UI_Layer/CombatHUD
@onready var unit_info_card: UnitInfoCard = $UI_Layer/UnitInfoCard
@onready var speech_bubble: SpeechBubble = $UI_Layer/SpeechBubble
@onready var phase_banner: PhaseBanner = $UI_Layer/PhaseBanner

var current_level_index: int = 0
var battle_map: BattleMap = null
var game_ended: bool = false

func _ready() -> void:

	action_menu.action_selected.connect(_on_action_selected)
	action_menu.cancelled.connect(_on_action_cancelled)

	if scene_container.has_node("BattleMap"):
		scene_container.get_node("BattleMap").queue_free()

	load_level(current_level_index)

func load_level(index: int) -> void:
	
	if index < 0 or index >= level_scenes.size():
		return

	if is_instance_valid(battle_map):
		battle_map.queue_free()
		await battle_map.tree_exited

	current_level_index = index
	battle_map = level_scenes[current_level_index].instantiate() as BattleMap
	scene_container.add_child(battle_map)

	_connect_battle_map_signals(battle_map)
	
	battle_map.set_process_unhandled_input(false)
	battle_map.cursor.is_active = false

	if battle_map.victory_condition and "objective_description" in battle_map.victory_condition:
		var objective: String = battle_map.victory_condition.objective_description
		if objective != "":
			phase_banner.show_mission_objective(objective)
			await phase_banner.banner_finished

	battle_map.set_process_unhandled_input(true)
	battle_map.cursor.is_active = true
	
func _connect_battle_map_signals(map: BattleMap) -> void:
	
	map.unit_action_needed.connect(_on_unit_action_needed)
	map.match_won.connect(_on_match_won)
	map.match_lost.connect(_on_match_lost)
	map.combat_forecast_requested.connect(_on_combat_forecast_requested)
	map.combat_forecast_cleared.connect(_on_combat_forecast_cleared)
	map.phase_changed.connect(_on_phase_changed)
	map.cursor_hovered_unit.connect(_on_cursor_hovered_unit)

func _on_unit_action_needed(can_attack: bool, menu_pos: Vector2) -> void:
	
	if not is_instance_valid(battle_map):
		return
	var can_interact: bool = battle_map.can_unit_interact()
	action_menu.open(can_attack, can_interact, menu_pos)

func _on_action_selected(action: String) -> void:
	
	action_menu.close()
	if is_instance_valid(battle_map):
		battle_map.execute_action(action)

func _on_action_cancelled() -> void:
	
	action_menu.close()
	if is_instance_valid(battle_map):
		battle_map.cancel_move()

func _on_combat_forecast_requested(attacker: Unit, defender: Unit) -> void:
	combat_hud.show_forecast(attacker, defender)

func _on_combat_forecast_cleared() -> void:
	combat_hud.clear_forecast()

func _on_cursor_hovered_unit(unit: Unit) -> void:
	
	if unit != null:
		unit_info_card.display_unit(unit)
	else:
		unit_info_card.clear()

func _unhandled_input(event: InputEvent) -> void:
	
	if game_ended and event.is_action_pressed("aceptar"):
		get_viewport().set_input_as_handled()
		get_tree().reload_current_scene()

func _on_match_won() -> void:
	
	unit_info_card.clear()
	if is_instance_valid(battle_map) and battle_map.cursor:
		battle_map.cursor.is_active = false
	battle_map.set_process_unhandled_input(false)

	var next_index: int = current_level_index + 1
	if next_index < level_scenes.size():
		unit_info_card.clear()
		await phase_banner.show_temporary_banner("¡NIVEL SUPERADO!", true, 2.5)
		load_level(next_index)
	else:
		unit_info_card.clear()
		game_ended = true
		phase_banner.show_end_game_banner("¡CAMPAÑA TERMINADA!", true)

func _on_match_lost() -> void:
	
	unit_info_card.clear()
	
	if is_instance_valid(battle_map) and battle_map.cursor:
		battle_map.cursor.is_active = false
	battle_map.set_process_unhandled_input(false)

	game_ended = true
	phase_banner.show_end_game_banner("DERROTA...", false)

func _on_phase_changed(phase: StringName) -> void:
	if phase_banner:
		unit_info_card.clear()
		phase_banner.play_phase_banner(phase)
