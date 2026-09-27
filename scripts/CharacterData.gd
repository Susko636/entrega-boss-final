class_name CharacterData
extends Resource

enum Faction { PLAYER, ENEMY, ALLY }

@export var character_name: String = "Soldado"
@export var faction: Faction = Faction.PLAYER

@export_group("Estadísticas Base")
@export var max_hp: int = 20
@export var strength: int = 5
@export var defense: int = 3
@export var speed: int = 4
@export var move_range: int = 4 
