extends Node2D

const CONTROL_GROUPS = [
	{
		"title": "MOVIMENTO",
		"actions": [
			{"id": "up", "label": "CIMA"},
			{"id": "down", "label": "BAIXO"},
			{"id": "left", "label": "ESQUERDA"},
			{"id": "right", "label": "DIREITA"},
			{"id": "correr", "label": "CORRER"},
			{"id": "empurrar", "label": "EMPURRAR"},
		]
	},
	{
		"title": "EQUIPAR",
		"actions": [
			{"id": "use_lanterna", "label": "LANTERNA"},
			{"id": "use_arma", "label": "ARMA"},
			{"id": "use_cartao", "label": "CARTÃO"},
			{"id": "use_laptop", "label": "LAPTOP"},
			{"id": "use_cabo", "label": "CABO"},
			{"id": "use_extintor", "label": "EXTINTOR"},
		]
	},
	{
		"title": "AÇÕES",
		"actions": [
			{"id": "interact", "label": "INTERAGIR"},
			{"id": "fire", "label": "ATIRAR"},
			{"id": "acende_lanterna", "label": "LIGAR LUZ"},
			{"id": "usar_extintor", "label": "USAR EXTINTOR"},
			{"id": "esc", "label": "PAUSAR"},
		]
	},
]

const PANEL_POSITION := Vector2(14.0, 47.0)
const PANEL_SIZE := Vector2(452.0, 215.0)

var _button_icon: Texture2D
var _button_font: Font


func _ready() -> void:
	_build_controls_menu()


func _build_controls_menu() -> void:
	var template := get_node_or_null(
		"VBoxContainer/InputRemapButton"
	) as InputRemapButton

	if template == null:
		push_warning("Modelo do botão de controles não foi encontrado.")
		return

	_button_icon = template.icon
	_button_font = template.get_theme_font("font")

	_remove_legacy_columns()

	var panel := PanelContainer.new()
	panel.name = "RemapPanel"
	panel.position = PANEL_POSITION
	panel.size = PANEL_SIZE
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_theme_stylebox_override(
		"panel",
		_make_stylebox(
			Color(0.018, 0.022, 0.028, 0.96),
			Color.TRANSPARENT,
			0,
			3
		)
	)
	add_child(panel)

	var outer_margin := MarginContainer.new()
	outer_margin.name = "Margin"
	outer_margin.add_theme_constant_override("margin_left", 7)
	outer_margin.add_theme_constant_override("margin_top", 6)
	outer_margin.add_theme_constant_override("margin_right", 7)
	outer_margin.add_theme_constant_override("margin_bottom", 5)
	panel.add_child(outer_margin)

	var content := VBoxContainer.new()
	content.name = "Content"
	content.add_theme_constant_override("separation", 4)
	outer_margin.add_child(content)

	var columns := HBoxContainer.new()
	columns.name = "Columns"
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 6)
	content.add_child(columns)

	for group_index: int in range(CONTROL_GROUPS.size()):
		_add_control_group(
			columns,
			CONTROL_GROUPS[group_index],
			group_index
		)

func _add_control_group(
	columns: HBoxContainer,
	group_data: Dictionary,
	group_index: int
) -> void:
	var group_panel := PanelContainer.new()
	group_panel.name = "Group%d" % group_index
	group_panel.custom_minimum_size = Vector2(142.0, 0.0)
	group_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	group_panel.add_theme_stylebox_override(
		"panel",
		_make_stylebox(
			Color(0.038, 0.046, 0.058, 0.94),
			Color(0.24, 0.27, 0.31, 1.0),
			1,
			2
		)
	)
	columns.add_child(group_panel)

	var group_margin := MarginContainer.new()
	group_margin.name = "Margin"
	group_margin.add_theme_constant_override("margin_left", 4)
	group_margin.add_theme_constant_override("margin_top", 3)
	group_margin.add_theme_constant_override("margin_right", 4)
	group_margin.add_theme_constant_override("margin_bottom", 3)
	group_panel.add_child(group_margin)

	var column := VBoxContainer.new()
	column.name = "ControlColumn"
	column.add_theme_constant_override("separation", 3)
	group_margin.add_child(column)

	var heading := Label.new()
	heading.name = "Heading"
	heading.text = str(group_data.get("title", ""))
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.custom_minimum_size.y = 14.0
	heading.add_theme_font_override("font", _button_font)
	heading.add_theme_font_size_override("font_size", 10)
	heading.add_theme_color_override(
		"font_color",
		Color(0.86, 0.87, 0.89, 1.0)
	)
	heading.add_to_group(&"alto_contraste")
	column.add_child(heading)

	var actions: Array = group_data.get("actions", [])

	for action_data: Variant in actions:
		if action_data is Dictionary:
			_add_remap_button(column, action_data as Dictionary)


