class_name CombatHUD
extends Control

@onready var attacker_card: UnitInfoCard = $AttackerCard
@onready var defender_card: UnitInfoCard = $DefenderCard

func _ready() -> void:
	hide()

func show_forecast(attacker: Unit, defender: Unit) -> void:
	
	attacker_card.display_unit(attacker)
	defender_card.display_unit(defender)
	show()

func clear_forecast() -> void:
	
	attacker_card.clear()
	defender_card.clear()
	hide()
