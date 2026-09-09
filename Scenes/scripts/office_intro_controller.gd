extends Node

const PLAYER_QUESTION_ID: String = "office:empty_floor"
const NPC_SHOUT_ID: String = "office:npc_boss_shout"
const NPC_DIALOG_ID: String = "office:npc_intro_dialog"
const LAPTOP_FIRST_FOUND_ID: String = "office:laptop_first_found"
const LAPTOP_SECOND_FOUND_ID: String = "office:laptop_second_found"
const CABLE_FIRST_FOUND_ID: String = "office:cable_first_found"
const CABLE_SECOND_FOUND_ID: String = "office:cable_second_found"
const BOSS_ROOM_HACK_READY_ID: String = "office:boss_room_hack_ready"
const DATA_CENTER_FLOOR_ID: String = "office:data_center_floor"
const NPC_REVEAL_DELAY: float = 2.0
const DATA_CENTER_PROMPT_DELAY: float = 2.0

var player: Player
var npc: Node2D
var npc_path: NPCPath
var npc_return_path: NPCPath
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
	if not player.balao_de_pensamento.pensamento_finalizado.is_connected(_on_player_thought_finished):
		player.balao_de_pensamento.pensamento_finalizado.connect(_on_player_thought_finished)
	if not DialogManager.dialog_finished.is_connected(_on_dialog_finished):
		DialogManager.dialog_finished.connect(_on_dialog_finished)
	var laptop_pickup := get_node_or_null("../Coletaveis/Laptop/PickupComponent") as PickupComponent
	if laptop_pickup != null and not laptop_pickup.interagiu.is_connected(_on_laptop_collected):
		laptop_pickup.interagiu.connect(_on_laptop_collected)
	var cable_pickup := get_node_or_null("../Coletaveis/Cabo/PickupComponent") as PickupComponent
	if cable_pickup != null and not cable_pickup.interagiu.is_connected(_on_cable_collected):
		cable_pickup.interagiu.connect(_on_cable_collected)

	var state: Dictionary = SaveGame.office_mission_state(player)
	var state_migrated := false
	if (
		player.inventory.get_item_on_inventary("laptop")
		or SaveGame.is_object_collected("laptop_sala_escritorio")
	):
		if not bool(state.get("office_laptop_collected", false)):
			state["office_laptop_collected"] = true
			state_migrated = true
	if (
		player.inventory.get_item_on_inventary("cabo")
		or SaveGame.is_object_collected("cabo_sala_escritorio")
	):
		if not bool(state.get("office_cable_collected", false)):
			state["office_cable_collected"] = true
			state_migrated = true
	if str(state.get("office_first_hacking_item", "")).is_empty():
		var laptop_saved := bool(state.get("office_laptop_collected", false))
		var cable_saved := bool(state.get("office_cable_collected", false))
		if laptop_saved or cable_saved:
			state["office_first_hacking_item"] = "cabo" if cable_saved and not laptop_saved else "laptop"
			state_migrated = true
	if _unlock_boss_room_hack_task(state):
		state_migrated = true
	if state_migrated:
		SaveGame.save_global_state("hall_quest_01", state)
	_queue_boss_room_hack_thought(state)
	if _handle_data_center_task(state):
		return
	npc = get_node_or_null("../NPCs/NPC1") as Node2D
	if bool(state.get("office_npc_left_for_data_center", false)):
		if is_instance_valid(npc):
			npc.process_mode = Node.PROCESS_MODE_DISABLED
			npc.hide()
			npc.queue_free()
		_show_boss_room_access_task()
		return
	if npc == null:
		push_error("OfficeIntroController não encontrou NPCs/NPC1.")
		return
	npc_path = npc.get_node_or_null("Line2D2") as NPCPath
	npc_return_path = npc.get_node_or_null("Line2D3") as NPCPath
	npc_balloon = npc.get_node_or_null("BalaoDePensamento") as Sprite2D
	if npc_path == null or npc_return_path == null or npc_balloon == null:
		push_error("NPC1 precisa dos caminhos Line2D2, Line2D3 e do BalaoDePensamento.")
		return

	if not npc.is_connected(&"path_completed", _on_npc_path_completed):
		npc.connect(&"path_completed", _on_npc_path_completed)

	npc.call("set_dialog_enabled", false)
	_refresh_npc_dialog()
	_restore_sequence()