func _add_remap_button(
	column: VBoxContainer,
	action_data: Dictionary
) -> void:
	var action_id := str(action_data.get("id", ""))

	if action_id.is_empty() or not InputMap.has_action(action_id):
		return

	var button := InputRemapButton.new()
	button.name = "Remap_%s" % action_id
	button.action = action_id
	button.action_name = str(action_data.get("label", action_id))
	button.custom_minimum_size = Vector2(0.0, 22.0)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.clip_text = true
	button.flat = false
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.icon = _button_icon
	button.expand_icon = false
	button.add_theme_font_override("font", _button_font)
	button.add_theme_font_size_override("font_size", 9)
	button.add_theme_constant_override("icon_max_width", 13)
	button.add_theme_color_override("font_color", Color.WHITE)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	button.add_theme_color_override("font_focus_color", Color.WHITE)
	button.add_theme_stylebox_override(
		"normal",
		_make_button_style(
			Color(0.065, 0.075, 0.088, 1.0),
			Color(0.25, 0.28, 0.32, 1.0),
			1
		)
	)
	button.add_theme_stylebox_override(
		"hover",
		_make_button_style(
			Color(0.12, 0.135, 0.155, 1.0),
			Color(0.82, 0.84, 0.87, 1.0),
			1
		)
	)
	button.add_theme_stylebox_override(
		"pressed",
		_make_button_style(
			Color(0.17, 0.18, 0.2, 1.0),
			Color.WHITE,
			1
		)
	)
	button.add_theme_stylebox_override(
		"focus",
		_make_button_style(
			Color(0.09, 0.1, 0.115, 1.0),
			Color.WHITE,
			1
		)
	)
	button.add_to_group(&"Botoes_Controles")
	button.add_to_group(&"alto_contraste")
	button.pressed.connect(button._on_pressed)
	column.add_child(button)


func _remove_legacy_columns() -> void:
	for path: String in ["VBoxContainer", "VBoxContainer3"]:
		var legacy_column := get_node_or_null(path)

		if legacy_column == null:
			continue

		remove_child(legacy_column)
		legacy_column.queue_free()


func _make_button_style(
	background: Color,
	border: Color,
	border_width: int
) -> StyleBoxFlat:
	var style := _make_stylebox(
		background,
		border,
		border_width,
		2
	)
	style.content_margin_left = 5.0
	style.content_margin_right = 4.0
	style.content_margin_top = 2.0
	style.content_margin_bottom = 2.0
	return style


func _make_stylebox(
	background: Color,
	border: Color,
	border_width: int,
	corner_radius: int
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.border_width_left = border_width
	style.border_width_top = border_width
	style.border_width_right = border_width
	style.border_width_bottom = border_width
	style.corner_radius_top_left = corner_radius
	style.corner_radius_top_right = corner_radius
	style.corner_radius_bottom_left = corner_radius
	style.corner_radius_bottom_right = corner_radius
	style.anti_aliasing = false
	return style


func _on_options_interface_size_item_selected(_index: int) -> void:
	# A escala é aplicada pelo script da tela que contém este painel.
	pass
