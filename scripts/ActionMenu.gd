class_name ActionMenu
extends Control

signal action_selected(action_name: String)
signal cancelled
signal interact_selected

@onready var attack_button: Button = $MenuContainer/VBoxContainer/AttackButton
@onready var wait_button: Button = $MenuContainer/VBoxContainer/WaitButton
@onready var interact_button: Button = $MenuContainer/VBoxContainer/InteractButton

func _ready() -> void:
	
	hide()
	attack_button.pressed.connect(func(): _on_button_pressed("Atacar"))
	wait_button.pressed.connect(func(): _on_button_pressed("Esperar"))
	interact_button.pressed.connect(func(): _on_button_pressed("Interactuar"))
	
func open(can_attack: bool, can_interact: bool, screen_pos: Vector2) -> void:

	attack_button.visible = can_attack
	interact_button.visible = can_interact
	
	var viewport_size: Vector2 = get_viewport_rect().size
	var estimated_menu_size: Vector2 = Vector2(80, 50)
	
	var final_pos: Vector2 = screen_pos
	if final_pos.x + estimated_menu_size.x > viewport_size.x:
		final_pos.x -= (64 + estimated_menu_size.x) 
	if final_pos.y + estimated_menu_size.y > viewport_size.y:
		final_pos.y -= estimated_menu_size.y

	global_position = final_pos
	show()

	await get_tree().process_frame

	if can_attack:
		attack_button.grab_focus()
	elif can_interact:
		interact_button.grab_focus()
	else:
		wait_button.grab_focus()

func close() -> void:
	hide()

func _on_button_pressed(action: String) -> void:
	action_selected.emit(action)
	if action == "Interactuar":
		interact_selected.emit()

func _unhandled_input(event: InputEvent) -> void:
	if !visible:
		return
		
	var visible_buttons: Array[Button] = _get_visible_buttons()
	if visible_buttons.is_empty():
		return

	var current_focus: Control = get_viewport().gui_get_focus_owner()
	var current_idx: int = visible_buttons.find(current_focus)

	if event.is_action_pressed("mover_abajo"):
		get_viewport().set_input_as_handled()
		if current_idx < visible_buttons.size() - 1:
			visible_buttons[current_idx + 1].grab_focus()
		return

	if event.is_action_pressed("mover_arriba"):
		get_viewport().set_input_as_handled()
		if current_idx > 0:
			visible_buttons[current_idx - 1].grab_focus()
		return

	if event.is_action_pressed("aceptar"):
		get_viewport().set_input_as_handled()
		var focused = get_viewport().gui_get_focus_owner()
		if focused is Button and (focused == attack_button or focused == wait_button or focused == interact_button):
			focused.emit_signal("pressed")
		return

	if event.is_action_pressed("cancelar"):
		get_viewport().set_input_as_handled()
		cancelled.emit()

func setup_interact(can_interact: bool) -> void:

	interact_button.visible = can_interact
	# interact_button.disabled = not can_interact

func _get_visible_buttons() -> Array[Button]:
	var list: Array[Button] = []
	for btn in [attack_button, interact_button, wait_button]:
		if is_instance_valid(btn) and btn.visible:
			list.append(btn)
	return list
