class_name ActionMenu
extends Control

# Avisa a BattleMap qué acción eligió el jugador ("Atacar" o "Esperar")
signal action_selected(action_name: String)
signal cancelled

@onready var attack_button: Button = $VBoxContainer/AttackButton
@onready var wait_button: Button = $VBoxContainer/WaitButton

func _ready() -> void:
	hide()
	attack_button.pressed.connect(func(): _on_button_pressed("Atacar"))
	wait_button.pressed.connect(func(): _on_button_pressed("Esperar"))

func open(can_attack: bool, screen_pos: Vector2) -> void:
	global_position = screen_pos
	attack_button.visible = can_attack
	show()

	await get_tree().process_frame

	if can_attack:
		attack_button.grab_focus()
	else:
		wait_button.grab_focus()

func close() -> void:
	hide()

func _on_button_pressed(action: String) -> void:
	action_selected.emit(action)

func _unhandled_input(event: InputEvent) -> void:
	if !visible:
		return

	if event.is_action_pressed("mover_arriba"):
		get_viewport().set_input_as_handled()
		if attack_button.visible:
			attack_button.grab_focus()
		return

	if event.is_action_pressed("mover_abajo"):
		get_viewport().set_input_as_handled()
		wait_button.grab_focus()
		return

	if event.is_action_pressed("aceptar"):
		get_viewport().set_input_as_handled()
		var focused = get_viewport().gui_get_focus_owner()
		if focused is Button and (focused == attack_button or focused == wait_button):
			focused.emit_signal("pressed")
		return

	if event.is_action_pressed("cancelar"):
		get_viewport().set_input_as_handled()
		cancelled.emit()
