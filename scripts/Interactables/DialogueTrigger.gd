class_name DialogueTrigger
extends MapInteractionTrigger

@export_multiline var dialogue_text: String = "¡Holaa!"

func trigger_interaction(actor: Unit) -> void:
	if not is_active:
		return
	
	# Obtenemos la SpeechBubble del árbol de UI
	var bubble: SpeechBubble = actor.get_tree().get_first_node_in_group("speech_bubble")
	if not bubble:
		# Fallback por si todavía no la asignaste al grupo
		bubble = actor.get_node_or_null("/root/Main/UI_Layer/SpeechBubble")
	
	if not bubble:
		print("DEBUG DIALOGUE: %s" % dialogue_text)
		return
	
	# Usamos la primera celda del trigger (donde está el NPC o puerta) para ubicar el globo
	var target_cell: Vector2i = trigger_cells[0] if not trigger_cells.is_empty() else actor.grid_coord
	var world_pos: Vector2 = Grid.grid_to_world(target_cell)
	var screen_pos: Vector2 = actor.get_viewport().get_canvas_transform() * world_pos
	
	# Mostramos el globo y esperamos a que el usuario presione 'Aceptar'
	bubble.display_text(dialogue_text, screen_pos)
	await bubble.closed
