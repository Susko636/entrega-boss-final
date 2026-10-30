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
	"Prota": preload("res://Assets/Tiny Swords/UI Elements/UI Elements/Human Avatars/Avatars_05.png")
}

func display_unit(unit: Unit) -> void:
	
	if unit == null:
		hide()
		return

	name_label.text = unit.character_name
	
	var u_class: String = unit.get_name()
	if CLASS_ICONS.has(u_class):
		class_icon.texture = CLASS_ICONS[u_class]
	else:
		class_icon.texture = null

	var cur_hp: int = unit.current_hp
	var m_hp: int =unit.max_hp

	hp_progress_bar.max_value = float(m_hp)
	hp_progress_bar.value = cur_hp
	hp_label.text = "%d / %d" % [cur_hp, m_hp]

	atk_value.text = str(unit.strength)
	def_value.text = str(unit.defense)
	range_value.text = str(unit.move_range)

	show()

func clear() -> void:
	hide()
