extends Node

const PLAYER_QUESTION_ID: String = "office:empty_floor"
const NPC_SHOUT_ID: String = "office:npc_boss_shout"
const NPC_DIALOG_ID: String = "office:npc_intro_dialog"
const NPC_REVEAL_DELAY: float = 2.0

var player: Player
var npc: Node2D
var npc_path: NPCPath
var npc_balloon: Sprite2D
var reveal_scheduled: bool = false
var shout_running: bool = false


func _ready() -> void:
	call_deferred("_initialize")


func _initialize() -> void:
	var office := get_parent() as BaseScene
	if office == null or not is_instance_valid(office.player):
		push_error("OfficeIntroController não encontrou o Player.")
		return
	player = office.player
	npc = get_node_or_null("../NPCs/NPC1") as Node2D
	if npc == null:
		push_error("OfficeIntroController não encontrou NPCs/NPC1.")
		return
	npc_path = npc.get_node_or_null("Line2D2") as NPCPath
	npc_balloon = npc.get_node_or_null("BalaoDePensamento") as Sprite2D
	if npc_path == null or npc_balloon == null:
		push_error("NPC1 precisa do caminho Line2D2 e do BalaoDePensamento.")
		return

	if not player.balao_de_pensamento.pensamento_finalizado.is_connected(_on_player_thought_finished):
		player.balao_de_pensamento.pensamento_finalizado.connect(_on_player_thought_finished)
	if not npc.is_connected(&"path_completed", _on_npc_path_completed):
		npc.connect(&"path_completed", _on_npc_path_completed)
	if not DialogManager.dialog_finished.is_connected(_on_dialog_finished):
		DialogManager.dialog_finished.connect(_on_dialog_finished)

	npc.call("set_dialog_enabled", false)
	_restore_sequence()


func _restore_sequence() -> void:
	var state := SaveGame.office_mission_state(player)
	var arrived := bool(state.get("office_npc_arrived", false))
	var revealed := bool(state.get("office_npc_revealed", false))
	var shout_finished := bool(state.get("office_npc_shout_finished", false))

	if arrived:
		_show_npc()
		if not bool(npc.get("checkpoint_restored")):
			_move_npc_to_path_end()
		if shout_finished:
			npc.call("set_dialog_enabled", true)
			_show_talk_task(bool(state.get("office_dialog_finished", false)))
		else:
			call_deferred("_npc_shout")
		return

	if revealed:
		_show_npc()
		if not bool(npc.get("checkpoint_restored")) or bool(npc.get("path_finished")):
			npc.call("start_path", npc_path)
		return

	_hide_npc()
	if bool(state.get("office_question_finished", false)) or player.balao_de_pensamento.foi_concluido(PLAYER_QUESTION_ID):
		_schedule_npc_reveal()


func _on_player_thought_finished(id: String) -> void:
	if id != PLAYER_QUESTION_ID:
		return
	var state := SaveGame.office_mission_state(player)
	state["office_question_finished"] = true
	SaveGame.save_global_state("hall_quest_01", state)
	_save_checkpoint()
	_schedule_npc_reveal()


func _schedule_npc_reveal() -> void:
	if reveal_scheduled:
		return
	reveal_scheduled = true
	await get_tree().create_timer(NPC_REVEAL_DELAY, false).timeout
	reveal_scheduled = false
	if not _is_current_office():
		return
	var state := SaveGame.office_mission_state(player)
	if bool(state.get("office_npc_revealed", false)):
		return
	_show_npc()
	npc.call("start_path", npc_path)
	state["office_npc_revealed"] = true
	SaveGame.save_global_state("hall_quest_01", state)
	_save_checkpoint()


func _on_npc_path_completed(finished_path: NPCPath) -> void:
	if finished_path != npc_path or not _is_current_office():
		return
	var state := SaveGame.office_mission_state(player)
	if bool(state.get("office_npc_arrived", false)):
		return
	state["office_npc_arrived"] = true
	SaveGame.save_global_state("hall_quest_01", state)
	_save_checkpoint()
	_npc_shout()


func _npc_shout() -> void:
	if shout_running or not _is_current_office():
		return
	var state := SaveGame.office_mission_state(player)
	if bool(state.get("office_npc_shout_finished", false)):
		npc.call("set_dialog_enabled", true)
		return
	shout_running = true
	await npc_balloon.mostrar_texto("CHEFE! CHEFE!", NPC_SHOUT_ID)
	shout_running = false
	if not _is_current_office():
		return
	state = SaveGame.office_mission_state(player)
	state["office_npc_shout_finished"] = true
	SaveGame.save_global_state("hall_quest_01", state)
	npc.call("set_dialog_enabled", true)
	_show_talk_task(false)
	_save_checkpoint()


func _on_dialog_finished(dialog_id: String) -> void:
	if dialog_id != NPC_DIALOG_ID or not _is_current_office():
		return
	var state := SaveGame.office_mission_state(player)
	state["office_dialog_finished"] = true
	SaveGame.save_global_state("hall_quest_01", state)
	_show_talk_task(true, true)
	_save_checkpoint()


func _show_talk_task(completed: bool, animate: bool = false) -> void:
	var quest_ui := player.get_node_or_null("QUEST_MISSION") as QuestMissionUI
	if quest_ui != null:
		quest_ui.show_talk_to_npc_task(completed, animate)


func _show_npc() -> void:
	npc.show()
	npc.process_mode = Node.PROCESS_MODE_INHERIT


func _hide_npc() -> void:
	npc.hide()
	npc.process_mode = Node.PROCESS_MODE_DISABLED


func _move_npc_to_path_end() -> void:
	if npc_path.points.is_empty():
		return
	npc.global_position = npc_path.to_global(npc_path.points[npc_path.points.size() - 1])
	npc.call("stop_current_path")


func _save_checkpoint() -> void:
	if is_instance_valid(player) and player.checkpoint_enabled:
		SaveGame.create_checkpoint(player)


func _is_current_office() -> bool:
	return (
		is_inside_tree()
		and not is_queued_for_deletion()
		and is_instance_valid(player)
		and get_tree().current_scene == get_parent()
	)