func _restore_sequence() -> void:
	var state: Dictionary = SaveGame.office_mission_state(player)
	var arrived := bool(state.get("office_npc_arrived", false))
	var revealed := bool(state.get("office_npc_revealed", false))
	var shout_finished := bool(state.get("office_npc_shout_finished", false))
	var dialog_finished := bool(state.get("office_dialog_finished", false))
	var return_started := bool(state.get("office_npc_return_started", false)) or dialog_finished

	if return_started:
		if not bool(state.get("office_npc_return_started", false)):
			state["office_npc_return_started"] = true
			SaveGame.save_global_state("hall_quest_01", state)
		_show_npc()
		npc.call("set_dialog_enabled", false)
		_show_boss_room_access_task()
		if not bool(npc.get("checkpoint_restored")) or bool(npc.get("path_finished")):
			npc.call("start_path", npc_return_path)
		return

	if arrived:
		_show_npc()
		if not bool(npc.get("checkpoint_restored")):
			_move_npc_to_path_end()
		if shout_finished:
			npc.call("set_dialog_enabled", true)
			if bool(state.get("office_dialog_finished", false)):
				_show_boss_room_access_task()
			else:
				_show_talk_task(false)
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
	if id == DATA_CENTER_FLOOR_ID:
		var data_center_state: Dictionary = SaveGame.office_mission_state(player)
		data_center_state["office_data_center_task_pending"] = false
		data_center_state["office_data_center_task_active"] = true
		SaveGame.save_global_state("hall_quest_01", data_center_state)
		_show_go_to_sixth_floor_task(bool(data_center_state.get("office_data_center_task_completed", false)))
		_save_checkpoint()
		return
	if id != PLAYER_QUESTION_ID:
		return
	var state: Dictionary = SaveGame.office_mission_state(player)
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
	var state: Dictionary = SaveGame.office_mission_state(player)
	if bool(state.get("office_npc_revealed", false)):
		return
	_show_npc()
	npc.call("start_path", npc_path)
	state["office_npc_revealed"] = true
	SaveGame.save_global_state("hall_quest_01", state)
	_save_checkpoint()


func _on_npc_path_completed(finished_path: NPCPath) -> void:
	if not _is_current_office():
		return
	var state: Dictionary = SaveGame.office_mission_state(player)
	if finished_path == npc_return_path:
		state["office_npc_left_for_data_center"] = true
		SaveGame.save_global_state("hall_quest_01", state)
		call_deferred("_save_checkpoint")
		return
	if finished_path != npc_path:
		return
	if bool(state.get("office_npc_arrived", false)):
		return
	state["office_npc_arrived"] = true
	SaveGame.save_global_state("hall_quest_01", state)
	_save_checkpoint()
	_npc_shout()


func _npc_shout() -> void:
	if shout_running or not _is_current_office():
		return
	var state: Dictionary = SaveGame.office_mission_state(player)
	if bool(state.get("office_npc_shout_finished", false)):
		npc.call("set_dialog_enabled", true)
		if bool(state.get("office_dialog_finished", false)):
			_show_boss_room_access_task()
		else:
			_show_talk_task(false)
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
	var state: Dictionary = SaveGame.office_mission_state(player)
	state["office_dialog_finished"] = true
	state["office_npc_return_started"] = true
	SaveGame.save_global_state("hall_quest_01", state)
	_show_boss_room_access_task()
	npc.call("set_dialog_enabled", false)
	npc.call("start_path", npc_return_path)
	_save_checkpoint()


func _on_laptop_collected() -> void:
	if not _is_current_office():
		return
	var state: Dictionary = SaveGame.office_mission_state(player)
	state["office_laptop_collected"] = true
	var laptop_was_first := _register_first_hacking_item(state, "laptop") == "laptop"
	_unlock_boss_room_hack_task(state)
	SaveGame.save_global_state("hall_quest_01", state)
	_show_hacking_item_task(state)
	_refresh_npc_dialog()
	player.balao_de_pensamento.enfileirar(
		LAPTOP_FIRST_FOUND_ID if laptop_was_first else LAPTOP_SECOND_FOUND_ID,
		"Alguém esqueceu o notebook aqui" if laptop_was_first else "Esqueceram um notebook também"
	)
	_queue_boss_room_hack_thought(state)


func _on_cable_collected() -> void:
	if not _is_current_office():
		return
	var state: Dictionary = SaveGame.office_mission_state(player)
	state["office_cable_collected"] = true
	var cable_was_first := _register_first_hacking_item(state, "cabo") == "cabo"
	_unlock_boss_room_hack_task(state)
	SaveGame.save_global_state("hall_quest_01", state)
	_show_hacking_item_task(state, not cable_was_first)
	_refresh_npc_dialog()
	player.balao_de_pensamento.enfileirar(
		CABLE_FIRST_FOUND_ID if cable_was_first else CABLE_SECOND_FOUND_ID,
		"Alguém esqueceu um cabo aqui" if cable_was_first else "Esqueceram um cabo também"
	)
	_queue_boss_room_hack_thought(state)


func _show_talk_task(completed: bool, animate: bool = false) -> void:
	var quest_ui := player.get_node_or_null("QUEST_MISSION") as QuestMissionUI
	if quest_ui != null:
		quest_ui.show_talk_to_npc_task(completed, animate)


func _show_boss_room_access_task() -> void:
	var quest_ui := player.get_node_or_null("QUEST_MISSION") as QuestMissionUI
	if quest_ui != null:
		var state: Dictionary = SaveGame.office_mission_state(player)
		if (
			bool(state.get("office_laptop_collected", false))
			or bool(state.get("office_cable_collected", false))
		):
			quest_ui.show_boss_room_and_cable_tasks(
				bool(state.get("office_boss_room_access_found", false)),
				bool(state.get("office_cable_collected", false)),
				false,
				bool(state.get("office_hack_boss_room_ready", false)),
				bool(state.get("office_boss_room_hacked", false)),
				false,
				false,
				str(state.get("office_first_hacking_item", "")) == "cabo"
			)
		else:
			quest_ui.show_find_boss_room_access_task()


