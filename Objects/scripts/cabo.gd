extends Node2D

@export var save_id: String = "faca"
var no_inventario: bool = false

@onready var sprite_2d: Sprite2D = $Sprite2D

var player: Player = null

func _ready() -> void:
	if not no_inventario:
		if SaveGame.is_object_collected(save_id):
			queue_free()
			return
	set_process(false)

func foi_coletado() -> void:
	SaveGame.set_object_collected(save_id)

func marcar_como_item_inventario() -> void:
	no_inventario = true

func set_player(novo_player: Player) -> void:
	player = novo_player
