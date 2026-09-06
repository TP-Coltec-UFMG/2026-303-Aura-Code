extends CanvasLayer


func atualizar(player: Player) -> void:
	var estado := SaveGame.office_mission_state(player)
	visible = bool(estado.get("elevator_third_floor_unlocked", false))
	if not visible:
		return
	var marcador: AnimatedSprite2D = $VBoxContainer/HBoxContainer/AnimatedSprite2D
	var chegou := bool(estado.get("arrived_third_floor", false))
	if not chegou and get_parent().scene_file_path.ends_with("andar_escritorio.tscn"):
		estado["arrived_third_floor"] = true
		marcador.play("default")
		if player.checkpoint_enabled:
			SaveGame.create_checkpoint(player)
	elif chegou:
		marcador.stop()
		marcador.frame = marcador.sprite_frames.get_frame_count("default") - 1
	else:
		marcador.stop()
		marcador.frame = 0


func _notification(what: int) -> void:
	if what == NOTIFICATION_PAUSED:
		hide()
	elif what == NOTIFICATION_UNPAUSED and is_inside_tree() and not is_queued_for_deletion():
		visible = bool(SaveGame.office_mission_state().get("elevator_third_floor_unlocked", false))
