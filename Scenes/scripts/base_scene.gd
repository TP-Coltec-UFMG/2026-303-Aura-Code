class_name BaseScene
extends Node

var player: Player = null

@onready var entrance_markers: Node2D = $EntranceMarkers


func _ready() -> void:
	var scene_player: Player = get_scene_player()

	# Existe um Player persistente vindo de outra cena.
	if is_instance_valid(scene_manager.player):
		if is_instance_valid(scene_player) and scene_player != scene_manager.player:
			if scene_player.get_parent() != null:
				scene_player.get_parent().remove_child(scene_player)

			scene_player.queue_free()

		player = scene_manager.player

		if player.get_parent() != null:
			player.get_parent().remove_child(player)

		add_child(player)

	# A própria cena já possui um Player.
	elif is_instance_valid(scene_player):
		player = scene_player
		scene_manager.player = player

	# A cena não possui Player e estamos carregando um checkpoint.
	elif SaveGame.restore_checkpoint_pending:
		player = SaveGame.create_player_from_checkpoint()

		if player == null:
			push_error(
				"Não foi possível criar o Player para carregar o checkpoint."
			)
			return

		add_child(player)
		scene_manager.player = player

	else:
		push_error(
			"A cena " + name
			+ " não possui Player e não existe Player persistente."
		)
		return

	var restaurou_checkpoint: bool = (
		SaveGame.apply_pending_checkpoint(player)
	)

	if not restaurou_checkpoint:
		position_player()

		if not SaveGame.has_checkpoint():
			SaveGame.create_checkpoint(player)

	call_deferred("atualizar_camera")
	call_deferred("_registrar_chegada_escritorio")


func get_scene_player() -> Player:
	for child in get_children():
		if child is Player:
			return child as Player

	return null


func position_player() -> void:
	if player == null:
		return

	var last_scene: String = scene_manager.last_scene_name

	if last_scene.is_empty():
		for entrance in entrance_markers.get_children():
			if entrance is Marker2D and entrance.name == "start_game_position":
				player.global_position = entrance.global_position
				return

	if not last_scene.is_empty():
		for entrance in entrance_markers.get_children():
			if entrance is Marker2D and entrance.name == last_scene:
				player.global_position = entrance.global_position
				return

	for entrance in entrance_markers.get_children():
		if entrance is Marker2D and entrance.name == "any":
			player.global_position = entrance.global_position
			return


func atualizar_camera() -> void:
	if player == null:
		return

	var camera: Camera2D = player.get_node_or_null(
		"Camera2D"
	) as Camera2D

	if camera == null:
		return

	camera.enabled = true
	camera.make_current()
	camera.reset_smoothing()
	camera.force_update_scroll()


# Executado depois de position_player/apply_pending_checkpoint, em todos os andares.
func _registrar_chegada_escritorio() -> void:
	if not is_inside_tree() or not is_instance_valid(player):
		return
	if not get_tree().current_scene.scene_file_path.ends_with("andar_escritorio.tscn"):
		return
	var estado := SaveGame.office_mission_state(player)
	if not bool(estado.get("elevator_third_floor_unlocked", false)) or bool(estado.get("arrived_third_floor", false)):
		return
	estado["arrived_third_floor"] = true
	SaveGame.save_global_state("hall_quest_01", estado)
	var quest_ui := player.get_node_or_null("QUEST_MISSION") as QuestMissionUI
	if quest_ui != null:
		quest_ui.complete_third_floor()
	if player.checkpoint_enabled:
		SaveGame.create_checkpoint(player)
