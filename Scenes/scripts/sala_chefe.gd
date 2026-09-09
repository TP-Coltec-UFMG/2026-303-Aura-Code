extends BaseScene

const BOSS_ROOM_EMPTY_ID: String = "boss_room:chief_left"
const BOSS_CARD_FOUND_ID: String = "boss_room:chief_card_found"


func _ready() -> void:
	super._ready()
	call_deferred("_initialize_boss_room")


func _initialize_boss_room() -> void:
	if not is_instance_valid(player):
		return
	var state: Dictionary = SaveGame.office_mission_state(player)
	var state_changed := false
	if SaveGame.is_object_collected("cartao_chefe_sala_chefe") and not bool(state.get("office_boss_card_collected", false)):
		state["office_boss_card_collected"] = true
		state_changed = true
	var first_visit := not bool(state.get("office_boss_room_visited", false))
	if first_visit:
		state["office_boss_room_visited"] = true
		state_changed = true
	if state_changed:
		SaveGame.save_global_state("hall_quest_01", state)
	_show_boss_room_tasks(state)
	if first_visit:
		player.balao_de_pensamento.enfileirar(
			BOSS_ROOM_EMPTY_ID,
			"Por isso ele não está respondendo, meteu o pé"
		)
	if player.checkpoint_enabled and state_changed:
		SaveGame.create_checkpoint(player)
	var card_pickup := get_node_or_null("Cartao_chefe/PickupComponent") as PickupComponent
	if card_pickup != null and not card_pickup.interagiu.is_connected(_on_boss_card_collected):
		card_pickup.interagiu.connect(_on_boss_card_collected)


func _on_boss_card_collected() -> void:
	if not is_instance_valid(player):
		return
	var state: Dictionary = SaveGame.office_mission_state(player)
	state["office_boss_room_visited"] = true
	state["office_boss_card_collected"] = true
	SaveGame.save_global_state("hall_quest_01", state)
	_show_boss_room_tasks(state)
	player.balao_de_pensamento.enfileirar(
		BOSS_CARD_FOUND_ID,
		"Tenho que levar isso no data center agora"
	)
	if player.checkpoint_enabled:
		SaveGame.create_checkpoint(player)


func prepare_return_to_office() -> void:
	if not is_instance_valid(player):
		return
	var state: Dictionary = SaveGame.office_mission_state(player)
	if not bool(state.get("office_boss_card_collected", false)):
		return
	if bool(state.get("office_data_center_task_active", false)):
		return
	state["office_data_center_task_pending"] = true
	SaveGame.save_global_state("hall_quest_01", state)
	var quest_ui := player.get_node_or_null("QUEST_MISSION") as QuestMissionUI
	if quest_ui != null:
		quest_ui.hide_all_tasks()
	if player.checkpoint_enabled:
		SaveGame.create_checkpoint(player)


func _show_boss_room_tasks(state: Dictionary) -> void:
	var quest_ui := player.get_node_or_null("QUEST_MISSION") as QuestMissionUI
	if quest_ui == null:
		return
	quest_ui.show_boss_room_and_cable_tasks(
		bool(state.get("office_boss_room_access_found", false)),
		bool(state.get("office_cable_collected", false)),
		false,
		bool(state.get("office_hack_boss_room_ready", false)),
		bool(state.get("office_boss_room_hacked", false)),
		true,
		bool(state.get("office_boss_card_collected", false))
	)
