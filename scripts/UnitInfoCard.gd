class_name UnitInfoCard
extends Control

@onready var class_icon: Sprite2D = %IconClass
@onready var name_label: Label = %Name

@onready var hp_progress_bar: TextureProgressBar = %HpProgressBar
@onready var hp_label: Label = %Hp

@onready var atk_value: Label = %Atk
@onready var def_value: Label = %Def
@onready var range_value: Label = %Range

const CLASS_ICONS: Dictionary = {
	"Warrior": preload("res://Assets/Tiny Swords/UI Elements/UI Elements/Human Avatars/Avatars_01.png"),
	"Lancer": preload("res://Assets/Tiny Swords/UI Elements/UI Elements/Human Avatars/Avatars_02.png"),
	"Archer": preload("res://Assets/Tiny Swords/UI Elements/UI Elements/Human Avatars/Avatars_03.png"),
	"Monk": preload("res://Assets/Tiny Swords/UI Elements/UI Elements/Human Avatars/Avatars_04.png"),
	"Prota": preload("res://Assets/Tiny Swords/UI Elements/UI Elements/Human Avatars/Avatars_05.png"),
	"GoblinTorch": preload("res://Assets/Tiny Swords/Enemys/Goblings/Avatar_goblin_torch.png"),
	"GoblinDynamite": preload("res://Assets/Tiny Swords/Enemys/Goblings/Avatar_goblin_dynamite.png")
}

var _monitored_unit: Unit = null

func display_unit(unit: Unit) -> void:
	
	if unit == null:
		clear()
		return

	if _monitored_unit == unit:
		_refresh_stats()
		return

	_disconnect_current_unit()
	_monitored_unit = unit

	if is_instance_valid(_monitored_unit):
		_monitored_unit.damage_taken.connect(_on_unit_damage_taken)
		_monitored_unit.tree_exiting.connect(clear)

	_refresh_display()
	show()

func _refresh_display() -> void:
	
	if not is_instance_valid(_monitored_unit):
		clear()
		return

	name_label.text = _monitored_unit.character_name
	
	var u_class: String = _monitored_unit.get_name()
	if CLASS_ICONS.has(u_class):
		class_icon.texture = CLASS_ICONS[u_class]
	else:
		var matched: bool = false
		for key in CLASS_ICONS.keys():
			if u_class.begins_with(key):
				class_icon.texture = CLASS_ICONS[key]
				matched = true
				break
		if not matched:
			class_icon.texture = null

	atk_value.text = str(_monitored_unit.strength)
	def_value.text = str(_monitored_unit.defense)
	range_value.text = str(_monitored_unit.move_range)

	_refresh_hp_visuals()

func _refresh_stats() -> void:
	if is_instance_valid(_monitored_unit):
		_refresh_hp_visuals()

func _refresh_hp_visuals() -> void:
	var cur_hp: int = _monitored_unit.current_hp
	var m_hp: int = _monitored_unit.max_hp

	hp_progress_bar.max_value = float(m_hp)
	hp_progress_bar.value = cur_hp
	hp_label.text = "%d / %d" % [cur_hp, m_hp]

func _on_unit_damage_taken(_remaining_hp: int) -> void:
	_refresh_hp_visuals()

func _disconnect_current_unit() -> void:
	
	if is_instance_valid(_monitored_unit):
		if _monitored_unit.damage_taken.is_connected(_on_unit_damage_taken):
			_monitored_unit.damage_taken.disconnect(_on_unit_damage_taken)
		if _monitored_unit.tree_exiting.is_connected(clear):
			_monitored_unit.tree_exiting.disconnect(clear)
	_monitored_unit = null

func clear() -> void:
	_disconnect_current_unit()
	hide()
