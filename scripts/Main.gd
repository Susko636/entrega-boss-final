class_name Main
extends Node

@export var level_scenes: Array[PackedScene] = []

@onready var scene_container: Node = $SceneContainer
@onready var action_menu: ActionMenu = $UI_Layer/ActionMenu
@onready var combat_hud: CombatHUD = $UI_Layer/CombatHUD
@onready var unit_info_card: UnitInfoCard = $UI_Layer/UnitInfoCard
@onready var speech_bubble: SpeechBubble = $UI_Layer/SpeechBubble

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
	combat_hud.display_forecast(attacker, defender)

func _on_combat_forecast_cleared() -> void:
	combat_hud.close()

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
	
	var next_index: int = current_level_index + 1
	if next_index < level_scenes.size():
		_show_phase_banner("¡NIVEL COMPLETADO!", Color(0.2, 0.7, 0.3, 0.9))
		await get_tree().create_timer(1.2).timeout
		load_level(next_index)
	else:
		game_ended = true
		_show_end_game_banner("¡CAMPAÑA COMPLETADA!", Color(0.9, 0.8, 0.2))

func _on_match_lost() -> void:
	
	game_ended = true
	_show_end_game_banner("DERROTA...", Color(0.9, 0.2, 0.2))

func _show_end_game_banner(title_text: String, title_color: Color) -> void:
	
	var overlay = CenterContainer.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)

	var title_label = Label.new()
	title_label.text = title_text
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.modulate = title_color
	title_label.add_theme_font_size_override("font_size", 16)

	var subtitle_label = Label.new()
	subtitle_label.text = "Presiona Aceptar para reiniciar"
	subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle_label.add_theme_font_size_override("font_size", 8)

	vbox.add_child(title_label)
	vbox.add_child(subtitle_label)
	overlay.add_child(vbox)

	$UI_Layer.add_child(overlay)

func _on_phase_changed(phase: StringName) -> void:
	
	var text: String = "FASE ALIADA" if phase == TurnManager.PHASE_PLAYER else "FASE ENEMIGA"
	var bg_color: Color = Color(0.1, 0.3, 0.8, 0.85) if phase == TurnManager.PHASE_PLAYER else Color(0.8, 0.15, 0.15, 0.85)
	_show_phase_banner(text, bg_color)

func _show_phase_banner(text: String, background_color: Color) -> void:
	
	var banner = PanelContainer.new()
	banner.set_anchors_preset(Control.PRESET_CENTER)
	banner.custom_minimum_size = Vector2(0, 32)
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var style_box = StyleBoxFlat.new()
	style_box.bg_color = background_color
	style_box.content_margin_top = 4
	style_box.content_margin_bottom = 4
	banner.add_theme_stylebox_override("panel", style_box)

	var label = Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 11)
	banner.add_child(label)

	$UI_Layer.add_child(banner)

	banner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	banner.anchor_left = 0.0
	banner.anchor_right = 1.0
	banner.offset_left = 0
	banner.offset_right = 0

	banner.modulate.a = 0.0
	var tween: Tween = create_tween()
	tween.tween_property(banner, "modulate:a", 1.0, 0.2)
	tween.tween_interval(0.6)
	tween.tween_property(banner, "modulate:a", 0.0, 0.2)
	tween.tween_callback(banner.queue_free)
