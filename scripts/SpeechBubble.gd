class_name SpeechBubble
extends PanelContainer

signal closed

@onready var text_label: Label = $TextLabel

var is_waiting_input: bool = false

func _ready() -> void:
	
	hide()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_to_group("speech_bubble")

func display_text(text: String, screen_pos: Vector2) -> void:
	text_label.text = text
	show()
	
	await get_tree().process_frame
	
	var bubble_size: Vector2 = size
	global_position = Vector2(
		screen_pos.x - (bubble_size.x / 2.0),
		screen_pos.y - bubble_size.y - 12.0 
	)
	
	var tween = create_tween().set_parallel(true)
	tween.tween_property(self, "scale", Vector2.ONE, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 1.0, 0.1)
	
	await tween.finished
	is_waiting_input = true

func _unhandled_input(event: InputEvent) -> void:
	
	if not visible or not is_waiting_input:
		return
	
	if event.is_action_pressed("aceptar"):
		get_viewport().set_input_as_handled()
		close()

func close() -> void:
	
	is_waiting_input = false
	var tween = create_tween().set_parallel(true)
	tween.tween_property(self, "scale", Vector2(0.5, 0.5), 0.1)
	tween.tween_property(self, "modulate:a", 0.0, 0.1)
	await tween.finished
	hide()
	closed.emit()
