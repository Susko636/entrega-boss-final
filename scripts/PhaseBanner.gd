class_name PhaseBanner
extends Control

signal banner_finished

@onready var banner_container: Control = $BannerContainer
@onready var banner_texture: TextureRect = $BannerContainer/BannerTexture
@onready var title_label: Label = $BannerContainer/VBoxContainer/TitleLabel
@onready var desc_label: Label = $BannerContainer/VBoxContainer/DescriptionLabel

const PLAYER_BANNER: Texture2D = preload("res://Assets/Tiny Swords/UI Elements/UI Elements/Ribbons/SmallRibbonsBlue.png") 
const ENEMY_BANNER: Texture2D = preload("res://Assets/Tiny Swords/UI Elements/UI Elements/Ribbons/SmallRibbonsRed.png")
const VICTORY_BANNER: Texture2D = preload("res://Assets/Tiny Swords/UI Elements/UI Elements/Ribbons/BigRibbonsWin.png") 
const DEFEAT_BANNER: Texture2D = preload("res://Assets/Tiny Swords/UI Elements/UI Elements/Ribbons/BigRibbonsDefeat.png")

var _is_waiting_input: bool = false
var _active_tween: Tween = null

func _ready() -> void:
	modulate.a = 0.0
	hide()

func _unhandled_input(event: InputEvent) -> void:
	
	if _is_waiting_input and event.is_action_pressed("aceptar"):
		get_viewport().set_input_as_handled()
		_is_waiting_input = false
		_dismiss_banner()

func show_mission_objective(objective_text: String) -> void:
	
	if _active_tween and _active_tween.is_running():
		_active_tween.kill()

	banner_texture.texture = PLAYER_BANNER
	title_label.text = "OBJETIVO"
	title_label.modulate = Color(1.0, 0.9, 0.4)
	desc_label.text = objective_text
	desc_label.show()

	_play_enter_animation()
	await _active_tween.finished

	_is_waiting_input = true
	while _is_waiting_input:
		await get_tree().process_frame

	banner_finished.emit()

func play_phase_banner(phase_name: StringName) -> void:
	
	if _active_tween and _active_tween.is_running():
		_active_tween.kill()

	_is_waiting_input = false
	desc_label.text = ""
	desc_label.hide()

	if phase_name == &"player" or phase_name == &"PLAYER":
		banner_texture.texture = PLAYER_BANNER
		title_label.text = "FASE ALIADA"
		title_label.modulate = Color(0.9, 0.95, 1.0)
	else:
		banner_texture.texture = ENEMY_BANNER
		title_label.text = "FASE ENEMIGA"
		title_label.modulate = Color(1.0, 0.85, 0.85)

	_play_enter_animation()
	await _active_tween.finished

	await get_tree().create_timer(0.65).timeout

	_dismiss_banner()
	await _active_tween.finished
	banner_finished.emit()

func _play_enter_animation() -> void:
	
	show()
	modulate.a = 0.0
	banner_container.scale = Vector2(0.6, 0.6)

	_active_tween = create_tween().set_parallel(true)
	_active_tween.tween_property(self, "modulate:a", 1.0, 0.22).set_trans(Tween.TRANS_SINE)
	_active_tween.tween_property(banner_container, "scale", Vector2.ONE, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _dismiss_banner() -> void:
	
	_active_tween = create_tween().set_parallel(true)
	_active_tween.tween_property(self, "modulate:a", 0.0, 0.2).set_trans(Tween.TRANS_SINE)
	_active_tween.tween_property(banner_container, "scale", Vector2(1.08, 1.08), 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await _active_tween.finished
	hide()

func show_temporary_banner(title_text: String, is_victory: bool = true, duration: float = 1.8) -> void:
	
	if _active_tween and _active_tween.is_running():
		_active_tween.kill()

	_is_waiting_input = false
	banner_texture.texture = VICTORY_BANNER if is_victory else DEFEAT_BANNER
	
	title_label.text = title_text
	title_label.modulate = Color(0.3, 1.0, 0.4) if is_victory else Color(1.0, 0.3, 0.3)
	
	desc_label.text = ""
	desc_label.hide()

	_play_enter_animation()
	await _active_tween.finished
	await get_tree().create_timer(duration).timeout

	_dismiss_banner()
	await _active_tween.finished
	banner_finished.emit()

func show_end_game_banner(title_text: String, is_victory: bool = false) -> void:
	
	if _active_tween and _active_tween.is_running():
		_active_tween.kill()

	banner_texture.texture = VICTORY_BANNER if is_victory else DEFEAT_BANNER
	
	title_label.text = title_text
	desc_label.text = ""
	desc_label.hide()

	_play_enter_animation()
	await _active_tween.finished
