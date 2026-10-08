class_name Main
extends Node

@onready var battle_map: BattleMap = $SceneContainer/BattleMap
@onready var action_menu: ActionMenu = $UI_Layer/ActionMenu
@onready var combat_hud: CombatHUD = $UI_Layer/CombatHUD

var game_ended: bool = false

func _ready() -> void:
	
	battle_map.unit_action_needed.connect(_on_unit_action_needed)
	action_menu.action_selected.connect(_on_action_selected)
	action_menu.cancelled.connect(_on_action_cancelled)
	
	battle_map.match_won.connect(_on_match_won)
	battle_map.match_lost.connect(_on_match_lost)
	
	battle_map.combat_forecast_requested.connect(_on_combat_forecast_requested)
	battle_map.combat_forecast_cleared.connect(_on_combat_forecast_cleared)
	
	battle_map.phase_changed.connect(_on_phase_changed)
	
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
	
func _unhandled_input(event: InputEvent) -> void:
	if game_ended and event.is_action_pressed("aceptar"):
		get_viewport().set_input_as_handled()
		get_tree().reload_current_scene()

func _on_match_won() -> void:
	game_ended = true
	_show_end_game_banner("¡VICTORIA!", Color(0.9, 0.8, 0.2))

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

func _on_phase_changed(phase: BattleMap.Phase) -> void:
	var text: String = "FASE ALIADA" if phase == BattleMap.Phase.PLAYER_PHASE else "FASE ENEMIGA"
	var bg_color: Color = Color(0.1, 0.3, 0.8, 0.85) if phase == BattleMap.Phase.PLAYER_PHASE else Color(0.8, 0.15, 0.15, 0.85)
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
