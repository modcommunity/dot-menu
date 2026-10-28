@tool
extends EditorPlugin

## Editor entry point for dot-menu. Registers inspector types only.
##
## No autoloads: a server and a client in one editor session are two menus.

const _TYPES := [
	["DotMenu", "CanvasLayer", "res://addons/dot_menu/runtime/dot_menu.gd"],
	["DotMenuApplier", "Node", "res://addons/dot_menu/runtime/dot_menu_applier.gd"],
]


func _enter_tree() -> void:
	for entry in _TYPES:
		add_custom_type(entry[0], entry[1], load(entry[2]), null)


func _exit_tree() -> void:
	for i in range(_TYPES.size() - 1, -1, -1):
		remove_custom_type(_TYPES[i][0])
