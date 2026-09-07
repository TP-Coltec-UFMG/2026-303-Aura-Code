extends Node2D
class_name Inventory

@onready var slot_1: Panel = $GridContainer/Slot1
@onready var slot_2: Panel = $GridContainer/Slot2
@onready var slot_3: Panel = $GridContainer/Slot3
@onready var slot_4: Panel = $GridContainer/Slot4
@onready var slot_5: Panel = $GridContainer/Slot5
@onready var slot_6: Panel = $GridContainer/Slot6

var slots_por_item: Dictionary = {}
var equipped_item_id: String = ""

func _ready() -> void:
	slots_por_item = {
		"lanterna": slot_2,
		"gun": slot_1,
		"cartao": slot_5,
		"laptop": slot_4,
		"cabo": slot_3,
		"extintor": slot_6
	}

func add_item(item_id: String, item_scene: PackedScene = null) -> bool:
	if item_id == "conhecimento":
		get_parent().get_parent().put_conhecimento()
		return true
		
	if item_id == "":
		return true

	if not slots_por_item.has(item_id):
		push_warning("Item sem slot configurado no inventário: " + item_id)
		return false

	var slot = slots_por_item[item_id]

	var adicionou: bool = slot.put_item_on_inventory(item_scene)

	if adicionou and equipped_item_id == item_id:
		slot.set_equipped(true)

	return adicionou

func get_item_on_inventary(item_id: String) -> bool:
	return get_item_control(item_id) != null

func get_item_control(item_id: String) -> Node2D:
	if not slots_por_item.has(item_id):
		return null

	var slot = slots_por_item[item_id]
	return slot.item

func remove_item(item_id: String) -> void:
	if not slots_por_item.has(item_id):
		return

	var slot = slots_por_item[item_id]

	if slot.item != null:
		slot.clear_item()

	if equipped_item_id == item_id:
		equipped_item_id = ""


func set_equipped_item(item_id: String) -> void:
	equipped_item_id = item_id if slots_por_item.has(item_id) else ""

	for current_item_id in slots_por_item:
		var slot: Panel = slots_por_item[current_item_id]
		slot.set_equipped(current_item_id == equipped_item_id)


func refresh_binding_labels() -> void:
	for slot: Panel in slots_por_item.values():
		slot.refresh_bind_label()
		
func get_save_state() -> Dictionary:
	var inventario_salvo: Dictionary = {}

	for item_id in slots_por_item:
		var slot = slots_por_item[item_id]

		if slot.item == null:
			continue

		if not is_instance_valid(slot.item):
			continue

		var scene_path: String = slot.item.scene_file_path

		if scene_path.is_empty():
			continue

		var item_data: Dictionary = {
			"scene_path": scene_path
		}

		if slot.item.has_method("get_checkpoint_state"):
			var item_state: Variant = slot.item.call(
				"get_checkpoint_state"
			)

			if item_state is Dictionary:
				item_data["state"] = item_state

		inventario_salvo[item_id] = item_data

	return inventario_salvo


func load_save_state(inventario_salvo: Dictionary) -> void:
	for saved_item_id in inventario_salvo:
		var item_id := "cabo" if str(saved_item_id) == "faca" else str(saved_item_id)
		if not slots_por_item.has(item_id):
			continue

		var saved_item: Variant = inventario_salvo[saved_item_id]

		var scene_path: String = ""
		var item_state: Dictionary = {}

		# Compatibilidade com o formato que você estava usando antes.
		if saved_item is String:
			scene_path = saved_item

		elif saved_item is Dictionary:
			scene_path = str(
				saved_item.get("scene_path", "")
			)

			var saved_state: Variant = saved_item.get(
				"state",
				{}
			)

			if saved_state is Dictionary:
				item_state = saved_state

		if scene_path.is_empty():
			continue
		if scene_path == "res://Objects/faca.tscn":
			scene_path = "res://Objects/cabo.tscn"

		var item_scene: PackedScene = load(scene_path)

		if item_scene == null:
			continue

		var slot = slots_por_item[item_id]

		var adicionou: bool = slot.put_item_on_inventory(
			item_scene
		)

		if not adicionou:
			continue

		if slot.item == null:
			continue

		if not item_state.is_empty():
			if slot.item.has_method("load_checkpoint_state"):
				slot.item.call(
					"load_checkpoint_state",
					item_state
				)