func _show_hacking_item_task(state: Dictionary, animate: bool = false) -> void:
	var quest_ui := player.get_node_or_null("QUEST_MISSION") as QuestMissionUI
	if quest_ui == null:
		return
	var find_laptop := str(state.get("office_first_hacking_item", "")) == "cabo"
	var item_collected := bool(
		state.get("office_laptop_collected", false)
		if find_laptop
		else state.get("office_cable_collected", false)
	)
	if bool(state.get("office_dialog_finished", false)):
		quest_ui.show_boss_room_and_cable_tasks(
			bool(state.get("office_boss_room_access_found", false)),
			item_collected,
			animate,
			bool(state.get("office_hack_boss_room_ready", false)),
			bool(state.get("office_boss_room_hacked", false)),
			false,
			false,
			find_laptop
		)
	else:
		quest_ui.show_find_hacking_item_task(find_laptop, item_collected, animate)


func _register_first_hacking_item(state: Dictionary, item: String) -> String:
	var first_item := str(state.get("office_first_hacking_item", ""))
	if first_item.is_empty():
		first_item = item
		state["office_first_hacking_item"] = first_item
	return first_item


func _refresh_npc_dialog() -> void:
	if not is_instance_valid(npc):
		return
	var state: Dictionary = SaveGame.office_mission_state(player)
	var has_laptop := bool(state.get("office_laptop_collected", false))
	var has_cable := bool(state.get("office_cable_collected", false))
	if not has_laptop and not has_cable:
		return
	var offer := ""
	if has_laptop and has_cable:
		offer = "Alex: Já achei um notebook e um cabo. Eu consigo hackear a porta da sala do chefe."
	elif has_laptop:
		offer = "Alex: Já achei um notebook. Se eu encontrar um cabo, consigo hackear a porta da sala do chefe."
	else:
		offer = "Alex: Já achei um cabo. Se eu encontrar um notebook, consigo hackear a porta da sala do chefe."
	var dialog_texts: Array[String] = [
		"Alex: Cadê todo mundo? O que aconteceu aqui?",
		"Funcionário: A IA ficou maluca. Ela tomou o controle dos sistemas e está construindo uma superbomba.",
		"Alex: Uma superbomba? Como isso foi acontecer?",
		"Funcionário: O chefe fez alguma merda e perdeu o controle dela. A gente precisa falar com ele.",
		"Alex: Então chama ele!",
		"Funcionário: Eu já tentei. Ele não atende e a sala está trancada.",
		offer,
		"Funcionário: Eu vou voltar para o andar do data center. Enquanto isso, tenta pegar o cartão do chefe. Precisamos dele lá encima.",
		"Alex: Certo. Eu vou atrás do cartão."
	]
	npc.set("dialog_texts", dialog_texts)


func _handle_data_center_task(state: Dictionary) -> bool:
	if bool(state.get("office_data_center_task_active", false)):
		_show_go_to_sixth_floor_task(bool(state.get("office_data_center_task_completed", false)))
		return true
	if not bool(state.get("office_data_center_task_pending", false)):
		return false
	var quest_ui := player.get_node_or_null("QUEST_MISSION") as QuestMissionUI
	if quest_ui != null:
		quest_ui.hide_all_tasks()
	call_deferred("_show_data_center_prompt")
	return true


func _show_data_center_prompt() -> void:
	await get_tree().create_timer(DATA_CENTER_PROMPT_DELAY, false).timeout
	if not _is_current_office():
		return
	var state: Dictionary = SaveGame.office_mission_state(player)
	if not bool(state.get("office_data_center_task_pending", false)):
		return
	player.balao_de_pensamento.enfileirar(
		DATA_CENTER_FLOOR_ID,
		"Onde era o data center? Acho que no 6º andar!"
	)


func _show_go_to_sixth_floor_task(completed: bool = false) -> void:
	var quest_ui := player.get_node_or_null("QUEST_MISSION") as QuestMissionUI
	if quest_ui != null:
		quest_ui.show_go_to_sixth_floor_task(completed)


func _unlock_boss_room_hack_task(state: Dictionary) -> bool:
	if not (
		bool(state.get("office_laptop_collected", false))
		and bool(state.get("office_cable_collected", false))
	):
		return false
	if bool(state.get("office_hack_boss_room_ready", false)):
		return false
	state["office_hack_boss_room_ready"] = true
	return true


func _queue_boss_room_hack_thought(state: Dictionary) -> void:
	if not bool(state.get("office_hack_boss_room_ready", false)):
		return
	if bool(state.get("office_hack_boss_room_thought_queued", false)):
		return
	state["office_hack_boss_room_thought_queued"] = true
	SaveGame.save_global_state("hall_quest_01", state)
	player.balao_de_pensamento.enfileirar(
		BOSS_ROOM_HACK_READY_ID,
		"Agora eu consigo entrar na sala do chefe..."
	)


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
